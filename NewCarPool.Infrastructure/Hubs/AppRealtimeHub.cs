using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using System.Security.Claims;

namespace NewCarPool.Infrastructure.Hubs;

[Authorize]
public sealed class AppRealtimeHub : Hub
{
    public Task JoinUserGroup(string userId)
    {
        var authenticatedUserId = Context.User?.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(authenticatedUserId))
        {
            throw new HubException("User is not authenticated.");
        }

        return Groups.AddToGroupAsync(Context.ConnectionId, UserGroupName(authenticatedUserId));
    }

    public static string UserGroupName(string userId) => $"user:{userId}";
}

