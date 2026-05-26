namespace NewCarPool.Application.DTOs.Rides;

public sealed class BookRideRequest
{
    public Guid RideOfferId { get; init; }
    public Guid? RideId { get; init; }
    public int SeatsBooked { get; init; }
    public GeoPointDto Pickup { get; init; } = default!;
    public GeoPointDto Drop { get; init; } = default!;

    public Guid EffectiveRideId => RideOfferId != Guid.Empty ? RideOfferId : (RideId ?? Guid.Empty);
}
