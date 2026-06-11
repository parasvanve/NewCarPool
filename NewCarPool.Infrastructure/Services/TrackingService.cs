using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Tracking;
using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Application.Interfaces.Services;
using NewCarPool.Domain.Entities;
using NewCarPool.Domain.Enums;
using NewCarPool.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace NewCarPool.Infrastructure.Services;

public sealed class TrackingService : ITrackingService
{
    private readonly IRideRepository _rides;
    private readonly IUnitOfWork _unitOfWork;
    private readonly NewCarPoolDbContext _dbContext;

    public TrackingService(IRideRepository rides, IUnitOfWork unitOfWork, NewCarPoolDbContext dbContext)
    {
        _rides = rides;
        _unitOfWork = unitOfWork;
        _dbContext = dbContext;
    }

    public async Task<LocationUpdateDto> AddLocationUpdateAsync(Guid driverId, LocationUpdateRequest request, CancellationToken cancellationToken)
    {
        var ride = await _rides.GetRideByIdAsync(request.RideOfferId, cancellationToken)
            ?? throw new ApiException("Ride not found.", 404);

        if (ride.DriverId != driverId)
        {
            throw new ApiException("Only the driver can publish tracking for this ride.", 403);
        }

        if (ride.Status != RideStatus.Started)
        {
            throw new ApiException("Tracking is not available for this ride status.");
        }

        var createdAtUtc = DateTime.UtcNow;
        var locationUpdate = new RideLocationUpdate
        {
            Id = Guid.NewGuid(),
            RideOfferId = ride.Id,
            DriverId = driverId,
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            Heading = request.Heading,
            SpeedKph = request.SpeedKph,
            CreatedAtUtc = createdAtUtc
        };
        ride.LastDriverLatitude = request.Latitude;
        ride.LastDriverLongitude = request.Longitude;
        ride.LastDriverHeading = request.Heading;
        ride.LastDriverSpeedKph = request.SpeedKph;
        ride.LastDriverLocationAtUtc = createdAtUtc;
        ride.UpdatedAtUtc = createdAtUtc;

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

    public async Task<LocationUpdateDto> GetLatestLocationAsync(Guid userId, Guid rideOfferId, CancellationToken cancellationToken)
    {
        var ride = await _rides.GetRideByIdAsync(rideOfferId, cancellationToken)
            ?? throw new ApiException("Ride not found.", 404);

        await EnsureCanAccessTrackingAsync(userId, rideOfferId, cancellationToken);

        var latest = await _dbContext.RideLocationUpdates
            .AsNoTracking()
            .Where(x => x.RideOfferId == rideOfferId)
            .OrderByDescending(x => x.CreatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (latest == null)
        {
            throw new ApiException("Waiting for driver location.", 404);
        }

        return new LocationUpdateDto(
            latest.RideOfferId,
            latest.DriverId,
            latest.Latitude,
            latest.Longitude,
            latest.Heading,
            latest.SpeedKph,
            latest.CreatedAtUtc);
    }

    public async Task EnsureCanAccessTrackingAsync(Guid userId, Guid rideOfferId, CancellationToken cancellationToken)
    {
        var ride = await _dbContext.RideOffers
            .AsNoTracking()
            .Where(x => x.Id == rideOfferId)
            .Select(x => new { x.Id, x.DriverId, x.Status })
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw new ApiException("Ride not found.", 404);

        if (ride.Status != RideStatus.Started)
        {
            throw new ApiException("Tracking is not available for this ride status.");
        }

        if (ride.DriverId == userId)
        {
            return;
        }

        var isBookedPassenger = await _dbContext.RideBookings
            .AsNoTracking()
            .AnyAsync(
                x => x.RideOfferId == rideOfferId
                     && x.PassengerId == userId
                     && x.Status == BookingStatus.Confirmed,
                cancellationToken);

        if (!isBookedPassenger)
        {
            throw new ApiException("You are not allowed to access this ride location.", 403);
        }
    }
}
