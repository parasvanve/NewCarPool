namespace NewCarPool.Application.DTOs.Auth;

public sealed record RegisterRequest(
    string FullName,
    string Email,
    string PhoneNumber,
    string Password);
