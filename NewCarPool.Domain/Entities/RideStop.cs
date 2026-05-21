namespace NewCarPool.Domain.Entities;

public sealed class RideStop
{
    public Guid Id { get; set; }
    public Guid RideOfferId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Address { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public int StopOrder { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

    public RideOffer RideOffer { get; set; } = default!;
}
