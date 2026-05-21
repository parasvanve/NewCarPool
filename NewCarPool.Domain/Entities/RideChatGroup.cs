namespace NewCarPool.Domain.Entities;

public sealed class RideChatGroup
{
    public Guid Id { get; set; }
    public Guid RideOfferId { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

    public RideOffer RideOffer { get; set; } = default!;
    public ICollection<RideChatMessage> Messages { get; set; } = new List<RideChatMessage>();
}
