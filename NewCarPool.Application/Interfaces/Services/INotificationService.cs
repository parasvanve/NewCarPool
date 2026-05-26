using NewCarPool.Application.DTOs.Notifications;

namespace NewCarPool.Application.Interfaces.Services;

public interface INotificationService
{
    Task<IReadOnlyList<NotificationDto>> GetMineAsync(Guid userId, CancellationToken cancellationToken);
    Task<int> UnreadCountAsync(Guid userId, CancellationToken cancellationToken);
    Task<NotificationDto> CreateAsync(Guid userId, CreateNotificationRequest request, CancellationToken cancellationToken);
    Task MarkReadAsync(Guid userId, Guid notificationId, CancellationToken cancellationToken);
}
