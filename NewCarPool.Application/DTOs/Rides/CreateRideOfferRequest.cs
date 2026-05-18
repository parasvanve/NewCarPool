namespace NewCarPool.Application.DTOs.Rides;

public sealed record CreateRideOfferRequest(
    Guid VehicleId,
    GeoPointDto Origin,
    GeoPointDto Destination,
    DateTime DepartureTimeUtc,
    int AvailableSeats,
    decimal PricePerSeat,
    string? VehicleName,
    string? VehicleNumber);
