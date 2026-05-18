namespace NewCarPool.Application.DTOs.Auth;

public sealed record ForgotPasswordRequest(string Email);
public sealed record ResetPasswordRequest(string Email, string ResetToken, string NewPassword);
