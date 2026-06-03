using NewCarPool.Application.DTOs.Auth;

namespace NewCarPool.Application.Interfaces.Services;

public interface IAuthService
{
    Task<AuthResponse> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken);
    Task<RegisterOtpResponse> SendRegisterOtpAsync(SendRegisterOtpRequest request, CancellationToken cancellationToken);
    Task<AuthResponse> VerifyRegisterOtpAsync(VerifyRegisterOtpRequest request, CancellationToken cancellationToken);
    Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken cancellationToken);
    Task<AuthResponse> RefreshAsync(RefreshTokenRequest request, CancellationToken cancellationToken);
    Task LogoutAsync(Guid userId, RefreshTokenRequest request, CancellationToken cancellationToken);
    Task<string> ForgotPasswordAsync(ForgotPasswordRequest request, CancellationToken cancellationToken);
    Task ResetPasswordAsync(ResetPasswordRequest request, CancellationToken cancellationToken);
}
