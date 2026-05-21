namespace NewCarPool.Domain.Entities;

public sealed class RideChatMessage
{
    public Guid Id { get; set; }
    public Guid RideChatGroupId { get; set; }
    public Guid SenderUserId { get; set; }
    public string Message { get; set; } = string.Empty;
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

    public RideChatGroup RideChatGroup { get; set; } = default!;
    public User SenderUser { get; set; } = default!;
}
