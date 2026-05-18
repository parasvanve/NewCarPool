namespace NewCarPool.Application.DTOs.Notifications;

public sealed record NotificationDto(Guid Id, string Title, string Message, bool IsRead, DateTime CreatedAtUtc);
public sealed record CreateNotificationRequest(string Title, string Message);
