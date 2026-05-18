using Microsoft.EntityFrameworkCore;
using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Rides;
using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Application.Interfaces.Services;
using NewCarPool.Domain.Entities;
using NewCarPool.Domain.Enums;
using NewCarPool.Infrastructure.Data;

namespace NewCarPool.Infrastructure.Services;

public sealed class BookingService : IBookingService
{
    private readonly NewCarPoolDbContext _dbContext;
    private readonly IGenericRepository<RideBooking> _bookings;

    public BookingService(NewCarPoolDbContext dbContext, IGenericRepository<RideBooking> bookings)
    {
        _dbContext = dbContext;
        _bookings = bookings;
    }

    public Task<RideBookingDto> AcceptAsync(Guid driverId, Guid bookingId, CancellationToken cancellationToken) =>
        ChangeByDriverAsync(driverId, bookingId, BookingStatus.Confirmed, cancellationToken);

    public Task<RideBookingDto> RejectAsync(Guid driverId, Guid bookingId, CancellationToken cancellationToken) =>
        ChangeByDriverAsync(driverId, bookingId, BookingStatus.Rejected, cancellationToken, restoreSeats: true);

    public async Task<RideBookingDto> CancelAsync(Guid passengerId, Guid bookingId, CancellationToken cancellationToken)
    {
        await using var transaction = await _dbContext.Database.BeginTransactionAsync(cancellationToken);
        var booking = await Query().FirstOrDefaultAsync(x => x.Id == bookingId, cancellationToken) ?? throw new ApiException("Booking not found.", 404);
        if (booking.PassengerId != passengerId)
        {
            throw new ApiException("You cannot cancel this booking.", 403);
        }

        if (booking.Status == BookingStatus.Cancelled)
        {
            return Map(booking);
        }

        booking.Status = BookingStatus.Cancelled;
        booking.CancelledAtUtc = DateTime.UtcNow;
        booking.RideOffer.AvailableSeats += booking.SeatsBooked;
        if (booking.RideOffer.Status == RideStatus.Full)
        {
            booking.RideOffer.Status = RideStatus.Open;
        }

        await _dbContext.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return Map(booking);
    }

    public async Task<IReadOnlyList<RideBookingDto>> HistoryAsync(Guid userId, CancellationToken cancellationToken) =>
        await Query().Where(x => x.PassengerId == userId || x.RideOffer.DriverId == userId)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Select(x => Map(x))
            .ToListAsync(cancellationToken);

    private async Task<RideBookingDto> ChangeByDriverAsync(Guid driverId, Guid bookingId, BookingStatus status, CancellationToken cancellationToken, bool restoreSeats = false)
    {
        await using var transaction = await _dbContext.Database.BeginTransactionAsync(cancellationToken);
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
        return Map(booking);
    }

    private IQueryable<RideBooking> Query() =>
        _bookings.Query().Include(x => x.Passenger).Include(x => x.RideOffer);

    private static RideBookingDto Map(RideBooking booking) =>
        new(booking.Id, booking.RideOfferId, booking.PassengerId, booking.Passenger?.FullName ?? string.Empty, booking.SeatsBooked, booking.Status, booking.CreatedAtUtc);
}
