using NewCarPool.Domain.Enums;

namespace NewCarPool.Domain.Entities;

public sealed class Notification
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public NotificationType Type { get; set; } = NotificationType.General;
    public Guid? RideId { get; set; }
    public Guid? BookingId { get; set; }
    public bool IsRead { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime? ReadAtUtc { get; set; }

    public User User { get; set; } = default!;
}
