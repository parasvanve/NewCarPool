namespace NewCarPool.Domain.Entities;

public sealed class Review
{
    public Guid Id { get; set; }
    public Guid RideOfferId { get; set; }
    public Guid ReviewerId { get; set; }
    public Guid RevieweeId { get; set; }
    public int Rating { get; set; }
    public string? Comment { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

    public RideOffer RideOffer { get; set; } = default!;
    public User Reviewer { get; set; } = default!;
    public User Reviewee { get; set; } = default!;
}
