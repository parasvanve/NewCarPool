using NewCarPool.Application.DTOs.Users;

namespace NewCarPool.Application.Interfaces.Services;

public interface IUserProfileService
{
    Task<UserProfileDto> GetProfileAsync(Guid userId, CancellationToken cancellationToken);
    Task<UserProfileDto> UpdateProfileAsync(Guid userId, UpdateProfileRequest request, CancellationToken cancellationToken);
    Task<UserProfileDto> UpdateProfileImageAsync(Guid userId, string imagePath, CancellationToken cancellationToken);
}
