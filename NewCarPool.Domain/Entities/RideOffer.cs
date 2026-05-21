using NewCarPool.Domain.Enums;

namespace NewCarPool.Domain.Entities;

public sealed class RideOffer
{
    public Guid Id { get; set; }
    public Guid DriverId { get; set; }
    public Guid VehicleId { get; set; }
    public string OriginName { get; set; } = string.Empty;
    public string OriginAddress { get; set; } = string.Empty;
    public double OriginLatitude { get; set; }
    public double OriginLongitude { get; set; }
    public string DestinationName { get; set; } = string.Empty;
    public string DestinationAddress { get; set; } = string.Empty;
    public double DestinationLatitude { get; set; }
    public double DestinationLongitude { get; set; }
    public DateTime DepartureTimeUtc { get; set; }
    public int AvailableSeats { get; set; }
    public decimal PricePerSeat { get; set; }
    public string? VehicleName { get; set; }
    public string? VehicleNumber { get; set; }
    public string? RoutePolyline { get; set; }
    public double? DistanceKm { get; set; }
    public int? EtaMinutes { get; set; }
    public RideStatus Status { get; set; } = RideStatus.Open;
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAtUtc { get; set; }

    public User Driver { get; set; } = default!;
    public Vehicle Vehicle { get; set; } = default!;
    public ICollection<RideBooking> Bookings { get; set; } = new List<RideBooking>();
    public ICollection<RideLocationUpdate> LocationUpdates { get; set; } = new List<RideLocationUpdate>();
    public ICollection<RideStop> IntermediateStops { get; set; } = new List<RideStop>();
    public RideChatGroup? ChatGroup { get; set; }
}
