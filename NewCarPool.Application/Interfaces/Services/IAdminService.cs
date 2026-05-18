using NewCarPool.Application.DTOs.Admin;
using NewCarPool.Application.DTOs.Rides;
using NewCarPool.Application.DTOs.Users;

namespace NewCarPool.Application.Interfaces.Services;

public interface IAdminService
{
    Task<IReadOnlyList<UserProfileDto>> GetUsersAsync(CancellationToken cancellationToken);
    Task BlockUserAsync(Guid userId, CancellationToken cancellationToken);
    Task VerifyVehicleAsync(Guid vehicleId, CancellationToken cancellationToken);
    Task<IReadOnlyList<RideOfferDto>> GetRidesAsync(CancellationToken cancellationToken);
    Task<DashboardStatsDto> GetStatsAsync(CancellationToken cancellationToken);
}
