using NewCarPool.Domain.Enums;

namespace NewCarPool.Domain.Entities;

public sealed class Vehicle
{
    public Guid Id { get; set; }
    public Guid OwnerId { get; set; }
    public string VehicleName { get; set; } = string.Empty;
    public string VehicleNumber { get; set; } = string.Empty;
    public VehicleType VehicleType { get; set; }
    public string Color { get; set; } = string.Empty;
    public int Seats { get; set; }
    public string? RcImagePath { get; set; }
    public string? VehicleImagePath { get; set; }
    public bool IsVerified { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAtUtc { get; set; }

    public User Owner { get; set; } = default!;
    public ICollection<RideOffer> RideOffers { get; set; } = new List<RideOffer>();
}
