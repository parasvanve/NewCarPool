namespace NewCarPool.Application.DTOs.Users;

public sealed record UserProfileDto(
    Guid Id,
    string FullName,
    string Email,
    string PhoneNumber,
    string? ProfileImagePath,
    decimal Rating,
    bool IsAdmin,
    bool IsActive);

public sealed record UpdateProfileRequest(string FullName, string PhoneNumber);
