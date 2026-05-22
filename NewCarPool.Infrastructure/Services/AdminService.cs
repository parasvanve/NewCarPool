using Microsoft.EntityFrameworkCore;
using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Admin;
using NewCarPool.Application.DTOs.Rides;
using NewCarPool.Application.DTOs.Users;
using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Application.Interfaces.Services;
using NewCarPool.Domain.Entities;
using NewCarPool.Domain.Enums;

namespace NewCarPool.Infrastructure.Services;

public sealed class AdminService : IAdminService
{
    private readonly IGenericRepository<User> _users;
    private readonly IGenericRepository<Vehicle> _vehicles;
    private readonly IGenericRepository<RideOffer> _rides;
    private readonly IGenericRepository<RideBooking> _bookings;
    private readonly IGenericRepository<Payment> _payments;
    private readonly IUnitOfWork _unitOfWork;

    public AdminService(
        IGenericRepository<User> users,
        IGenericRepository<Vehicle> vehicles,
        IGenericRepository<RideOffer> rides,
        IGenericRepository<RideBooking> bookings,
        IGenericRepository<Payment> payments,
        IUnitOfWork unitOfWork)
    {
        _users = users;
        _vehicles = vehicles;
        _rides = rides;
        _bookings = bookings;
        _payments = payments;
        _unitOfWork = unitOfWork;
    }

    public async Task<IReadOnlyList<UserProfileDto>> GetUsersAsync(CancellationToken cancellationToken) =>
        await _users.Query().OrderByDescending(x => x.CreatedAtUtc).Select(x => new UserProfileDto(x.Id, x.FullName, x.Email, x.PhoneNumber, x.ProfileImagePath, x.Rating, x.IsAdmin, x.IsActive)).ToListAsync(cancellationToken);

    public async Task BlockUserAsync(Guid userId, CancellationToken cancellationToken)
    {
        var user = await _users.GetByIdAsync(userId, cancellationToken) ?? throw new ApiException("User not found.", 404);
        user.IsActive = false;
        await _unitOfWork.SaveChangesAsync(cancellationToken);
    }

    public async Task VerifyVehicleAsync(Guid vehicleId, CancellationToken cancellationToken)
    {
        var vehicle = await _vehicles.GetByIdAsync(vehicleId, cancellationToken) ?? throw new ApiException("Vehicle not found.", 404);
        vehicle.IsVerified = true;
        await _unitOfWork.SaveChangesAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<RideOfferDto>> GetRidesAsync(CancellationToken cancellationToken) =>
        await _rides.Query().Include(x => x.Driver).Include(x => x.IntermediateStops).OrderByDescending(x => x.CreatedAtUtc).Select(x => new RideOfferDto(
            x.Id, x.DriverId, x.VehicleId, x.Driver.FullName,
            new GeoPointDto(x.OriginName, x.OriginLatitude, x.OriginLongitude, x.OriginAddress),
            new GeoPointDto(x.DestinationName, x.DestinationLatitude, x.DestinationLongitude, x.DestinationAddress),
            x.IntermediateStops.OrderBy(s => s.StopOrder)
                .Select(s => new RideStopDto(s.Name, s.Address, s.Latitude, s.Longitude, s.StopOrder))
                .ToList(),
            x.DepartureTimeUtc, x.AvailableSeats, x.Bookings.Count(b => b.Status == BookingStatus.Confirmed), x.PricePerSeat, x.Notes, x.VehicleName, x.VehicleNumber, x.RoutePolyline, x.DistanceKm, x.EtaMinutes, x.Status)).ToListAsync(cancellationToken);

    public async Task<DashboardStatsDto> GetStatsAsync(CancellationToken cancellationToken) =>
        new(
            await _users.Query().CountAsync(cancellationToken),
            await _users.Query().CountAsync(x => x.IsActive, cancellationToken),
            await _vehicles.Query().CountAsync(cancellationToken),
            await _vehicles.Query().CountAsync(x => x.IsVerified, cancellationToken),
            await _rides.Query().CountAsync(cancellationToken),
            await _rides.Query().CountAsync(x => x.Status == RideStatus.Completed, cancellationToken),
            await _bookings.Query().CountAsync(cancellationToken),
            await _payments.Query().Where(x => x.PaymentStatus == PaymentStatus.Verified).SumAsync(x => x.Amount, cancellationToken));
}
