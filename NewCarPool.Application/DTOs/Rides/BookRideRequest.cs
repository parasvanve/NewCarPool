namespace NewCarPool.Application.DTOs.Rides;

public sealed record BookRideRequest(Guid RideOfferId, int SeatsBooked);
