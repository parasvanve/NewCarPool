using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using NewCarPool.Api.Extensions;
using NewCarPool.Application.Interfaces.Services;

namespace NewCarPool.Api.Hubs;

[Authorize]
public sealed class TrackingHub : Hub
{
    private readonly ITrackingService _trackingService;

    public TrackingHub(ITrackingService trackingService)
    {
        _trackingService = trackingService;
    }

    public async Task JoinRide(string rideOfferId)
    {
        if (!Guid.TryParse(rideOfferId, out var rideId))
        {
            throw new HubException("Ride not found.");
        }

        await _trackingService.EnsureCanAccessTrackingAsync(Context.User!.GetUserId(), rideId, Context.ConnectionAborted);
        await Groups.AddToGroupAsync(Context.ConnectionId, RideGroupName(rideId.ToString()));
    }

    public Task LeaveRide(string rideOfferId) =>
        Groups.RemoveFromGroupAsync(Context.ConnectionId, RideGroupName(rideOfferId));

    public static string RideGroupName(string rideOfferId) => $"ride:{rideOfferId}";
}
