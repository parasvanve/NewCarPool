using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using NewCarPool.Api.Extensions;
using NewCarPool.Application.DTOs.Rides;
using NewCarPool.Application.Interfaces.Services;

namespace NewCarPool.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public sealed class BookingsController : ControllerBase
{
    private readonly IBookingService _bookingService;

    public BookingsController(IBookingService bookingService) => _bookingService = bookingService;

    [HttpPost("{bookingId:guid}/accept")]
    public async Task<ActionResult<RideBookingDto>> Accept(Guid bookingId, CancellationToken cancellationToken) =>
        Ok(await _bookingService.AcceptAsync(User.GetUserId(), bookingId, cancellationToken));

    [HttpPost("{bookingId:guid}/reject")]
    public async Task<ActionResult<RideBookingDto>> Reject(Guid bookingId, CancellationToken cancellationToken) =>
        Ok(await _bookingService.RejectAsync(User.GetUserId(), bookingId, cancellationToken));

    [HttpPost("{bookingId:guid}/cancel")]
    public async Task<ActionResult<RideBookingDto>> Cancel(
        Guid bookingId,
        [FromBody] CancelActionRequest? request,
        CancellationToken cancellationToken) =>
        Ok(await _bookingService.CancelAsync(User.GetUserId(), bookingId, request?.Reason, cancellationToken));

    [HttpGet("history")]
    public async Task<ActionResult<IReadOnlyList<RideBookingDto>>> History(CancellationToken cancellationToken) =>
        Ok(await _bookingService.HistoryAsync(User.GetUserId(), cancellationToken));
}
