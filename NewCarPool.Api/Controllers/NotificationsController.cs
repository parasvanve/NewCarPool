using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using NewCarPool.Api.Extensions;
using NewCarPool.Api.Hubs;
using NewCarPool.Application.DTOs.Notifications;
using NewCarPool.Application.Interfaces.Services;

namespace NewCarPool.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public sealed class NotificationsController : ControllerBase
{
    private readonly INotificationService _notificationService;
    private readonly IHubContext<NotificationHub> _hubContext;

    public NotificationsController(INotificationService notificationService, IHubContext<NotificationHub> hubContext)
    {
        _notificationService = notificationService;
        _hubContext = hubContext;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<NotificationDto>>> Mine(CancellationToken cancellationToken) =>
        Ok(await _notificationService.GetMineAsync(User.GetUserId(), cancellationToken));

    [HttpPost]
    public async Task<ActionResult<NotificationDto>> SendToMe(CreateNotificationRequest request, CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var notification = await _notificationService.CreateAsync(userId, request, cancellationToken);
        await _hubContext.Clients.Group(NotificationHub.UserGroupName(userId.ToString())).SendAsync("notificationReceived", notification, cancellationToken);
        return Ok(notification);
    }

    [HttpPost("{notificationId:guid}/read")]
    public async Task<IActionResult> MarkRead(Guid notificationId, CancellationToken cancellationToken)
    {
        await _notificationService.MarkReadAsync(User.GetUserId(), notificationId, cancellationToken);
        return NoContent();
    }
}
