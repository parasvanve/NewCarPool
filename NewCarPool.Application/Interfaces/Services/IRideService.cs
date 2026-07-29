using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Rides;


namespace NewCarPool.Application.Interfaces.Services;

public interface IRideService
{
    Task<RideOfferDto> OfferRideAsync(Guid driverId, CreateRideOfferRequest request, CancellationToken cancellationToken);
    Task<RideOfferDto> DetailsAsync(Guid rideOfferId, CancellationToken cancellationToken);
    Task<PagedResult<RideOfferDto>> SearchAsync(SearchRideRequest request, CancellationToken cancellationToken);
    Task<IReadOnlyList<RideOfferDto>> UpcomingActiveRidesAsync(CancellationToken cancellationToken);
    Task<IReadOnlyList<RideOfferDto>> MineAsync(Guid userId, CancellationToken cancellationToken);
    Task<RideOfferDto> UpdateRideAsync(Guid driverId, Guid rideOfferId, CreateRideOfferRequest request, CancellationToken cancellationToken);
    Task DeleteRideAsync(Guid driverId, Guid rideOfferId, CancellationToken cancellationToken);
    Task<RideOfferDto> CancelRideAsync(Guid driverId, Guid rideOfferId, string? reason, CancellationToken cancellationToken);
    Task<RideBookingDto> BookRideAsync(Guid passengerId, BookRideRequest request, CancellationToken cancellationToken);
    Task<IReadOnlyList<RideBookingDto>> ParticipantsAsync(Guid rideOfferId, CancellationToken cancellationToken);
    Task<IReadOnlyList<RideChatMessageDto>> RideChatAsync(Guid userId, Guid rideOfferId, CancellationToken cancellationToken);
    Task<RideChatMessageDto> SendRideChatMessageAsync(Guid userId, Guid rideOfferId, SendRideChatMessageRequest request, CancellationToken cancellationToken);
    Task<RideChatMessageDto> UploadChatAttachmentAsync(Guid rideOfferId, Guid userId, ChatAttachmentUpload upload, CancellationToken cancellationToken);
    Task<RideOfferDto> StartRideAsync(Guid driverId, Guid rideOfferId, CancellationToken cancellationToken);
    Task<RideOfferDto> CompleteRideAsync(Guid driverId, Guid rideOfferId, CancellationToken cancellationToken);

    //Task<SharedRideDto?> GetSharedRideAsync(Guid rideId);

    Task<SharedRideDto> GetSharedRideAsync(
     Guid rideId,
     CancellationToken cancellationToken);


    Task<RideShareResponseDto> GetRideShareDataAsync(
    Guid rideId,
    CancellationToken cancellationToken);
}
