namespace NewCarPool.Application.DTOs.Rides;

public sealed record RideChatMessageDto(
    Guid Id,
    Guid RideOfferId,
    Guid SenderUserId,
    string SenderName,
    string Message,
    DateTime CreatedAtUtc);

public sealed record SendRideChatMessageRequest(string Message);
