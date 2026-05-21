namespace NewCarPool.Application.DTOs.Rides;

public sealed record RideStopDto(
    string Name,
    string? Address,
    double Latitude,
    double Longitude,
    int Order);
