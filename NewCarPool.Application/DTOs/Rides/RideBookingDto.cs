using NewCarPool.Domain.Enums;

namespace NewCarPool.Application.DTOs.Rides;

public sealed record RideBookingDto(
    Guid Id,
    Guid RideOfferId,
    Guid PassengerId,
    string PassengerName,
    int SeatsBooked,
    GeoPointDto PassengerPickup,
    GeoPointDto PassengerDrop,
    BookingStatus Status,
    DateTime CreatedAtUtc);
