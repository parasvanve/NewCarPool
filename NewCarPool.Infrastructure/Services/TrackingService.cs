using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Tracking;
using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Application.Interfaces.Services;
using NewCarPool.Domain.Entities;
using NewCarPool.Domain.Enums;

namespace NewCarPool.Infrastructure.Services;

public sealed class TrackingService : ITrackingService
{
    private readonly IRideRepository _rides;
    private readonly IUnitOfWork _unitOfWork;

    public TrackingService(IRideRepository rides, IUnitOfWork unitOfWork)
    {
        _rides = rides;
        _unitOfWork = unitOfWork;
    }

    public async Task<LocationUpdateDto> AddLocationUpdateAsync(Guid driverId, LocationUpdateRequest request, CancellationToken cancellationToken)
    {
        var ride = await _rides.GetRideByIdAsync(request.RideOfferId, cancellationToken)
            ?? throw new ApiException("Ride not found.", 404);

        if (ride.DriverId != driverId)
        {
            throw new ApiException("Only the driver can publish tracking for this ride.", 403);
        }

        if (ride.Status is not (RideStatus.Started or RideStatus.Open or RideStatus.Full))
        {
            throw new ApiException("Tracking is not available for this ride status.");
        }

        var locationUpdate = new RideLocationUpdate
        {
            Id = Guid.NewGuid(),
            RideOfferId = ride.Id,
            DriverId = driverId,
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            Heading = request.Heading,
            SpeedKph = request.SpeedKph
        };

        await _rides.AddLocationUpdateAsync(locationUpdate, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return new LocationUpdateDto(
            locationUpdate.RideOfferId,
            locationUpdate.DriverId,
            locationUpdate.Latitude,
            locationUpdate.Longitude,
            locationUpdate.Heading,
            locationUpdate.SpeedKph,
            locationUpdate.CreatedAtUtc);
    }
}
