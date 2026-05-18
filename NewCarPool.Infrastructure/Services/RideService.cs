using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Rides;
using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Application.Interfaces.Services;
using NewCarPool.Domain.Entities;
using NewCarPool.Domain.Enums;

namespace NewCarPool.Infrastructure.Services;

public sealed class RideService : IRideService
{
    private readonly IRideRepository _rides;
    private readonly IUserRepository _users;
    private readonly IGenericRepository<RideOffer> _rideOffers;
    private readonly IUnitOfWork _unitOfWork;

    public RideService(IRideRepository rides, IUserRepository users, IGenericRepository<RideOffer> rideOffers, IUnitOfWork unitOfWork)
    {
        _rides = rides;
        _users = users;
        _rideOffers = rideOffers;
        _unitOfWork = unitOfWork;
    }

    public async Task<RideOfferDto> OfferRideAsync(Guid driverId, CreateRideOfferRequest request, CancellationToken cancellationToken)
    {
        _ = await _users.GetByIdAsync(driverId, cancellationToken) ?? throw new ApiException("Driver not found.", 404);
        ValidateRideOffer(request);

        var ride = new RideOffer
        {
            Id = Guid.NewGuid(),
            DriverId = driverId,
            VehicleId = request.VehicleId,
            OriginName = request.Origin.Name,
            OriginLatitude = request.Origin.Latitude,
            OriginLongitude = request.Origin.Longitude,
            DestinationName = request.Destination.Name,
            DestinationLatitude = request.Destination.Latitude,
            DestinationLongitude = request.Destination.Longitude,
            DepartureTimeUtc = request.DepartureTimeUtc,
            AvailableSeats = request.AvailableSeats,
            PricePerSeat = request.PricePerSeat,
            VehicleName = request.VehicleName,
            VehicleNumber = request.VehicleNumber
        };

        await _rides.AddRideAsync(ride, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        ride = await _rides.GetRideByIdAsync(ride.Id, cancellationToken) ?? ride;
        return MapRide(ride);
    }

    public async Task<PagedResult<RideOfferDto>> SearchAsync(SearchRideRequest request, CancellationToken cancellationToken)
    {
        var result = await _rides.SearchAsync(request, cancellationToken);
        return new PagedResult<RideOfferDto>(
            result.Items.Select(MapRide).ToList(),
            result.Page,
            result.PageSize,
            result.TotalCount);
    }

    public async Task<RideOfferDto> DetailsAsync(Guid rideOfferId, CancellationToken cancellationToken) =>
        MapRide(await _rides.GetRideByIdAsync(rideOfferId, cancellationToken) ?? throw new ApiException("Ride not found.", 404));

    public async Task<RideOfferDto> UpdateRideAsync(Guid driverId, Guid rideOfferId, CreateRideOfferRequest request, CancellationToken cancellationToken)
    {
        ValidateRideOffer(request);
        var ride = await _rides.GetRideByIdAsync(rideOfferId, cancellationToken) ?? throw new ApiException("Ride not found.", 404);
        if (ride.DriverId != driverId)
        {
            throw new ApiException("Only the driver can update this ride.", 403);
        }

        if (ride.Status is RideStatus.Started or RideStatus.Completed)
        {
            throw new ApiException("Started or completed rides cannot be edited.");
        }

        ride.VehicleId = request.VehicleId;
        ride.OriginName = request.Origin.Name;
        ride.OriginLatitude = request.Origin.Latitude;
        ride.OriginLongitude = request.Origin.Longitude;
        ride.DestinationName = request.Destination.Name;
        ride.DestinationLatitude = request.Destination.Latitude;
        ride.DestinationLongitude = request.Destination.Longitude;
        ride.DepartureTimeUtc = request.DepartureTimeUtc;
        ride.AvailableSeats = request.AvailableSeats;
        ride.PricePerSeat = request.PricePerSeat;
        ride.VehicleName = request.VehicleName;
        ride.VehicleNumber = request.VehicleNumber;
        ride.UpdatedAtUtc = DateTime.UtcNow;
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return MapRide(ride);
    }

    public async Task DeleteRideAsync(Guid driverId, Guid rideOfferId, CancellationToken cancellationToken)
    {
        var ride = await _rides.GetRideByIdAsync(rideOfferId, cancellationToken) ?? throw new ApiException("Ride not found.", 404);
        if (ride.DriverId != driverId)
        {
            throw new ApiException("Only the driver can delete this ride.", 403);
        }

        if (ride.Status == RideStatus.Started)
        {
            throw new ApiException("Started rides cannot be deleted.");
        }

        _rideOffers.Delete(ride);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
    }

    public Task<RideOfferDto> CancelRideAsync(Guid driverId, Guid rideOfferId, CancellationToken cancellationToken) =>
        ChangeRideStatusAsync(driverId, rideOfferId, RideStatus.Cancelled, cancellationToken);

    public async Task<RideBookingDto> BookRideAsync(Guid passengerId, BookRideRequest request, CancellationToken cancellationToken)
    {
        var passenger = await _users.GetByIdAsync(passengerId, cancellationToken)
            ?? throw new ApiException("Passenger not found.", 404);
        var ride = await _rides.GetRideByIdAsync(request.RideOfferId, cancellationToken)
            ?? throw new ApiException("Ride not found.", 404);

        if (ride.DriverId == passengerId)
        {
            throw new ApiException("Driver cannot book their own ride.");
        }

        if (ride.Status != RideStatus.Open)
        {
            throw new ApiException("Ride is not open for booking.");
        }

        if (request.SeatsBooked <= 0 || request.SeatsBooked > ride.AvailableSeats)
        {
            throw new ApiException("Requested seats are not available.");
        }

        ride.AvailableSeats -= request.SeatsBooked;
        ride.Status = ride.AvailableSeats == 0 ? RideStatus.Full : RideStatus.Open;
        ride.UpdatedAtUtc = DateTime.UtcNow;

        var booking = new RideBooking
        {
            Id = Guid.NewGuid(),
            PassengerId = passengerId,
            RideOfferId = ride.Id,
            SeatsBooked = request.SeatsBooked
        };

        await _rides.AddBookingAsync(booking, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        booking.Passenger = passenger;
        return MapBooking(booking);
    }

    public Task<RideOfferDto> StartRideAsync(Guid driverId, Guid rideOfferId, CancellationToken cancellationToken) =>
        ChangeRideStatusAsync(driverId, rideOfferId, RideStatus.Started, cancellationToken);

    public Task<RideOfferDto> CompleteRideAsync(Guid driverId, Guid rideOfferId, CancellationToken cancellationToken) =>
        ChangeRideStatusAsync(driverId, rideOfferId, RideStatus.Completed, cancellationToken);

    private async Task<RideOfferDto> ChangeRideStatusAsync(Guid driverId, Guid rideOfferId, RideStatus status, CancellationToken cancellationToken)
    {
        var ride = await _rides.GetRideByIdAsync(rideOfferId, cancellationToken)
            ?? throw new ApiException("Ride not found.", 404);
        if (ride.DriverId != driverId)
        {
            throw new ApiException("Only the driver can update this ride.", 403);
        }

        ride.Status = status;
        ride.UpdatedAtUtc = DateTime.UtcNow;
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return MapRide(ride);
    }

    private static void ValidateRideOffer(CreateRideOfferRequest request)
    {
        if (request.AvailableSeats <= 0)
        {
            throw new ApiException("Available seats must be greater than zero.");
        }

        if (request.PricePerSeat < 0)
        {
            throw new ApiException("Price per seat cannot be negative.");
        }

        if (request.DepartureTimeUtc <= DateTime.UtcNow)
        {
            throw new ApiException("Departure time must be in the future.");
        }
    }

    private static RideOfferDto MapRide(RideOffer ride) =>
        new(
            ride.Id,
            ride.DriverId,
            ride.VehicleId,
            ride.Driver?.FullName ?? string.Empty,
            new GeoPointDto(ride.OriginName, ride.OriginLatitude, ride.OriginLongitude),
            new GeoPointDto(ride.DestinationName, ride.DestinationLatitude, ride.DestinationLongitude),
            ride.DepartureTimeUtc,
            ride.AvailableSeats,
            ride.PricePerSeat,
            ride.VehicleName,
            ride.VehicleNumber,
            ride.RoutePolyline,
            ride.DistanceKm,
            ride.EtaMinutes,
            ride.Status);

    private static RideBookingDto MapBooking(RideBooking booking) =>
        new(
            booking.Id,
            booking.RideOfferId,
            booking.PassengerId,
            booking.Passenger?.FullName ?? string.Empty,
            booking.SeatsBooked,
            booking.Status,
            booking.CreatedAtUtc);
}
