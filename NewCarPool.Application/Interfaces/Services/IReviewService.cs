using NewCarPool.Application.DTOs.Reviews;

namespace NewCarPool.Application.Interfaces.Services;

public interface IReviewService
{
    Task<ReviewDto> AddAsync(Guid reviewerId, AddReviewRequest request, CancellationToken cancellationToken);
    Task<IReadOnlyList<ReviewDto>> GetForUserAsync(Guid userId, CancellationToken cancellationToken);
    Task<decimal> AverageRatingAsync(Guid userId, CancellationToken cancellationToken);
}
