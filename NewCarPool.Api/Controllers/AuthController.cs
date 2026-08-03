using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using NewCarPool.Api.Extensions;
using NewCarPool.Application.DTOs.Auth;
using NewCarPool.Application.Interfaces.Services;

namespace NewCarPool.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService) => _authService = authService;

    [HttpPost("register")]
    public async Task<ActionResult<AuthResponse>> Register(RegisterRequest request, CancellationToken cancellationToken) =>
        Ok(await _authService.RegisterAsync(request, cancellationToken));

    [HttpPost("send-register-otp")]
    public async Task<ActionResult<RegisterOtpResponse>> SendRegisterOtp(SendRegisterOtpRequest request, CancellationToken cancellationToken) =>
        Ok(await _authService.SendRegisterOtpAsync(request, cancellationToken));

    [HttpPost("verify-register-otp")]
    public async Task<ActionResult<AuthResponse>> VerifyRegisterOtp(VerifyRegisterOtpRequest request, CancellationToken cancellationToken) =>
        Ok(await _authService.VerifyRegisterOtpAsync(request, cancellationToken));

    [HttpPost("login")]
    public async Task<ActionResult<AuthResponse>> Login(LoginRequest request, CancellationToken cancellationToken) =>
        Ok(await _authService.LoginAsync(request, cancellationToken));

    [HttpGet("exists")]
    public async Task<ActionResult<object>> EmailExists([FromQuery] string email, CancellationToken cancellationToken) =>
        Ok(new { exists = await _authService.EmailExistsAsync(email, cancellationToken) });

    [HttpPost("refresh")]
    public async Task<ActionResult<AuthResponse>> Refresh(RefreshTokenRequest request, CancellationToken cancellationToken) =>
        Ok(await _authService.RefreshAsync(request, cancellationToken));

    [Authorize]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout(RefreshTokenRequest request, CancellationToken cancellationToken)
    {
        await _authService.LogoutAsync(User.GetUserId(), request, cancellationToken);
        return NoContent();
    }

    [HttpPost("forgot-password")]
    public async Task<ActionResult<object>> ForgotPassword(ForgotPasswordRequest request, CancellationToken cancellationToken)
    {
        var resetToken = await _authService.ForgotPasswordAsync(request, cancellationToken);
        return Ok(new { resetToken, message = "In production send this token by email or SMS." });
    }

    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword(ResetPasswordRequest request, CancellationToken cancellationToken)
    {
        await _authService.ResetPasswordAsync(request, cancellationToken);
        return NoContent();
    }
}
