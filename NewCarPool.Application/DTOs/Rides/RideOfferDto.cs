using NewCarPool.Domain.Enums;

namespace NewCarPool.Application.DTOs.Rides;

public sealed record RideOfferDto(
    Guid Id,
    Guid DriverId,
    Guid VehicleId,
    string DriverName,
    GeoPointDto Origin,
    GeoPointDto Destination,
    IReadOnlyList<RideStopDto> IntermediateStops,
    DateTime DepartureTimeUtc,
    int AvailableSeats,
    int ParticipantCount,
    decimal PricePerSeat,
    string? Notes,
    string? VehicleName,
    string? VehicleNumber,
    string? RoutePolyline,
    double? DistanceKm,
    int? EtaMinutes,
    RideStatus Status);
