using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace NewCarPool.Infrastructure.Hubs;

[Authorize]
public sealed class AppRealtimeHub : Hub
{
    public Task JoinUserGroup(string userId) =>
        Groups.AddToGroupAsync(Context.ConnectionId, UserGroupName(userId));

    public static string UserGroupName(string userId) => $"user:{userId}";
}

