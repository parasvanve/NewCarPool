using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace NewCarPool.Api.Hubs;

[Authorize]
public sealed class NotificationHub : Hub
{
    public Task JoinUserGroup(string userId) =>
        Groups.AddToGroupAsync(Context.ConnectionId, UserGroupName(userId));

    public static string UserGroupName(string userId) => $"user:{userId}";
}
