using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using NewCarPool.Api.Extensions;
using NewCarPool.Api.Hubs;
using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Rides;
using NewCarPool.Application.Interfaces.Services;
using NewCarPool.Infrastructure.Hubs;

namespace NewCarPool.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/rides")]
public sealed class RidesController : ControllerBase
{
    private readonly IRideService _rideService;
    private readonly IBookingService _bookingService;
    private readonly IHubContext<AppRealtimeHub> _hubContext;
    private readonly IHubContext<TrackingHub> _trackingHubContext;

    public RidesController(
        IRideService rideService,
        IBookingService bookingService,
        IHubContext<AppRealtimeHub> hubContext,
        IHubContext<TrackingHub> trackingHubContext)
    {
        _rideService = rideService;
        _bookingService = bookingService;
        _hubContext = hubContext;
        _trackingHubContext = trackingHubContext;
    }

    [HttpPost("offer")]
    public async Task<ActionResult<RideOfferDto>> Offer(
      CreateRideOfferRequest request,
      CancellationToken cancellationToken)
    {
        var ride = await _rideService.OfferRideAsync(User.GetUserId(), request, cancellationToken);

        // Driver ko personal update
        await _hubContext.Clients
            .Group(AppRealtimeHub.UserGroupName(ride.DriverId.ToString()))
            .SendAsync("RideCreated", new { ride }, cancellationToken);

        await _hubContext.Clients.All
            .SendAsync("UpcomingRidesChanged", new { ride }, cancellationToken);

        return Ok(ride);
    }

    [HttpGet("search")]
    public async Task<ActionResult<PagedResult<RideOfferDto>>> Search([FromQuery] SearchRideRequest request, CancellationToken cancellationToken) =>
        Ok(await _rideService.SearchAsync(request, cancellationToken));

    [HttpGet("upcoming-active")]
    public async Task<ActionResult<IReadOnlyList<RideOfferDto>>> UpcomingActive(CancellationToken cancellationToken) =>
        Ok(await _rideService.UpcomingActiveRidesAsync(cancellationToken));

    [HttpGet("mine")]
    public async Task<ActionResult<IReadOnlyList<RideOfferDto>>> Mine(CancellationToken cancellationToken) =>
        Ok(await _rideService.MineAsync(User.GetUserId(), cancellationToken));

    [HttpGet("{rideOfferId:guid}")]
    public async Task<ActionResult<RideOfferDto>> Details(Guid rideOfferId, CancellationToken cancellationToken) =>
        Ok(await _rideService.DetailsAsync(rideOfferId, cancellationToken));

    //newcode 
    [AllowAnonymous]
    [HttpGet("{rideOfferId:guid}/public")]
    public async Task<ActionResult<RidePublicDto>> PublicDetails(Guid rideOfferId, CancellationToken cancellationToken) =>
        Ok(await _rideService.PublicDetailsAsync(rideOfferId, cancellationToken));

    [HttpPost("{rideOfferId:guid}/share-link")]
    public async Task<ActionResult<RideShareLinkDto>> ShareLink(Guid rideOfferId, CancellationToken cancellationToken) =>
        Ok(await _rideService.GenerateShareLinkAsync(User.GetUserId(), rideOfferId, cancellationToken));

    [HttpPut("{rideOfferId:guid}")]
    public async Task<ActionResult<RideOfferDto>> Update(Guid rideOfferId, CreateRideOfferRequest request, CancellationToken cancellationToken) =>
        Ok(await _rideService.UpdateRideAsync(User.GetUserId(), rideOfferId, request, cancellationToken));

    [HttpDelete("{rideOfferId:guid}")]
    public async Task<IActionResult> Delete(Guid rideOfferId, CancellationToken cancellationToken)
    {
        await _rideService.DeleteRideAsync(User.GetUserId(), rideOfferId, cancellationToken);
        return NoContent();
    }

    [HttpPost("book")]
    public async Task<ActionResult<RideBookingDto>> Book(BookRideRequest request, CancellationToken cancellationToken) =>
        Ok(await _rideService.BookRideAsync(User.GetUserId(), request, cancellationToken));

    [HttpGet("{rideOfferId:guid}/participants")]
    public async Task<ActionResult<IReadOnlyList<RideBookingDto>>> Participants(Guid rideOfferId, CancellationToken cancellationToken) =>
        Ok(await _rideService.ParticipantsAsync(rideOfferId, cancellationToken));

    [HttpGet("{rideOfferId:guid}/chat/messages")]
    public async Task<ActionResult<IReadOnlyList<RideChatMessageDto>>> Chat(Guid rideOfferId, CancellationToken cancellationToken) =>
        Ok(await _rideService.RideChatAsync(User.GetUserId(), rideOfferId, cancellationToken));

    [HttpPost("{rideOfferId:guid}/chat/messages")]
    public async Task<ActionResult<RideChatMessageDto>> SendChat(
        Guid rideOfferId,
        SendRideChatMessageRequest request,
        CancellationToken cancellationToken) =>
        Ok(await _rideService.SendRideChatMessageAsync(User.GetUserId(), rideOfferId, request, cancellationToken));

    [HttpPost("{rideId:guid}/chat/attachments")]
    [Consumes("multipart/form-data")]
    public async Task<ActionResult<RideChatMessageDto>> UploadChatAttachment(
        Guid rideId,
        [FromForm] RideChatAttachmentUploadRequest request,
        CancellationToken cancellationToken)
    {
        if (request.File is null || request.File.Length == 0)
        {
            throw new ApiException("File is required.");
        }

        await using var stream = request.File.OpenReadStream();
        var upload = new ChatAttachmentUpload(
            stream,
            request.File.FileName,
            request.File.ContentType,
            request.File.Length,
            request.Caption);
        return Ok(await _rideService.UploadChatAttachmentAsync(rideId, User.GetUserId(), upload, cancellationToken));
    }

    [HttpPost("{rideOfferId:guid}/start")]
    public async Task<ActionResult<RideOfferDto>> Start(Guid rideOfferId, CancellationToken cancellationToken)
    {
        var ride = await _rideService.StartRideAsync(User.GetUserId(), rideOfferId, cancellationToken);
        await _trackingHubContext.Clients
            .Group(TrackingHub.RideGroupName(rideOfferId.ToString()))
            .SendAsync("TrackingStarted", new { rideId = rideOfferId }, cancellationToken);
        return Ok(ride);
    }

    [HttpPost("{rideOfferId:guid}/complete")]
    public async Task<ActionResult<RideOfferDto>> Complete(Guid rideOfferId, CancellationToken cancellationToken)
    {
        var ride = await _rideService.CompleteRideAsync(User.GetUserId(), rideOfferId, cancellationToken);
        await _trackingHubContext.Clients
            .Group(TrackingHub.RideGroupName(rideOfferId.ToString()))
            .SendAsync("TrackingStopped", new { rideId = rideOfferId, status = ride.Status.ToString() }, cancellationToken);
        return Ok(ride);
    }

    [HttpPost("{rideOfferId:guid}/cancel")]
    public async Task<ActionResult<RideOfferDto>> Cancel(
        Guid rideOfferId,
        [FromBody] CancelActionRequest? request,
        CancellationToken cancellationToken)
    {
        var ride = await _rideService.CancelRideAsync(User.GetUserId(), rideOfferId, request?.Reason, cancellationToken);
        await _trackingHubContext.Clients
            .Group(TrackingHub.RideGroupName(rideOfferId.ToString()))
            .SendAsync("TrackingStopped", new { rideId = rideOfferId, status = ride.Status.ToString() }, cancellationToken);
        return Ok(ride);
    }

    [HttpPost("bookings/{bookingId:guid}/cancel")]
    public async Task<ActionResult<RideBookingDto>> CancelBooking(
        Guid bookingId,
        [FromBody] CancelActionRequest? request,
        CancellationToken cancellationToken) =>
        Ok(await _bookingService.CancelAsync(User.GetUserId(), bookingId, request?.Reason, cancellationToken));
}

public sealed class RideChatAttachmentUploadRequest
{
    public IFormFile File { get; set; } = default!;
    public string? Caption { get; set; }
}
