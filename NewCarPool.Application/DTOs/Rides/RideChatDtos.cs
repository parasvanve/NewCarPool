namespace NewCarPool.Application.DTOs.Rides;

using NewCarPool.Domain.Enums;

public sealed record RideChatMessageDto(
    Guid Id,
    Guid RideChatGroupId,
    Guid SenderUserId,
    string SenderName,
    string Message,
    DateTime CreatedAtUtc,
    RideChatMessageType MessageType,
    string? AttachmentUrl,
    string? AttachmentFileName,
    string? AttachmentContentType,
    long? AttachmentSizeBytes);

public sealed record SendRideChatMessageRequest(string Message);

public sealed record ChatAttachmentUpload(
    Stream Content,
    string FileName,
    string ContentType,
    long Length,
    string? Caption);
