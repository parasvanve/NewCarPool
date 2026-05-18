using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using NewCarPool.Api.Extensions;
using NewCarPool.Application.DTOs.Reviews;
using NewCarPool.Application.Interfaces.Services;

namespace NewCarPool.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public sealed class ReviewsController : ControllerBase
{
    private readonly IReviewService _reviewService;

    public ReviewsController(IReviewService reviewService) => _reviewService = reviewService;

    [HttpPost]
    public async Task<ActionResult<ReviewDto>> Add(AddReviewRequest request, CancellationToken cancellationToken) =>
        Ok(await _reviewService.AddAsync(User.GetUserId(), request, cancellationToken));

    [HttpGet("user/{userId:guid}")]
    public async Task<ActionResult<IReadOnlyList<ReviewDto>>> ForUser(Guid userId, CancellationToken cancellationToken) =>
        Ok(await _reviewService.GetForUserAsync(userId, cancellationToken));

    [HttpGet("user/{userId:guid}/average")]
    public async Task<ActionResult<object>> Average(Guid userId, CancellationToken cancellationToken) =>
        Ok(new { userId, averageRating = await _reviewService.AverageRatingAsync(userId, cancellationToken) });
}
