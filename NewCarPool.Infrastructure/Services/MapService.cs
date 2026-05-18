using System.Globalization;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using NewCarPool.Application.DTOs.Maps;
using NewCarPool.Application.Interfaces.Services;

namespace NewCarPool.Infrastructure.Services;

public sealed class MapService : IMapService
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IConfiguration _configuration;

    public MapService(IHttpClientFactory httpClientFactory, IConfiguration configuration)
    {
        _httpClientFactory = httpClientFactory;
        _configuration = configuration;
    }

    public async Task<RouteResultDto> CalculateRouteAsync(RouteRequest request, CancellationToken cancellationToken)
    {
        var apiKey = _configuration["ExternalApis:OpenRouteServiceApiKey"];
        if (string.IsNullOrWhiteSpace(apiKey))
        {
            var distance = HaversineKm(request.FromLatitude, request.FromLongitude, request.ToLatitude, request.ToLongitude);
            return new RouteResultDto(Math.Round(distance, 2), Math.Max(1, (int)Math.Ceiling(distance / 40d * 60d)), null);
        }

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
        response.EnsureSuccessStatusCode();

        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync(cancellationToken));
        var route = document.RootElement.GetProperty("routes")[0];
        var summary = route.GetProperty("summary");
        return new RouteResultDto(
            Math.Round(summary.GetProperty("distance").GetDouble() / 1000d, 2),
            Math.Max(1, (int)Math.Ceiling(summary.GetProperty("duration").GetDouble() / 60d)),
            route.TryGetProperty("geometry", out var geometry) ? geometry.GetString() : null);
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

    private static double HaversineKm(double lat1, double lon1, double lat2, double lon2)
    {
        const double radiusKm = 6371d;
        var dLat = DegreesToRadians(lat2 - lat1);
        var dLon = DegreesToRadians(lon2 - lon1);
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(DegreesToRadians(lat1)) * Math.Cos(DegreesToRadians(lat2)) *
                Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        return radiusKm * 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
    }

    private static double DegreesToRadians(double degrees) => degrees * Math.PI / 180d;
}
