using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.SignalR;
using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Notifications;
using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Application.Interfaces.Services;
using NewCarPool.Domain.Entities;
using NewCarPool.Infrastructure.Hubs;

namespace NewCarPool.Infrastructure.Services;

public sealed class NotificationService : INotificationService
{
    private readonly IGenericRepository<Notification> _notifications;
    private readonly IUnitOfWork _unitOfWork;
    private readonly IHubContext<AppRealtimeHub> _hubContext;

    public NotificationService(IGenericRepository<Notification> notifications, IUnitOfWork unitOfWork, IHubContext<AppRealtimeHub> hubContext)
    {
        _notifications = notifications;
        _unitOfWork = unitOfWork;
        _hubContext = hubContext;
    }

    public async Task<IReadOnlyList<NotificationDto>> GetMineAsync(Guid userId, CancellationToken cancellationToken) =>
        await _notifications.Query().Where(x => x.UserId == userId).OrderByDescending(x => x.CreatedAtUtc).Select(x => Map(x)).ToListAsync(cancellationToken);

    public Task<int> UnreadCountAsync(Guid userId, CancellationToken cancellationToken) =>
        _notifications.Query().CountAsync(x => x.UserId == userId && !x.IsRead, cancellationToken);

    public async Task<NotificationDto> CreateAsync(Guid userId, CreateNotificationRequest request, CancellationToken cancellationToken)
    {
        var nowUtc = DateTime.UtcNow;
        var notification = new Notification
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Title = request.Title.Trim(),
            Message = request.Message.Trim(),
            Type = request.Type,
            RideId = request.RideId,
            BookingId = request.BookingId,
            CreatedAtUtc = nowUtc
        };
        await _notifications.AddAsync(notification, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        var dto = Map(notification);
        await _hubContext.Clients.Group(AppRealtimeHub.UserGroupName(userId.ToString())).SendAsync("notificationReceived", dto, cancellationToken);
        await _hubContext.Clients.Group(AppRealtimeHub.UserGroupName(userId.ToString())).SendAsync("NotificationCreated", dto, cancellationToken);
        var unread = await UnreadCountAsync(userId, cancellationToken);
        await _hubContext.Clients.Group(AppRealtimeHub.UserGroupName(userId.ToString())).SendAsync("UnreadCountChanged", unread, cancellationToken);
        return dto;
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
        var unread = await UnreadCountAsync(userId, cancellationToken);
        await _hubContext.Clients.Group(AppRealtimeHub.UserGroupName(userId.ToString())).SendAsync("UnreadCountChanged", unread, cancellationToken);
    }

    public async Task MarkAllReadAsync(Guid userId, CancellationToken cancellationToken)
    {
        var unread = await _notifications.Query()
            .Where(x => x.UserId == userId && !x.IsRead)
            .ToListAsync(cancellationToken);
        if (unread.Count == 0) return;
        var now = DateTime.UtcNow;
        foreach (var notification in unread)
        {
            notification.IsRead = true;
            notification.ReadAtUtc = now;
        }
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        await _hubContext.Clients.Group(AppRealtimeHub.UserGroupName(userId.ToString())).SendAsync("UnreadCountChanged", 0, cancellationToken);
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
            NormalizeToUtc(notification.CreatedAtUtc));

    private static DateTime NormalizeToUtc(DateTime value) =>
        value.Kind switch
        {
            DateTimeKind.Utc => value,
            DateTimeKind.Local => value.ToUniversalTime(),
            DateTimeKind.Unspecified => DateTime.SpecifyKind(value, DateTimeKind.Utc),
            _ => value.ToUniversalTime()
        };
}
