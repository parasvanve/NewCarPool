using NewCarPool.Domain.Enums;

namespace NewCarPool.Application.DTOs.Rides;

public sealed record RideOfferDto(
    Guid Id,
    Guid DriverId,
    Guid VehicleId,
    string DriverName,
    GeoPointDto Origin,
    GeoPointDto Destination,
    DateTime DepartureTimeUtc,
    int AvailableSeats,
    decimal PricePerSeat,
    string? VehicleName,
    string? VehicleNumber,
    string? RoutePolyline,
    double? DistanceKm,
    int? EtaMinutes,
    RideStatus Status);
