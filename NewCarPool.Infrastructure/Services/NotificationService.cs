using Microsoft.EntityFrameworkCore;
using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Notifications;
using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Application.Interfaces.Services;
using NewCarPool.Domain.Entities;

namespace NewCarPool.Infrastructure.Services;

public sealed class NotificationService : INotificationService
{
    private readonly IGenericRepository<Notification> _notifications;
    private readonly IUnitOfWork _unitOfWork;

    public NotificationService(IGenericRepository<Notification> notifications, IUnitOfWork unitOfWork)
    {
        _notifications = notifications;
        _unitOfWork = unitOfWork;
    }

    public async Task<IReadOnlyList<NotificationDto>> GetMineAsync(Guid userId, CancellationToken cancellationToken) =>
        await _notifications.Query().Where(x => x.UserId == userId).OrderByDescending(x => x.CreatedAtUtc).Select(x => Map(x)).ToListAsync(cancellationToken);

    public Task<int> UnreadCountAsync(Guid userId, CancellationToken cancellationToken) =>
        _notifications.Query().CountAsync(x => x.UserId == userId && !x.IsRead, cancellationToken);

    public async Task<NotificationDto> CreateAsync(Guid userId, CreateNotificationRequest request, CancellationToken cancellationToken)
    {
        var notification = new Notification
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Title = request.Title.Trim(),
            Message = request.Message.Trim(),
            Type = request.Type,
            RideId = request.RideId,
            BookingId = request.BookingId
        };
        await _notifications.AddAsync(notification, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return Map(notification);
    }

    public async Task MarkReadAsync(Guid userId, Guid notificationId, CancellationToken cancellationToken)
    {
        var notification = await _notifications.GetByIdAsync(notificationId, cancellationToken) ?? throw new ApiException("Notification not found.", 404);
        if (notification.UserId != userId)
        {
            throw new ApiException("You cannot update this notification.", 403);
        }

        notification.IsRead = true;
        notification.ReadAtUtc = DateTime.UtcNow;
        await _unitOfWork.SaveChangesAsync(cancellationToken);
    }

    private static NotificationDto Map(Notification notification) =>
        new(
            notification.Id,
            notification.Title,
            notification.Message,
            notification.Type,
            notification.RideId,
            notification.BookingId,
            notification.IsRead,
            notification.CreatedAtUtc);
}
