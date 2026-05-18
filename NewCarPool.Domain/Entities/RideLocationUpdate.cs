namespace NewCarPool.Domain.Entities;

public sealed class RideLocationUpdate
{
    public Guid Id { get; set; }
    public Guid RideOfferId { get; set; }
    public Guid DriverId { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double? Heading { get; set; }
    public double? SpeedKph { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

    public RideOffer RideOffer { get; set; } = default!;
    public User Driver { get; set; } = default!;
}
