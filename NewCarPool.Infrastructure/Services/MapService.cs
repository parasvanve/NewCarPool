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

    public async Task<IReadOnlyList<GeocodeResultDto>> SearchPlacesAsync(
        string query,
        double? latitude,
        double? longitude,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(query))
        {
            return [];
        }

        var client = _httpClientFactory.CreateClient("Nominatim");
        var endpoint =
            $"/search?q={Uri.EscapeDataString(query.Trim())}" +
            "&format=json&limit=20&addressdetails=1&namedetails=1&extratags=1&countrycodes=in";
        if (latitude is not null && longitude is not null)
        {
            var delta = 0.8d;
            var left = (longitude.Value - delta).ToString(CultureInfo.InvariantCulture);
            var right = (longitude.Value + delta).ToString(CultureInfo.InvariantCulture);
            var top = (latitude.Value + delta).ToString(CultureInfo.InvariantCulture);
            var bottom = (latitude.Value - delta).ToString(CultureInfo.InvariantCulture);
            endpoint += $"&viewbox={left},{top},{right},{bottom}&bounded=0";
        }

        var response = await client.GetFromJsonAsync<JsonElement[]>(endpoint, cancellationToken);
        return response?
            .Select(x => ToGeocodeResult(x, latitude, longitude))
            .OrderByDescending(x => ScoreMatch(query, x, latitude, longitude))
            .ThenBy(x => x.DistanceKm ?? double.MaxValue)
            .Take(15)
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
        var name = response.TryGetProperty("name", out var nameNode) ? nameNode.GetString() : null;
        return new ReverseGeocodeResultDto(displayName, latitude, longitude, name ?? GetMainText(displayName), displayName);
    }

    private static GeocodeResultDto ToGeocodeResult(JsonElement element, double? latitude, double? longitude)
    {
        var displayName = element.GetProperty("display_name").GetString() ?? string.Empty;
        var resultLatitude = double.Parse(element.GetProperty("lat").GetString() ?? "0", CultureInfo.InvariantCulture);
        var resultLongitude = double.Parse(element.GetProperty("lon").GetString() ?? "0", CultureInfo.InvariantCulture);
        var name = GetPlaceName(element, displayName);
        double? distanceKm = latitude is null || longitude is null
            ? null
            : Math.Round(DistanceKm(latitude.Value, longitude.Value, resultLatitude, resultLongitude), 2);

        return new GeocodeResultDto(
            displayName,
            resultLatitude,
            resultLongitude,
            name,
            displayName,
            element.TryGetProperty("place_id", out var placeIdNode) ? placeIdNode.GetInt64() : null,
            name,
            GetSecondaryText(displayName),
            distanceKm);
    }

    private static string GetPlaceName(JsonElement element, string displayName)
    {
        if (element.TryGetProperty("namedetails", out var namedetails))
        {
            foreach (var key in new[] { "name", "name:en", "official_name", "short_name" })
            {
                if (namedetails.TryGetProperty(key, out var value) && !string.IsNullOrWhiteSpace(value.GetString()))
                {
                    return value.GetString()!;
                }
            }
        }

        if (element.TryGetProperty("name", out var nameNode) && !string.IsNullOrWhiteSpace(nameNode.GetString()))
        {
            return nameNode.GetString()!;
        }

        return GetMainText(displayName);
    }

    private static double ScoreMatch(string query, GeocodeResultDto result, double? latitude, double? longitude)
    {
        var normalizedQuery = query.Trim().ToLowerInvariant();
        var name = (result.MainText ?? result.Name ?? string.Empty).ToLowerInvariant();
        var display = result.DisplayName.ToLowerInvariant();
        var score = 0d;

        if (name == normalizedQuery) score += 100;
        if (name.StartsWith(normalizedQuery, StringComparison.OrdinalIgnoreCase)) score += 50;
        if (name.Contains(normalizedQuery, StringComparison.OrdinalIgnoreCase)) score += 30;
        if (display.Contains(normalizedQuery, StringComparison.OrdinalIgnoreCase)) score += 10;
        if (latitude is not null && longitude is not null && result.DistanceKm is not null)
        {
            score += Math.Max(0, 20 - result.DistanceKm.Value);
        }

        return score;
    }

    private static double DistanceKm(double fromLatitude, double fromLongitude, double toLatitude, double toLongitude)
    {
        const double earthRadiusKm = 6371d;
        var dLat = ToRadians(toLatitude - fromLatitude);
        var dLon = ToRadians(toLongitude - fromLongitude);
        var lat1 = ToRadians(fromLatitude);
        var lat2 = ToRadians(toLatitude);
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(lat1) * Math.Cos(lat2) *
                Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return earthRadiusKm * c;
    }

    private static double ToRadians(double degrees) => degrees * Math.PI / 180d;

    private static string GetMainText(string displayName)
    {
        if (string.IsNullOrWhiteSpace(displayName)) return string.Empty;
        var parts = displayName.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        return parts.Length == 0 ? displayName.Trim() : parts[0];
    }

    private static string GetSecondaryText(string displayName)
    {
        if (string.IsNullOrWhiteSpace(displayName)) return string.Empty;
        var parts = displayName.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (parts.Length <= 1) return string.Empty;
        return string.Join(", ", parts.Skip(1).Take(3));
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
