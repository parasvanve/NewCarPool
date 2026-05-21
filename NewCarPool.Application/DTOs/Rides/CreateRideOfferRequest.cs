namespace NewCarPool.Application.DTOs.Rides;

public sealed record CreateRideOfferRequest(
    Guid VehicleId,
    GeoPointDto Origin,
    GeoPointDto Destination,
    DateTime DepartureTimeUtc,
    int AvailableSeats,
    decimal PricePerSeat,
    IReadOnlyList<RideStopDto>? IntermediateStops,
    string? VehicleName,
    string? VehicleNumber);
