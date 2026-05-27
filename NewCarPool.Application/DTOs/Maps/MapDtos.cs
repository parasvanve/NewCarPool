namespace NewCarPool.Application.DTOs.Maps;

public sealed record RouteRequest(double FromLatitude, double FromLongitude, double ToLatitude, double ToLongitude);
public sealed record RouteResultDto(double DistanceKm, int EtaMinutes, string? EncodedPolyline);
public sealed record GeocodeResultDto(
    string DisplayName,
    double Latitude,
    double Longitude,
    string? Name = null,
    string? Address = null,
    long? PlaceId = null,
    string? MainText = null,
    string? SecondaryText = null);
public sealed record ReverseGeocodeResultDto(
    string DisplayName,
    double Latitude,
    double Longitude,
    string? Name = null,
    string? Address = null);
