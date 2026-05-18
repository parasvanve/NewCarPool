namespace NewCarPool.Application.DTOs.Tracking;

public sealed record LocationUpdateRequest(
    Guid RideOfferId,
    double Latitude,
    double Longitude,
    double? Heading,
    double? SpeedKph);
