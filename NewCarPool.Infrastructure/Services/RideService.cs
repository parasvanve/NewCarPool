using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Rides;
using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Application.Interfaces.Services;
using Microsoft.EntityFrameworkCore;
using System.Data;
using NewCarPool.Domain.Entities;
using NewCarPool.Domain.Enums;

namespace NewCarPool.Infrastructure.Services;

public sealed class RideService : IRideService
{
    private readonly IRideRepository _rides;
    private readonly IUserRepository _users;
    private readonly IGenericRepository<RideOffer> _rideOffers;
    private readonly IGenericRepository<RideBooking> _rideBookings;
    private readonly IGenericRepository<RideChatGroup> _chatGroups;
    private readonly IGenericRepository<RideChatMessage> _chatMessages;
    private readonly IUnitOfWork _unitOfWork;
    private readonly Data.NewCarPoolDbContext _dbContext;

    public RideService(
        IRideRepository rides,
        IUserRepository users,
        IGenericRepository<RideOffer> rideOffers,
        IGenericRepository<RideBooking> rideBookings,
        IGenericRepository<RideChatGroup> chatGroups,
        IGenericRepository<RideChatMessage> chatMessages,
        Data.NewCarPoolDbContext dbContext,
        IUnitOfWork unitOfWork)
    {
        _rides = rides;
        _users = users;
        _rideOffers = rideOffers;
        _rideBookings = rideBookings;
        _chatGroups = chatGroups;
        _chatMessages = chatMessages;
        _dbContext = dbContext;
        _unitOfWork = unitOfWork;
    }

    public async Task<RideOfferDto> OfferRideAsync(Guid driverId, CreateRideOfferRequest request, CancellationToken cancellationToken)
    {
        _ = await _users.GetByIdAsync(driverId, cancellationToken) ?? throw new ApiException("Driver not found.", 404);
        ValidateRideOffer(request);
        await EnsureVehicleOwnershipAsync(driverId, request.VehicleId, cancellationToken);

        var ride = new RideOffer
        {
            Id = Guid.NewGuid(),
            DriverId = driverId,
            VehicleId = request.VehicleId,
            OriginName = Truncate(request.Origin.Name, 300),
            OriginAddress = Truncate(request.Origin.Address ?? request.Origin.Name, 500),
            OriginLatitude = request.Origin.Latitude,
            OriginLongitude = request.Origin.Longitude,
            DestinationName = Truncate(request.Destination.Name, 300),
            DestinationAddress = Truncate(request.Destination.Address ?? request.Destination.Name, 500),
            DestinationLatitude = request.Destination.Latitude,
            DestinationLongitude = request.Destination.Longitude,
            DepartureTimeUtc = request.DepartureTimeUtc,
            AvailableSeats = request.AvailableSeats,
            PricePerSeat = request.PricePerSeat,
            VehicleName = request.VehicleName,
            VehicleNumber = request.VehicleNumber,
            IntermediateStops = (request.IntermediateStops ?? [])
                .OrderBy(x => x.Order)
                .Select(x => new RideStop
                {
                    Id = Guid.NewGuid(),
                    Name = Truncate(x.Name, 200),
                    Address = Truncate(x.Address ?? x.Name, 500),
                    Latitude = x.Latitude,
                    Longitude = x.Longitude,
                    StopOrder = x.Order
                })
                .ToList()
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
        await EnsureVehicleOwnershipAsync(driverId, request.VehicleId, cancellationToken);
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
        ride.OriginName = Truncate(request.Origin.Name, 300);
        ride.OriginAddress = Truncate(request.Origin.Address ?? request.Origin.Name, 500);
        ride.OriginLatitude = request.Origin.Latitude;
        ride.OriginLongitude = request.Origin.Longitude;
        ride.DestinationName = Truncate(request.Destination.Name, 300);
        ride.DestinationAddress = Truncate(request.Destination.Address ?? request.Destination.Name, 500);
        ride.DestinationLatitude = request.Destination.Latitude;
        ride.DestinationLongitude = request.Destination.Longitude;
        ride.DepartureTimeUtc = request.DepartureTimeUtc;
        ride.AvailableSeats = request.AvailableSeats;
        ride.PricePerSeat = request.PricePerSeat;
        ride.VehicleName = request.VehicleName;
        ride.VehicleNumber = request.VehicleNumber;
        ride.IntermediateStops.Clear();
        foreach (var stop in (request.IntermediateStops ?? []).OrderBy(x => x.Order))
        {
            ride.IntermediateStops.Add(new RideStop
            {
                Id = Guid.NewGuid(),
                RideOfferId = ride.Id,
                Name = Truncate(stop.Name, 200),
                Address = Truncate(stop.Address ?? stop.Name, 500),
                Latitude = stop.Latitude,
                Longitude = stop.Longitude,
                StopOrder = stop.Order
            });
        }
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
        await using var transaction = await _dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);
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
        await EnsureRideChatGroupAsync(ride.Id, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        booking.Passenger = passenger;
        return MapBooking(booking);
    }

    public async Task<IReadOnlyList<RideBookingDto>> ParticipantsAsync(Guid rideOfferId, CancellationToken cancellationToken)
    {
        var participants = await _rideBookings.Query()
            .Where(x => x.RideOfferId == rideOfferId && x.Status == BookingStatus.Confirmed)
            .Include(x => x.Passenger)
            .OrderBy(x => x.CreatedAtUtc)
            .ToListAsync(cancellationToken);
        return participants.Select(MapBooking).ToList();
    }

    public async Task<IReadOnlyList<RideChatMessageDto>> RideChatAsync(Guid userId, Guid rideOfferId, CancellationToken cancellationToken)
    {
        await EnsureRideAccessAsync(userId, rideOfferId, cancellationToken);
        var group = await EnsureRideChatGroupAsync(rideOfferId, cancellationToken);
        var messages = await _chatMessages.Query()
            .Where(x => x.RideChatGroupId == group.Id)
            .Include(x => x.SenderUser)
            .OrderBy(x => x.CreatedAtUtc)
            .Take(200)
            .ToListAsync(cancellationToken);
        return messages.Select(m => new RideChatMessageDto(
            m.Id,
            rideOfferId,
            m.SenderUserId,
            m.SenderUser.FullName,
            m.Message,
            m.CreatedAtUtc)).ToList();
    }

    public async Task<RideChatMessageDto> SendRideChatMessageAsync(Guid userId, Guid rideOfferId, SendRideChatMessageRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Message))
        {
            throw new ApiException("Message cannot be empty.");
        }

        var sender = await _users.GetByIdAsync(userId, cancellationToken) ?? throw new ApiException("User not found.", 404);
        await EnsureRideAccessAsync(userId, rideOfferId, cancellationToken);
        var group = await EnsureRideChatGroupAsync(rideOfferId, cancellationToken);
        var message = new RideChatMessage
        {
            Id = Guid.NewGuid(),
            RideChatGroupId = group.Id,
            SenderUserId = userId,
            Message = request.Message.Trim()
        };
        await _chatMessages.AddAsync(message, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return new RideChatMessageDto(message.Id, rideOfferId, userId, sender.FullName, message.Message, message.CreatedAtUtc);
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
        if (request.Origin.Latitude is < -90 or > 90 || request.Origin.Longitude is < -180 or > 180)
        {
            throw new ApiException("Pickup coordinates are invalid.");
        }

        if (request.Destination.Latitude is < -90 or > 90 || request.Destination.Longitude is < -180 or > 180)
        {
            throw new ApiException("Destination coordinates are invalid.");
        }

        if (string.IsNullOrWhiteSpace(request.Origin.Name) || string.IsNullOrWhiteSpace(request.Destination.Name))
        {
            throw new ApiException("Pickup and destination are required.");
        }

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

    private async Task EnsureVehicleOwnershipAsync(Guid driverId, Guid vehicleId, CancellationToken cancellationToken)
    {
        var vehicleExists = await _dbContext.Vehicles
            .AsNoTracking()
            .AnyAsync(x => x.Id == vehicleId, cancellationToken);
        if (!vehicleExists)
        {
            throw new ApiException("Selected vehicle does not exist.", 400);
        }

        var ownedByDriver = await _dbContext.Vehicles
            .AsNoTracking()
            .AnyAsync(x => x.Id == vehicleId && x.OwnerId == driverId, cancellationToken);
        if (!ownedByDriver)
        {
            throw new ApiException("You can only publish rides with your own vehicle.", 403);
        }
    }

    private static RideOfferDto MapRide(RideOffer ride) =>
        new(
            ride.Id,
            ride.DriverId,
            ride.VehicleId,
            ride.Driver?.FullName ?? string.Empty,
            new GeoPointDto(ride.OriginName, ride.OriginLatitude, ride.OriginLongitude, ride.OriginAddress),
            new GeoPointDto(ride.DestinationName, ride.DestinationLatitude, ride.DestinationLongitude, ride.DestinationAddress),
            ride.IntermediateStops
                .OrderBy(x => x.StopOrder)
                .Select(x => new RideStopDto(x.Name, x.Address, x.Latitude, x.Longitude, x.StopOrder))
                .ToList(),
            ride.DepartureTimeUtc,
            ride.AvailableSeats,
            ride.Bookings.Count(x => x.Status == BookingStatus.Confirmed),
            ride.PricePerSeat,
            ride.VehicleName,
            ride.VehicleNumber,
            ride.RoutePolyline,
            ride.DistanceKm,
            ride.EtaMinutes,
            ride.Status);

    private async Task<RideChatGroup> EnsureRideChatGroupAsync(Guid rideOfferId, CancellationToken cancellationToken)
    {
        var group = await _chatGroups.Query().FirstOrDefaultAsync(x => x.RideOfferId == rideOfferId, cancellationToken);
        if (group != null) return group;
        group = new RideChatGroup
        {
            Id = Guid.NewGuid(),
            RideOfferId = rideOfferId
        };
        await _chatGroups.AddAsync(group, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return group;
    }

    private async Task EnsureRideAccessAsync(Guid userId, Guid rideOfferId, CancellationToken cancellationToken)
    {
        var ride = await _rides.GetRideByIdAsync(rideOfferId, cancellationToken) ?? throw new ApiException("Ride not found.", 404);
        if (ride.DriverId == userId) return;
        var isParticipant = await _rideBookings.Query().AnyAsync(
            x => x.RideOfferId == rideOfferId && x.PassengerId == userId && x.Status == BookingStatus.Confirmed,
            cancellationToken);
        if (!isParticipant)
        {
            throw new ApiException("Only booked participants can access ride chat.", 403);
        }
    }

    private static RideBookingDto MapBooking(RideBooking booking) =>
        new(
            booking.Id,
            booking.RideOfferId,
            booking.PassengerId,
            booking.Passenger?.FullName ?? string.Empty,
            booking.SeatsBooked,
            booking.Status,
            booking.CreatedAtUtc);

    private static string Truncate(string value, int maxLength)
    {
        var text = value?.Trim() ?? string.Empty;
        if (text.Length <= maxLength) return text;
        return text[..maxLength];
    }
}
