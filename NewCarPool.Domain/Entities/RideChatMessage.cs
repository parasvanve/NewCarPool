namespace NewCarPool.Domain.Entities;

using NewCarPool.Domain.Enums;

public sealed class RideChatMessage
{
    public Guid Id { get; set; }
    public Guid RideChatGroupId { get; set; }
    public Guid SenderUserId { get; set; }
    public string Message { get; set; } = string.Empty;
    public RideChatMessageType MessageType { get; set; } = RideChatMessageType.Text;
    public string? AttachmentUrl { get; set; }
    public string? AttachmentFileName { get; set; }
    public string? AttachmentContentType { get; set; }
    public long? AttachmentSizeBytes { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

    public RideChatGroup RideChatGroup { get; set; } = default!;
    public User SenderUser { get; set; } = default!;
}
