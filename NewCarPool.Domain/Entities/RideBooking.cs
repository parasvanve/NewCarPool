using NewCarPool.Domain.Enums;

namespace NewCarPool.Domain.Entities;

public sealed class RideBooking
{
    public Guid Id { get; set; }
    public Guid RideOfferId { get; set; }
    public Guid PassengerId { get; set; }
    public int SeatsBooked { get; set; }
    public string PassengerPickupName { get; set; } = string.Empty;
    public string PassengerPickupAddress { get; set; } = string.Empty;
    public double PassengerPickupLatitude { get; set; }
    public double PassengerPickupLongitude { get; set; }
    public string PassengerDropName { get; set; } = string.Empty;
    public string PassengerDropAddress { get; set; } = string.Empty;
    public double PassengerDropLatitude { get; set; }
    public double PassengerDropLongitude { get; set; }
    public BookingStatus Status { get; set; } = BookingStatus.Confirmed;
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime? CancelledAtUtc { get; set; }

    public RideOffer RideOffer { get; set; } = default!;
    public User Passenger { get; set; } = default!;
}
