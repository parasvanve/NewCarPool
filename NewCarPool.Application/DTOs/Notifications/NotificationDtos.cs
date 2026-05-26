using NewCarPool.Domain.Enums;

namespace NewCarPool.Application.DTOs.Notifications;

public sealed record NotificationDto(
    Guid Id,
    string Title,
    string Message,
    NotificationType Type,
    Guid? RideId,
    Guid? BookingId,
    bool IsRead,
    DateTime CreatedAtUtc);

public sealed record CreateNotificationRequest(
    string Title,
    string Message,
    NotificationType Type = NotificationType.General,
    Guid? RideId = null,
    Guid? BookingId = null);
