using Microsoft.EntityFrameworkCore;
using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Rides;
using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Domain.Entities;
using NewCarPool.Domain.Enums;
using NewCarPool.Infrastructure.Data;

namespace NewCarPool.Infrastructure.Repositories;

public sealed class RideRepository : IRideRepository
{
    private readonly NewCarPoolDbContext _dbContext;

    public RideRepository(NewCarPoolDbContext dbContext) => _dbContext = dbContext;

    public async Task AddRideAsync(RideOffer ride, CancellationToken cancellationToken) =>
        await _dbContext.RideOffers.AddAsync(ride, cancellationToken);

    public Task<RideOffer?> GetRideByIdAsync(Guid id, CancellationToken cancellationToken) =>
        _dbContext.RideOffers
            .Include(x => x.Driver)
            .Include(x => x.Bookings)
            .ThenInclude(x => x.Passenger)
            .FirstOrDefaultAsync(x => x.Id == id, cancellationToken);

    public async Task<PagedResult<RideOffer>> SearchAsync(SearchRideRequest request, CancellationToken cancellationToken)
    {
        var page = Math.Max(request.Page, 1);
        var pageSize = Math.Clamp(request.PageSize, 1, 50);
        var originWindow = 0.25d;
        var destinationWindow = 0.25d;

        var query = _dbContext.RideOffers
            .AsNoTracking()
            .Include(x => x.Driver)
            .Where(x => x.Status == RideStatus.Open && x.AvailableSeats >= request.Seats)
            .Where(x => Math.Abs(x.OriginLatitude - request.OriginLatitude) <= originWindow)
            .Where(x => Math.Abs(x.OriginLongitude - request.OriginLongitude) <= originWindow)
            .Where(x => Math.Abs(x.DestinationLatitude - request.DestinationLatitude) <= destinationWindow)
            .Where(x => Math.Abs(x.DestinationLongitude - request.DestinationLongitude) <= destinationWindow);

        if (request.DepartureDateUtc.HasValue)
        {
            var start = request.DepartureDateUtc.Value.Date;
            var end = start.AddDays(1);
            query = query.Where(x => x.DepartureTimeUtc >= start && x.DepartureTimeUtc < end);
        }

        var total = await query.CountAsync(cancellationToken);
        var items = await query
            .OrderBy(x => x.DepartureTimeUtc)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        return new PagedResult<RideOffer>(items, page, pageSize, total);
    }

    public async Task AddBookingAsync(RideBooking booking, CancellationToken cancellationToken) =>
        await _dbContext.RideBookings.AddAsync(booking, cancellationToken);

    public Task<RideBooking?> GetBookingAsync(Guid id, CancellationToken cancellationToken) =>
        _dbContext.RideBookings
            .Include(x => x.RideOffer)
            .Include(x => x.Passenger)
            .FirstOrDefaultAsync(x => x.Id == id, cancellationToken);

    public async Task AddLocationUpdateAsync(RideLocationUpdate locationUpdate, CancellationToken cancellationToken) =>
        await _dbContext.RideLocationUpdates.AddAsync(locationUpdate, cancellationToken);
}
