using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using NewCarPool.Api.Extensions;
using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Rides;
using NewCarPool.Application.Interfaces.Services;

namespace NewCarPool.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public sealed class RidesController : ControllerBase
{
    private readonly IRideService _rideService;

    public RidesController(IRideService rideService) => _rideService = rideService;

    [HttpPost("offer")]
    public async Task<ActionResult<RideOfferDto>> Offer(CreateRideOfferRequest request, CancellationToken cancellationToken) =>
        Ok(await _rideService.OfferRideAsync(User.GetUserId(), request, cancellationToken));

    [HttpGet("search")]
    public async Task<ActionResult<PagedResult<RideOfferDto>>> Search([FromQuery] SearchRideRequest request, CancellationToken cancellationToken) =>
        Ok(await _rideService.SearchAsync(request, cancellationToken));

    [HttpGet("{rideOfferId:guid}")]
    public async Task<ActionResult<RideOfferDto>> Details(Guid rideOfferId, CancellationToken cancellationToken) =>
        Ok(await _rideService.DetailsAsync(rideOfferId, cancellationToken));

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

    [HttpPost("{rideOfferId:guid}/start")]
    public async Task<ActionResult<RideOfferDto>> Start(Guid rideOfferId, CancellationToken cancellationToken) =>
        Ok(await _rideService.StartRideAsync(User.GetUserId(), rideOfferId, cancellationToken));

    [HttpPost("{rideOfferId:guid}/complete")]
    public async Task<ActionResult<RideOfferDto>> Complete(Guid rideOfferId, CancellationToken cancellationToken) =>
        Ok(await _rideService.CompleteRideAsync(User.GetUserId(), rideOfferId, cancellationToken));

    [HttpPost("{rideOfferId:guid}/cancel")]
    public async Task<ActionResult<RideOfferDto>> Cancel(Guid rideOfferId, CancellationToken cancellationToken) =>
        Ok(await _rideService.CancelRideAsync(User.GetUserId(), rideOfferId, cancellationToken));
}
