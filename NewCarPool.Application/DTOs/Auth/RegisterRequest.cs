namespace NewCarPool.Application.DTOs.Auth;

public sealed record RegisterRequest(
    string FullName,
    string Email,
    string PhoneNumber,
    string Password);

public sealed record SendRegisterOtpRequest(
    string FullName,
    string Email,
    string PhoneNumber,
    string Password,
    string ConfirmPassword);

public sealed record VerifyRegisterOtpRequest(string Email, string Otp);

public sealed record RegisterOtpResponse(string Message, DateTime ResendAvailableAtUtc);
