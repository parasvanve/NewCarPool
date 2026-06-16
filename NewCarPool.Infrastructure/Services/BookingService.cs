using Microsoft.EntityFrameworkCore;
using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Rides;
using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Application.Interfaces.Services;
using NewCarPool.Domain.Entities;
using NewCarPool.Domain.Enums;
using NewCarPool.Infrastructure.Data;
using Microsoft.AspNetCore.SignalR;
using NewCarPool.Infrastructure.Hubs;

namespace NewCarPool.Infrastructure.Services;

public sealed class BookingService : IBookingService
{
    private readonly NewCarPoolDbContext _dbContext;
    private readonly IGenericRepository<RideBooking> _bookings;
    private readonly INotificationService _notificationService;
    private readonly IHubContext<AppRealtimeHub> _hubContext;

    public BookingService(
        NewCarPoolDbContext dbContext,
        IGenericRepository<RideBooking> bookings,
        INotificationService notificationService,
        IHubContext<AppRealtimeHub> hubContext)
    {
        _dbContext = dbContext;
        _bookings = bookings;
        _notificationService = notificationService;
        _hubContext = hubContext;
    }

    public Task<RideBookingDto> AcceptAsync(Guid driverId, Guid bookingId, CancellationToken cancellationToken) =>
        ChangeByDriverAsync(driverId, bookingId, BookingStatus.Confirmed, cancellationToken);

    public Task<RideBookingDto> RejectAsync(Guid driverId, Guid bookingId, CancellationToken cancellationToken) =>
        ChangeByDriverAsync(driverId, bookingId, BookingStatus.Rejected, cancellationToken, restoreSeats: true);

    public async Task<RideBookingDto> CancelAsync(Guid passengerId, Guid bookingId, string? reason, CancellationToken cancellationToken)
    {
        var strategy = _dbContext.Database.CreateExecutionStrategy();
        return await strategy.ExecuteAsync(async () =>
        {
            await using var transaction = await _dbContext.Database.BeginTransactionAsync(cancellationToken);
            try
            {
                var booking = await Query().FirstOrDefaultAsync(x => x.Id == bookingId, cancellationToken) ?? throw new ApiException("Booking not found.", 404);
                if (booking.PassengerId != passengerId)
                {
                    throw new ApiException("You cannot cancel this booking.", 403);
                }

                if (booking.Status == BookingStatus.Cancelled)
                {
                    throw new ApiException("Booking already cancelled.");
                }

                if (booking.RideOffer.Status == RideStatus.Completed)
                {
                    throw new ApiException("Ride already completed.");
                }

                booking.Status = BookingStatus.Cancelled;
                booking.CancelledAtUtc = DateTime.UtcNow;
                booking.RideOffer.AvailableSeats += booking.SeatsBooked;
                if (booking.RideOffer.Status == RideStatus.Full)
                {
                    booking.RideOffer.Status = RideStatus.Open;
                }

                await _dbContext.SaveChangesAsync(cancellationToken);
                await _notificationService.CreateAsync(
                    booking.RideOffer.DriverId,
                    new Application.DTOs.Notifications.CreateNotificationRequest(
                        "Booking cancelled",
                        $"{booking.Passenger?.FullName ?? "Passenger"} cancelled booking for your ride.",
                        NotificationType.RideCancelled,
                        booking.RideOfferId,
                        booking.Id),
                    cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                var dto = Map(booking);
                await SendBookingEventAsync("BookingCancelled", booking.RideOffer.DriverId, booking.PassengerId, dto, cancellationToken);
                return dto;
            }
            catch
            {
                await transaction.RollbackAsync(cancellationToken);
                throw;
            }
        });
    }

    public async Task<IReadOnlyList<RideBookingDto>> HistoryAsync(Guid userId, CancellationToken cancellationToken) =>
        await _bookings.Query()
            .AsNoTracking()
            .Where(x => x.PassengerId == userId || x.RideOffer.DriverId == userId)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Select(x => new RideBookingDto(
                x.Id,
                x.RideOfferId,
                x.PassengerId,
                x.Passenger.FullName,
                x.SeatsBooked,
                new GeoPointDto(
                    x.PassengerPickupName,
                    x.PassengerPickupLatitude,
                    x.PassengerPickupLongitude,
                    x.PassengerPickupAddress),
                new GeoPointDto(
                    x.PassengerDropName,
                    x.PassengerDropLatitude,
                    x.PassengerDropLongitude,
                    x.PassengerDropAddress),
                x.Status,
                x.CreatedAtUtc))
            .ToListAsync(cancellationToken);

    private async Task<RideBookingDto> ChangeByDriverAsync(Guid driverId, Guid bookingId, BookingStatus status, CancellationToken cancellationToken, bool restoreSeats = false)
    {
        var strategy = _dbContext.Database.CreateExecutionStrategy();
        return await strategy.ExecuteAsync(async () =>
        {
            await using var transaction = await _dbContext.Database.BeginTransactionAsync(cancellationToken);
            try
            {
                var booking = await Query().FirstOrDefaultAsync(x => x.Id == bookingId, cancellationToken) ?? throw new ApiException("Booking not found.", 404);
                if (booking.RideOffer.DriverId != driverId)
                {
                    throw new ApiException("Only the driver can update this booking.", 403);
                }

                if (restoreSeats && booking.Status != BookingStatus.Rejected)
                {
                    booking.RideOffer.AvailableSeats += booking.SeatsBooked;
                    if (booking.RideOffer.Status == RideStatus.Full)
                    {
                        booking.RideOffer.Status = RideStatus.Open;
                    }
                }

                booking.Status = status;
                await _dbContext.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                var dto = Map(booking);
                await SendBookingEventAsync(
                    status == BookingStatus.Confirmed ? "BookingCreated" : "BookingCancelled",
                    booking.RideOffer.DriverId,
                    booking.PassengerId,
                    dto,
                    cancellationToken);
                return dto;
            }
            catch
            {
                await transaction.RollbackAsync(cancellationToken);
                throw;
            }
        });
    }

    private IQueryable<RideBooking> Query() =>
        _bookings.Query().Include(x => x.Passenger).Include(x => x.RideOffer);

    private Task SendBookingEventAsync(
        string eventName,
        Guid driverId,
        Guid passengerId,
        RideBookingDto booking,
        CancellationToken cancellationToken)
    {
        var payload = new { booking };
        var tasks = new[] { driverId, passengerId }
            .Distinct()
            .Select(userId => _hubContext.Clients
                .Group(AppRealtimeHub.UserGroupName(userId.ToString()))
                .SendAsync(eventName, payload, cancellationToken));
        return Task.WhenAll(tasks);
    }

    private static RideBookingDto Map(RideBooking booking) =>
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
}
