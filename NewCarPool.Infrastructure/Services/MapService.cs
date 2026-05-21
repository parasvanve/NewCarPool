using System.Globalization;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Maps;
using NewCarPool.Application.Interfaces.Services;

namespace NewCarPool.Infrastructure.Services;

public sealed class MapService : IMapService
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IConfiguration _configuration;
    private readonly ILogger<MapService> _logger;

    public MapService(IHttpClientFactory httpClientFactory, IConfiguration configuration, ILogger<MapService> logger)
    {
        _httpClientFactory = httpClientFactory;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<RouteResultDto> CalculateRouteAsync(RouteRequest request, CancellationToken cancellationToken)
    {
        var apiKey = _configuration["ExternalApis:OpenRouteServiceApiKey"];
        if (!string.IsNullOrWhiteSpace(apiKey))
        {
            try
            {
                var client = _httpClientFactory.CreateClient("OpenRouteService");
                client.DefaultRequestHeaders.TryAddWithoutValidation("Authorization", apiKey);
                var response = await client.PostAsJsonAsync("/v2/directions/driving-car", new
                {
                    coordinates = new[]
                    {
                        new[] { request.FromLongitude, request.FromLatitude },
                        new[] { request.ToLongitude, request.ToLatitude }
                    }
                }, cancellationToken);
                if (response.IsSuccessStatusCode)
                {
                    using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync(cancellationToken));
                    var route = document.RootElement.GetProperty("routes")[0];
                    var summary = route.GetProperty("summary");
                    return new RouteResultDto(
                        Math.Round(summary.GetProperty("distance").GetDouble() / 1000d, 2),
                        Math.Max(1, (int)Math.Ceiling(summary.GetProperty("duration").GetDouble() / 60d)),
                        route.TryGetProperty("geometry", out var geometry) ? geometry.GetString() : null);
                }

                var payload = await response.Content.ReadAsStringAsync(cancellationToken);
                _logger.LogWarning("OpenRouteService failed: {StatusCode}, Body: {Body}", (int)response.StatusCode, payload);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "OpenRouteService call failed, falling back to OSRM.");
            }
        }

        return await CalculateWithOsrmAsync(request, cancellationToken);
    }

    public async Task<IReadOnlyList<GeocodeResultDto>> SearchPlacesAsync(string query, CancellationToken cancellationToken)
    {
        var client = _httpClientFactory.CreateClient("Nominatim");
        var response = await client.GetFromJsonAsync<JsonElement[]>($"/search?q={Uri.EscapeDataString(query)}&format=json&limit=10", cancellationToken);
        return response?
            .Select(x => new GeocodeResultDto(
                x.GetProperty("display_name").GetString() ?? string.Empty,
                double.Parse(x.GetProperty("lat").GetString() ?? "0", CultureInfo.InvariantCulture),
                double.Parse(x.GetProperty("lon").GetString() ?? "0", CultureInfo.InvariantCulture)))
            .ToList() ?? [];
    }

    public async Task<ReverseGeocodeResultDto> ReverseGeocodeAsync(double latitude, double longitude, CancellationToken cancellationToken)
    {
        var client = _httpClientFactory.CreateClient("Nominatim");
        var endpoint =
            $"/reverse?lat={latitude.ToString(CultureInfo.InvariantCulture)}&lon={longitude.ToString(CultureInfo.InvariantCulture)}&format=json";
        var response = await client.GetFromJsonAsync<JsonElement>(endpoint, cancellationToken);
        var displayName = response.TryGetProperty("display_name", out var display)
            ? display.GetString() ?? "Current location"
            : "Current location";
        return new ReverseGeocodeResultDto(displayName, latitude, longitude);
    }

    private async Task<RouteResultDto> CalculateWithOsrmAsync(RouteRequest request, CancellationToken cancellationToken)
    {
        var coordinates =
            $"{request.FromLongitude.ToString(CultureInfo.InvariantCulture)},{request.FromLatitude.ToString(CultureInfo.InvariantCulture)};" +
            $"{request.ToLongitude.ToString(CultureInfo.InvariantCulture)},{request.ToLatitude.ToString(CultureInfo.InvariantCulture)}";
        var url = $"https://router.project-osrm.org/route/v1/driving/{coordinates}?overview=full&geometries=polyline";

        using var httpClient = new HttpClient();
        var response = await httpClient.GetAsync(url, cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            var payload = await response.Content.ReadAsStringAsync(cancellationToken);
            _logger.LogError("OSRM route failed: {StatusCode}, Body: {Body}", (int)response.StatusCode, payload);
            throw new ApiException("Unable to fetch road route right now.", 502);
        }

        using var doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync(cancellationToken));
        var routes = doc.RootElement.GetProperty("routes");
        if (routes.GetArrayLength() == 0)
        {
            throw new ApiException("No road route found for selected points.", 422);
        }

        var first = routes[0];
        var distanceMeters = first.GetProperty("distance").GetDouble();
        var durationSeconds = first.GetProperty("duration").GetDouble();
        var geometry = first.GetProperty("geometry").GetString();

        return new RouteResultDto(
            Math.Round(distanceMeters / 1000d, 2),
            Math.Max(1, (int)Math.Ceiling(durationSeconds / 60d)),
            geometry);
    }
}
