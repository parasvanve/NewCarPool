using NewCarPool.Application.DTOs.Tracking;

namespace NewCarPool.Application.Interfaces.Services;

public interface ITrackingService
{
    Task<LocationUpdateDto> AddLocationUpdateAsync(Guid driverId, LocationUpdateRequest request, CancellationToken cancellationToken);
    Task<LocationUpdateDto> GetLatestLocationAsync(Guid userId, Guid rideOfferId, CancellationToken cancellationToken);
}
