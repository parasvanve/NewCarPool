namespace NewCarPool.Application.DTOs.Rides;

public sealed record SearchRideRequest(
    double OriginLatitude,
    double OriginLongitude,
    double DestinationLatitude,
    double DestinationLongitude,
    DateTime? DepartureDateUtc,
    int Seats,
    int Page = 1,
    int PageSize = 20);
