namespace NewCarPool.Application.DTOs.Reviews;

public sealed record ReviewDto(
    Guid Id,
    Guid RideOfferId,
    Guid ReviewerId,
    Guid RevieweeId,
    int Rating,
    string? Comment,
    DateTime CreatedAtUtc);

public sealed record AddReviewRequest(Guid RideOfferId, Guid RevieweeId, int Rating, string? Comment);
