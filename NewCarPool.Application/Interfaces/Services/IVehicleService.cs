using NewCarPool.Application.DTOs.Vehicles;

namespace NewCarPool.Application.Interfaces.Services;

public interface IVehicleService
{
    Task<VehicleDto> AddAsync(Guid ownerId, UpsertVehicleRequest request, CancellationToken cancellationToken);
    Task<IReadOnlyList<VehicleDto>> GetMineAsync(Guid ownerId, CancellationToken cancellationToken);
    Task<VehicleDto> UpdateAsync(Guid ownerId, Guid vehicleId, UpsertVehicleRequest request, CancellationToken cancellationToken);
    Task DeleteAsync(Guid ownerId, Guid vehicleId, CancellationToken cancellationToken);
}
