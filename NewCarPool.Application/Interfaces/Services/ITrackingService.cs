using NewCarPool.Application.DTOs.Tracking;

namespace NewCarPool.Application.Interfaces.Services;

public interface ITrackingService
{
    Task<LocationUpdateDto> AddLocationUpdateAsync(Guid driverId, LocationUpdateRequest request, CancellationToken cancellationToken);
}
