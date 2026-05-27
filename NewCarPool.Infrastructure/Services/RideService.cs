using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Rides;
using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Application.Interfaces.Services;
using Microsoft.EntityFrameworkCore;
using System.Data;
using NewCarPool.Domain.Entities;
using NewCarPool.Domain.Enums;
using Microsoft.Extensions.Logging;
using Microsoft.Data.SqlClient;

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
    private readonly ILogger<RideService> _logger;

    public RideService(
        IRideRepository rides,
        IUserRepository users,
        IGenericRepository<RideOffer> rideOffers,
        IGenericRepository<RideBooking> rideBookings,
        IGenericRepository<RideChatGroup> chatGroups,
        IGenericRepository<RideChatMessage> chatMessages,
        Data.NewCarPoolDbContext dbContext,
        ILogger<RideService> logger,
        IUnitOfWork unitOfWork)
    {
        _rides = rides;
        _users = users;
        _rideOffers = rideOffers;
        _rideBookings = rideBookings;
        _chatGroups = chatGroups;
        _chatMessages = chatMessages;
        _dbContext = dbContext;
        _logger = logger;
        _unitOfWork = unitOfWork;
    }

    public async Task<RideOfferDto> OfferRideAsync(Guid driverId, CreateRideOfferRequest request, CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogInformation(
                "Offer ride request received. DriverId={DriverId}, VehicleId={VehicleId}, Seats={Seats}, DepartureUtc={DepartureUtc}, Stops={StopCount}",
                driverId,
                request.VehicleId,
                request.AvailableSeats,
                request.DepartureTimeUtc,
                request.IntermediateStops?.Count ?? 0);

            _ = await _users.GetByIdAsync(driverId, cancellationToken) ?? throw new ApiException("Driver not found.", 404);
            var departureUtc = NormalizeToUtc(request.DepartureTimeUtc);
            _logger.LogInformation(
                "Offer ride departure normalization. Input={InputDeparture}, NormalizedUtc={NormalizedDepartureUtc}",
                request.DepartureTimeUtc,
                departureUtc);
            ValidateRideOffer(departureUtc);
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
                DepartureTimeUtc = departureUtc,
                AvailableSeats = request.AvailableSeats,
                PricePerSeat = request.PricePerSeat,
                Notes = Truncate(request.Notes, 1000),
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
        catch (ApiException)
        {
            throw;
        }
        catch (Exception exception)
        {
            _logger.LogError(
                exception,
                "Offer ride failed. DriverId={DriverId}, VehicleId={VehicleId}, Pickup=({PickupLat},{PickupLng}), Destination=({DestLat},{DestLng}), Stops={StopCount}",
                driverId,
                request.VehicleId,
                request.Origin?.Latitude,
                request.Origin?.Longitude,
                request.Destination?.Latitude,
                request.Destination?.Longitude,
                request.IntermediateStops?.Count ?? 0);
            throw;
        }
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

    public async Task<IReadOnlyList<RideOfferDto>> UpcomingActiveRidesAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var rides = await _rideOffers.Query()
            .AsNoTracking()
            .Include(x => x.Driver)
            .Include(x => x.Bookings)
            .Include(x => x.IntermediateStops)
            .Where(x => (x.Status == RideStatus.Open || x.Status == RideStatus.Full) && x.DepartureTimeUtc > now)
            .OrderBy(x => x.DepartureTimeUtc)
            .Take(200)
            .ToListAsync(cancellationToken);
        return rides.Select(MapRide).ToList();
    }

    public async Task<RideOfferDto> DetailsAsync(Guid rideOfferId, CancellationToken cancellationToken) =>
        MapRide(await _rides.GetRideByIdAsync(rideOfferId, cancellationToken) ?? throw new ApiException("Ride not found.", 404));

    public async Task<RideOfferDto> UpdateRideAsync(Guid driverId, Guid rideOfferId, CreateRideOfferRequest request, CancellationToken cancellationToken)
    {
        var departureUtc = NormalizeToUtc(request.DepartureTimeUtc);
        _logger.LogInformation(
            "Update ride departure normalization. Input={InputDeparture}, NormalizedUtc={NormalizedDepartureUtc}",
            request.DepartureTimeUtc,
            departureUtc);
        ValidateRideOffer(departureUtc);
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
        ride.DepartureTimeUtc = departureUtc;
        ride.AvailableSeats = request.AvailableSeats;
        ride.PricePerSeat = request.PricePerSeat;
        ride.Notes = Truncate(request.Notes, 1000);
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
        var rideId = request.EffectiveRideId;
        try
        {
            if (rideId == Guid.Empty)
            {
                throw new ApiException("Ride id is required.");
            }

            _logger.LogInformation(
                "Book ride request received. PassengerId={PassengerId}, RideId={RideId}, SeatsBooked={SeatsBooked}",
                passengerId,
                rideId,
                request.SeatsBooked);

            await using var transaction = await _dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);
            var passenger = await _users.GetByIdAsync(passengerId, cancellationToken)
                ?? throw new ApiException("Passenger not found.", 404);
            var ride = await _rides.GetRideByIdAsync(rideId, cancellationToken)
                ?? throw new ApiException("Ride not found.", 404);

            _logger.LogInformation(
                "Book ride loaded ride. RideId={RideId}, RideDriverId={RideDriverId}, AvailableSeats={AvailableSeats}, RideStatus={RideStatus}",
                ride.Id,
                ride.DriverId,
                ride.AvailableSeats,
                ride.Status);

            var existingBooking = await _rideBookings.Query()
                .FirstOrDefaultAsync(
                    x => x.RideOfferId == rideId
                         && x.PassengerId == passengerId,
                    cancellationToken);

            _logger.LogInformation(
                "Book ride existing booking. PassengerId={PassengerId}, RideId={RideId}, Exists={Exists}, ExistingStatus={ExistingStatus}",
                passengerId,
                rideId,
                existingBooking != null,
                existingBooking?.Status);

            if (existingBooking is { Status: BookingStatus.Confirmed })
            {
                throw new ApiException("You have already booked this ride.");
            }

            if (ride.DriverId == passengerId)
            {
                throw new ApiException("You cannot book your own ride.");
            }

            if (ride.AvailableSeats <= 0 || ride.Status == RideStatus.Full)
            {
                throw new ApiException("Ride is full.");
            }

            if (ride.Status != RideStatus.Open)
            {
                throw new ApiException("Ride is not open for booking.");
            }

            if (request.SeatsBooked <= 0 || request.SeatsBooked > ride.AvailableSeats)
            {
                throw new ApiException("Requested seats are not available.");
            }

            ValidateBookingPoint(request.Pickup, "Pickup");
            ValidateBookingPoint(request.Drop, "Drop");

            ride.AvailableSeats -= request.SeatsBooked;
            ride.Status = ride.AvailableSeats == 0 ? RideStatus.Full : RideStatus.Open;
            ride.UpdatedAtUtc = DateTime.UtcNow;

            RideBooking booking;
            if (existingBooking == null)
            {
                booking = new RideBooking
                {
                    Id = Guid.NewGuid(),
                    PassengerId = passengerId,
                    RideOfferId = ride.Id,
                    SeatsBooked = request.SeatsBooked,
                    PassengerPickupName = Truncate(request.Pickup.Name, 300),
                    PassengerPickupAddress = Truncate(request.Pickup.Address ?? request.Pickup.Name, 500),
                    PassengerPickupLatitude = request.Pickup.Latitude,
                    PassengerPickupLongitude = request.Pickup.Longitude,
                    PassengerDropName = Truncate(request.Drop.Name, 300),
                    PassengerDropAddress = Truncate(request.Drop.Address ?? request.Drop.Name, 500),
                    PassengerDropLatitude = request.Drop.Latitude,
                    PassengerDropLongitude = request.Drop.Longitude,
                    Status = BookingStatus.Confirmed
                };
                await _rides.AddBookingAsync(booking, cancellationToken);
            }
            else
            {
                booking = existingBooking;
                booking.SeatsBooked = request.SeatsBooked;
                booking.PassengerPickupName = Truncate(request.Pickup.Name, 300);
                booking.PassengerPickupAddress = Truncate(request.Pickup.Address ?? request.Pickup.Name, 500);
                booking.PassengerPickupLatitude = request.Pickup.Latitude;
                booking.PassengerPickupLongitude = request.Pickup.Longitude;
                booking.PassengerDropName = Truncate(request.Drop.Name, 300);
                booking.PassengerDropAddress = Truncate(request.Drop.Address ?? request.Drop.Name, 500);
                booking.PassengerDropLatitude = request.Drop.Latitude;
                booking.PassengerDropLongitude = request.Drop.Longitude;
                booking.Status = BookingStatus.Confirmed;
                booking.CancelledAtUtc = null;
            }

            var notificationMessage =
                $"{passenger.FullName} booked your ride from {ShortLocationName(ride.OriginName)} to {ShortLocationName(ride.DestinationName)}. " +
                $"Pickup: {ShortLocationName(booking.PassengerPickupName)}. Drop: {ShortLocationName(booking.PassengerDropName)}. Seats: {booking.SeatsBooked}.";
            _dbContext.Notifications.Add(new Notification
            {
                Id = Guid.NewGuid(),
                UserId = ride.DriverId,
                Title = "New ride booking",
                Message = Truncate(notificationMessage, 1000),
                Type = NotificationType.RideBooked,
                RideId = ride.Id,
                BookingId = booking.Id,
                CreatedAtUtc = DateTime.UtcNow
            });
            _dbContext.Notifications.Add(new Notification
            {
                Id = Guid.NewGuid(),
                UserId = passengerId,
                Title = "Ride booked successfully",
                Message = Truncate(
                    $"Your ride with {ride.Driver?.FullName ?? "Driver"} is confirmed. " +
                    $"Pickup: {ShortLocationName(booking.PassengerPickupName)}. " +
                    $"Drop: {ShortLocationName(booking.PassengerDropName)}. Seats: {booking.SeatsBooked}.",
                    1000),
                Type = NotificationType.BookingConfirmed,
                RideId = ride.Id,
                BookingId = booking.Id,
                CreatedAtUtc = DateTime.UtcNow
            });

            await _unitOfWork.SaveChangesAsync(cancellationToken);
            await EnsureRideChatGroupAsync(ride.Id, cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            booking.Passenger = passenger;
            return MapBooking(booking);
        }
        catch (ApiException)
        {
            throw;
        }
        catch (DbUpdateException exception) when (exception.InnerException is SqlException sql && (sql.Number == 2627 || sql.Number == 2601))
        {
            _logger.LogWarning(exception, "Duplicate booking detected for passenger {PassengerId} and ride {RideId}", passengerId, request.EffectiveRideId);
            throw new ApiException("You have already booked this ride.");
        }
        catch (Exception exception)
        {
            _logger.LogError(
                exception,
                "Book ride failed. PassengerId={PassengerId}, RideId={RideId}, Seats={SeatsBooked}, InnerException={InnerException}",
                passengerId,
                rideId,
                request.SeatsBooked,
                exception.InnerException?.Message);
            throw new ApiException(exception.InnerException?.Message ?? exception.Message, 500);
        }
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

        var participantIds = await _rideBookings.Query()
            .Where(x => x.RideOfferId == rideOfferId && x.Status == BookingStatus.Confirmed)
            .Select(x => x.PassengerId)
            .Distinct()
            .ToListAsync(cancellationToken);
        var driverId = await _rideOffers.Query()
            .Where(x => x.Id == rideOfferId)
            .Select(x => x.DriverId)
            .FirstOrDefaultAsync(cancellationToken);
        if (driverId != Guid.Empty) participantIds.Add(driverId);
        var recipients = participantIds
            .Where(x => x != userId)
            .Distinct()
            .ToList();
        foreach (var recipientId in recipients)
        {
            _dbContext.Notifications.Add(new Notification
            {
                Id = Guid.NewGuid(),
                UserId = recipientId,
                Title = $"New message from {sender.FullName}",
                Message = Truncate(request.Message.Trim(), 300),
                Type = NotificationType.NewMessage,
                RideId = rideOfferId,
                CreatedAtUtc = DateTime.UtcNow
            });
        }
        if (recipients.Count > 0)
        {
            await _unitOfWork.SaveChangesAsync(cancellationToken);
        }
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

    private static void ValidateRideOffer(DateTime departureTimeUtc)
    {
        if (departureTimeUtc <= DateTime.UtcNow)
        {
            throw new ApiException("Departure time must be in the future.");
        }
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

        ValidateRideOffer(NormalizeToUtc(request.DepartureTimeUtc));
    }

    private static void ValidateBookingPoint(GeoPointDto point, string label)
    {
        if (point is null || string.IsNullOrWhiteSpace(point.Name))
        {
            throw new ApiException($"{label} point is required.");
        }

        if (point.Latitude is < -90 or > 90 || point.Longitude is < -180 or > 180)
        {
            throw new ApiException($"{label} coordinates are invalid.");
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
            NormalizeToUtc(ride.DepartureTimeUtc),
            ride.AvailableSeats,
            ride.Bookings.Count(x => x.Status == BookingStatus.Confirmed),
            ride.PricePerSeat,
            ride.Notes,
            ride.VehicleName,
            ride.VehicleNumber,
            ride.RoutePolyline,
            ride.DistanceKm,
            ride.EtaMinutes,
            ride.Status);

    private static DateTime NormalizeToUtc(DateTime value) =>
        value.Kind switch
        {
            DateTimeKind.Utc => value,
            DateTimeKind.Local => value.ToUniversalTime(),
            DateTimeKind.Unspecified => DateTime.SpecifyKind(value, DateTimeKind.Utc),
            _ => value.ToUniversalTime()
        };

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
        var rideOwner = await _rideOffers.Query()
            .AsNoTracking()
            .Where(x => x.Id == rideOfferId)
            .Select(x => new { x.Id, x.DriverId })
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw new ApiException("Ride not found.", 404);

        if (rideOwner.DriverId == userId)
        {
            return;
        }

        // Backward compatibility: allow chat for booked passengers across legacy booking states.
        var isParticipant = await _rideBookings.Query().AnyAsync(
            x => x.RideOfferId == rideOfferId
                 && x.PassengerId == userId
                 && (x.Status == BookingStatus.Confirmed || x.Status == BookingStatus.Pending),
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
            new GeoPointDto(
                booking.PassengerPickupName,
                booking.PassengerPickupLatitude,
                booking.PassengerPickupLongitude,
                booking.PassengerPickupAddress),
            new GeoPointDto(
                booking.PassengerDropName,
                booking.PassengerDropLatitude,
                booking.PassengerDropLongitude,
                booking.PassengerDropAddress),
            booking.Status,
            booking.CreatedAtUtc);

    private static string Truncate(string? value, int maxLength)
    {
        var text = value?.Trim() ?? string.Empty;
        if (text.Length <= maxLength) return text;
        return text[..maxLength];
    }

    private static string ShortLocationName(string? value)
    {
        var text = value?.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(text)) return "Location";
        var comma = text.IndexOf(',');
        return comma > 0 ? text[..comma].Trim() : text;
    }
}
