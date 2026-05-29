using NewCarPool.Application.DTOs.Rides;

namespace NewCarPool.Application.Interfaces.Services;

public interface IBookingService
{
    Task<RideBookingDto> AcceptAsync(Guid driverId, Guid bookingId, CancellationToken cancellationToken);
    Task<RideBookingDto> RejectAsync(Guid driverId, Guid bookingId, CancellationToken cancellationToken);
    Task<RideBookingDto> CancelAsync(Guid passengerId, Guid bookingId, string? reason, CancellationToken cancellationToken);
    Task<IReadOnlyList<RideBookingDto>> HistoryAsync(Guid userId, CancellationToken cancellationToken);
}
