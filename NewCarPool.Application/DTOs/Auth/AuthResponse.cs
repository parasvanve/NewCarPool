namespace NewCarPool.Application.DTOs.Auth;

public sealed record AuthResponse(
    Guid UserId,
    string FullName,
    string Email,
    string AccessToken,
    string RefreshToken,
    DateTime AccessTokenExpiresAtUtc);
