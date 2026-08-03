using NewCarPool.Domain.Enums;

namespace NewCarPool.Application.DTOs.Rides;

public sealed record RidePublicDto(
    Guid Id,
    string DriverName,
    GeoPointDto Origin,
    GeoPointDto Destination,
    IReadOnlyList<RideStopDto> IntermediateStops,
    DateTime DepartureTimeUtc,
    int AvailableSeats,
    int ParticipantCount,
    decimal PricePerSeat,
    string? VehicleName,
    string? VehicleNumber,
    RideStatus Status);

public sealed record RideShareLinkDto(string ShareUrl, string WhatsAppMessage);