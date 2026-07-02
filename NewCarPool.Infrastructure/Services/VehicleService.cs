using Microsoft.EntityFrameworkCore;
using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Vehicles;
using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Application.Interfaces.Services;
using NewCarPool.Domain.Entities;

namespace NewCarPool.Infrastructure.Services;

public sealed class VehicleService : IVehicleService
{
    private readonly IGenericRepository<Vehicle> _vehicles;
    private readonly IUnitOfWork _unitOfWork;

    public VehicleService(IGenericRepository<Vehicle> vehicles, IUnitOfWork unitOfWork)
    {
        _vehicles = vehicles;
        _unitOfWork = unitOfWork;
    }

    public async Task<VehicleDto> AddAsync(Guid ownerId, UpsertVehicleRequest request, CancellationToken cancellationToken)
    {
        Validate(request);
         var vehicle = new Vehicle
        {
            Id = Guid.NewGuid(),
            OwnerId = ownerId,
            VehicleName = request.VehicleName.Trim(),
            VehicleNumber = request.VehicleNumber.Trim().ToUpperInvariant(),
            VehicleType = request.VehicleType,
            Color = request.Color.Trim(),
            Seats = request.Seats,
            RcImagePath = request.RcImagePath,
            VehicleImagePath = request.VehicleImagePath
        };
        await _vehicles.AddAsync(vehicle, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return Map(vehicle);
    }

    public async Task<IReadOnlyList<VehicleDto>> GetMineAsync(
     Guid ownerId,
     CancellationToken cancellationToken)
    {
        return await _vehicles.Query()
            .AsNoTracking()
            .Where(x => x.OwnerId == ownerId)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Select(x => new VehicleDto(
                x.Id,
                x.VehicleName,
                x.VehicleNumber,
                x.VehicleType,
                x.Color,
                x.Seats,
                x.RcImagePath,
                x.VehicleImagePath,
                x.IsVerified))
            .ToListAsync(cancellationToken);
    }

    public async Task<VehicleDto> UpdateAsync(Guid ownerId, Guid vehicleId, UpsertVehicleRequest request, CancellationToken cancellationToken)
    {
        Validate(request);
        var vehicle = await _vehicles.GetByIdAsync(vehicleId, cancellationToken) ?? throw new ApiException("Vehicle not found.", 404);
        if (vehicle.OwnerId != ownerId)
        {
            throw new ApiException("You cannot update this vehicle.", 403);
        }

        vehicle.VehicleName = request.VehicleName.Trim();
        vehicle.VehicleNumber = request.VehicleNumber.Trim().ToUpperInvariant();
        vehicle.VehicleType = request.VehicleType;
        vehicle.Color = request.Color.Trim();
        vehicle.Seats = request.Seats;
        vehicle.RcImagePath = request.RcImagePath;
        vehicle.VehicleImagePath = request.VehicleImagePath;
        vehicle.UpdatedAtUtc = DateTime.UtcNow;
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return Map(vehicle);
    }

    public async Task DeleteAsync(Guid ownerId, Guid vehicleId, CancellationToken cancellationToken)
    {
        var vehicle = await _vehicles.GetByIdAsync(vehicleId, cancellationToken) ?? throw new ApiException("Vehicle not found.", 404);
        if (vehicle.OwnerId != ownerId)
        {
            throw new ApiException("You cannot delete this vehicle.", 403);
        }

        _vehicles.Delete(vehicle);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
    }

    private static void Validate(UpsertVehicleRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.VehicleName) ||
            string.IsNullOrWhiteSpace(request.VehicleNumber))
        {
            throw new ApiException("Vehicle name and number are required.");
        }

        if (request.Seats is < 4 or > 8)
        {
            throw new ApiException("Vehicle seating capacity must be between 4 and 8 seats.");
        }
    }

    private static VehicleDto Map(Vehicle vehicle) =>
        new(vehicle.Id, vehicle.VehicleName, vehicle.VehicleNumber, vehicle.VehicleType, vehicle.Color, vehicle.Seats, vehicle.RcImagePath, vehicle.VehicleImagePath, vehicle.IsVerified);
}
