using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Users;
using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Application.Interfaces.Services;

namespace NewCarPool.Infrastructure.Services;

public sealed class UserProfileService : IUserProfileService
{
    private readonly IUserRepository _users;
    private readonly IUnitOfWork _unitOfWork;

    public UserProfileService(IUserRepository users, IUnitOfWork unitOfWork)
    {
        _users = users;
        _unitOfWork = unitOfWork;
    }

    public async Task<UserProfileDto> GetProfileAsync(Guid userId, CancellationToken cancellationToken) =>
        Map(await _users.GetByIdAsync(userId, cancellationToken) ?? throw new ApiException("User not found.", 404));

    public async Task<UserProfileDto> UpdateProfileAsync(Guid userId, UpdateProfileRequest request, CancellationToken cancellationToken)
    {
        var user = await _users.GetByIdAsync(userId, cancellationToken) ?? throw new ApiException("User not found.", 404);
        if (string.IsNullOrWhiteSpace(request.FullName) || string.IsNullOrWhiteSpace(request.PhoneNumber))
        {
            throw new ApiException("Full name and phone number are required.");
        }

        user.FullName = request.FullName.Trim();
        user.PhoneNumber = request.PhoneNumber.Trim();
        user.UpdatedAtUtc = DateTime.UtcNow;
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return Map(user);
    }

    public async Task<UserProfileDto> UpdateProfileImageAsync(Guid userId, string imagePath, CancellationToken cancellationToken)
    {
        var user = await _users.GetByIdAsync(userId, cancellationToken) ?? throw new ApiException("User not found.", 404);
        user.ProfileImagePath = imagePath;
        user.UpdatedAtUtc = DateTime.UtcNow;
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return Map(user);
    }

    private static UserProfileDto Map(NewCarPool.Domain.Entities.User user) =>
        new(user.Id, user.FullName, user.Email, user.PhoneNumber, user.ProfileImagePath, user.Rating, user.IsAdmin, user.IsActive);
}
