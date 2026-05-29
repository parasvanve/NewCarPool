using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using NewCarPool.Api.Extensions;
using NewCarPool.Api.Hubs;
using NewCarPool.Application.DTOs.Tracking;
using NewCarPool.Application.Interfaces.Services;

namespace NewCarPool.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public sealed class TrackingController : ControllerBase
{
    private readonly ITrackingService _trackingService;
    private readonly IHubContext<TrackingHub> _hubContext;

    public TrackingController(ITrackingService trackingService, IHubContext<TrackingHub> hubContext)
    {
        _trackingService = trackingService;
        _hubContext = hubContext;
    }

    [HttpPost("location")]
    public async Task<ActionResult<LocationUpdateDto>> Publish(LocationUpdateRequest request, CancellationToken cancellationToken)
    {
        var location = await _trackingService.AddLocationUpdateAsync(User.GetUserId(), request, cancellationToken);
        await _hubContext.Clients
            .Group(TrackingHub.RideGroupName(request.RideOfferId.ToString()))
            .SendAsync("locationUpdated", location, cancellationToken);
        await _hubContext.Clients
            .Group(TrackingHub.RideGroupName(request.RideOfferId.ToString()))
            .SendAsync("DriverLocationUpdated", location, cancellationToken);

        return Ok(location);
    }

    [HttpPost("/api/rides/{rideOfferId:guid}/location")]
    public async Task<ActionResult<LocationUpdateDto>> PublishForRide(
        Guid rideOfferId,
        [FromBody] LocationUpdateRequest request,
        CancellationToken cancellationToken)
    {
        var normalized = request with { RideOfferId = rideOfferId };
        return await Publish(normalized, cancellationToken);
    }

    [HttpGet("/api/rides/{rideOfferId:guid}/location/latest")]
    public async Task<ActionResult<LocationUpdateDto>> Latest(Guid rideOfferId, CancellationToken cancellationToken) =>
        Ok(await _trackingService.GetLatestLocationAsync(User.GetUserId(), rideOfferId, cancellationToken));
}
