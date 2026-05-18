using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace NewCarPool.Api.Hubs;

[Authorize]
public sealed class TrackingHub : Hub
{
    public Task JoinRide(string rideOfferId) =>
        Groups.AddToGroupAsync(Context.ConnectionId, RideGroupName(rideOfferId));

    public Task LeaveRide(string rideOfferId) =>
        Groups.RemoveFromGroupAsync(Context.ConnectionId, RideGroupName(rideOfferId));

    public static string RideGroupName(string rideOfferId) => $"ride:{rideOfferId}";
}
