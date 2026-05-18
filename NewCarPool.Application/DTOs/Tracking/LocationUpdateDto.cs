namespace NewCarPool.Application.DTOs.Tracking;

public sealed record LocationUpdateDto(
    Guid RideOfferId,
    Guid DriverId,
    double Latitude,
    double Longitude,
    double? Heading,
    double? SpeedKph,
    DateTime CreatedAtUtc);
