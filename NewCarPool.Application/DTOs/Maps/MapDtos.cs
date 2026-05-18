namespace NewCarPool.Application.DTOs.Maps;

public sealed record RouteRequest(double FromLatitude, double FromLongitude, double ToLatitude, double ToLongitude);
public sealed record RouteResultDto(double DistanceKm, int EtaMinutes, string? EncodedPolyline);
public sealed record GeocodeResultDto(string DisplayName, double Latitude, double Longitude);
