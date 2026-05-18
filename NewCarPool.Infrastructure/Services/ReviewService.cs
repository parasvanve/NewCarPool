using Microsoft.EntityFrameworkCore;
using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Reviews;
using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Application.Interfaces.Services;
using NewCarPool.Domain.Entities;

namespace NewCarPool.Infrastructure.Services;

public sealed class ReviewService : IReviewService
{
    private readonly IGenericRepository<Review> _reviews;
    private readonly IUnitOfWork _unitOfWork;

    public ReviewService(IGenericRepository<Review> reviews, IUnitOfWork unitOfWork)
    {
        _reviews = reviews;
        _unitOfWork = unitOfWork;
    }

    public async Task<ReviewDto> AddAsync(Guid reviewerId, AddReviewRequest request, CancellationToken cancellationToken)
    {
        if (request.Rating is < 1 or > 5)
        {
            throw new ApiException("Rating must be between 1 and 5.");
        }

        var review = new Review
        {
            Id = Guid.NewGuid(),
            ReviewerId = reviewerId,
            RideOfferId = request.RideOfferId,
            RevieweeId = request.RevieweeId,
            Rating = request.Rating,
            Comment = request.Comment
        };
        await _reviews.AddAsync(review, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return Map(review);
    }

    public async Task<IReadOnlyList<ReviewDto>> GetForUserAsync(Guid userId, CancellationToken cancellationToken) =>
        await _reviews.Query().Where(x => x.RevieweeId == userId).OrderByDescending(x => x.CreatedAtUtc).Select(x => Map(x)).ToListAsync(cancellationToken);

    public async Task<decimal> AverageRatingAsync(Guid userId, CancellationToken cancellationToken)
    {
        var ratings = _reviews.Query().Where(x => x.RevieweeId == userId);
        if (!await ratings.AnyAsync(cancellationToken))
        {
            return 0m;
        }

        return (decimal)await ratings.AverageAsync(x => x.Rating, cancellationToken);
    }

    private static ReviewDto Map(Review review) =>
        new(review.Id, review.RideOfferId, review.ReviewerId, review.RevieweeId, review.Rating, review.Comment, review.CreatedAtUtc);
}
