using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Rides;
using NewCarPool.Domain.Entities;

namespace NewCarPool.Application.Interfaces.Repositories;

public interface IRideRepository
{
    Task AddRideAsync(RideOffer ride, CancellationToken cancellationToken);
    Task<RideOffer?> GetRideByIdAsync(Guid id, CancellationToken cancellationToken);
    Task<PagedResult<RideOffer>> SearchAsync(SearchRideRequest request, CancellationToken cancellationToken);
    Task AddBookingAsync(RideBooking booking, CancellationToken cancellationToken);
    Task<RideBooking?> GetBookingAsync(Guid id, CancellationToken cancellationToken);
    Task AddLocationUpdateAsync(RideLocationUpdate locationUpdate, CancellationToken cancellationToken);
}
