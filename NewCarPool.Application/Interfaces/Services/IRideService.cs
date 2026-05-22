using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Rides;

namespace NewCarPool.Application.Interfaces.Services;

public interface IRideService
{
    Task<RideOfferDto> OfferRideAsync(Guid driverId, CreateRideOfferRequest request, CancellationToken cancellationToken);
    Task<RideOfferDto> DetailsAsync(Guid rideOfferId, CancellationToken cancellationToken);
    Task<PagedResult<RideOfferDto>> SearchAsync(SearchRideRequest request, CancellationToken cancellationToken);
    Task<IReadOnlyList<RideOfferDto>> UpcomingActiveRidesAsync(CancellationToken cancellationToken);
    Task<RideOfferDto> UpdateRideAsync(Guid driverId, Guid rideOfferId, CreateRideOfferRequest request, CancellationToken cancellationToken);
    Task DeleteRideAsync(Guid driverId, Guid rideOfferId, CancellationToken cancellationToken);
    Task<RideOfferDto> CancelRideAsync(Guid driverId, Guid rideOfferId, CancellationToken cancellationToken);
    Task<RideBookingDto> BookRideAsync(Guid passengerId, BookRideRequest request, CancellationToken cancellationToken);
    Task<IReadOnlyList<RideBookingDto>> ParticipantsAsync(Guid rideOfferId, CancellationToken cancellationToken);
    Task<IReadOnlyList<RideChatMessageDto>> RideChatAsync(Guid userId, Guid rideOfferId, CancellationToken cancellationToken);
    Task<RideChatMessageDto> SendRideChatMessageAsync(Guid userId, Guid rideOfferId, SendRideChatMessageRequest request, CancellationToken cancellationToken);
    Task<RideOfferDto> StartRideAsync(Guid driverId, Guid rideOfferId, CancellationToken cancellationToken);
    Task<RideOfferDto> CompleteRideAsync(Guid driverId, Guid rideOfferId, CancellationToken cancellationToken);
}
