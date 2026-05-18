using Microsoft.Extensions.Options;
using Microsoft.EntityFrameworkCore;
using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Auth;
using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Application.Interfaces.Services;
using NewCarPool.Domain.Entities;
using NewCarPool.Infrastructure.Authentication;

namespace NewCarPool.Infrastructure.Services;

public sealed class AuthService : IAuthService
{
    private readonly IUserRepository _users;
    private readonly IRefreshTokenRepository _refreshTokens;
    private readonly ITokenService _tokenService;
    private readonly IGenericRepository<PasswordResetToken> _passwordResetTokens;
    private readonly IUnitOfWork _unitOfWork;
    private readonly JwtOptions _jwtOptions;

    public AuthService(
        IUserRepository users,
        IRefreshTokenRepository refreshTokens,
        ITokenService tokenService,
        IGenericRepository<PasswordResetToken> passwordResetTokens,
        IUnitOfWork unitOfWork,
        IOptions<JwtOptions> jwtOptions)
    {
        _users = users;
        _refreshTokens = refreshTokens;
        _tokenService = tokenService;
        _passwordResetTokens = passwordResetTokens;
        _unitOfWork = unitOfWork;
        _jwtOptions = jwtOptions.Value;
    }

    public async Task<AuthResponse> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken)
    {
        ValidateRegistration(request);
        var email = request.Email.Trim().ToLowerInvariant();
        if (await _users.ExistsByEmailAsync(email, cancellationToken))
        {
            throw new ApiException("Email is already registered.", 409);
        }

        var user = new User
        {
            Id = Guid.NewGuid(),
            FullName = request.FullName.Trim(),
            Email = email,
            PhoneNumber = request.PhoneNumber.Trim(),
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password)
        };

        await _users.AddAsync(user, cancellationToken);
        return await IssueTokensAsync(user, cancellationToken);
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken cancellationToken)
    {
        var email = request.Email.Trim().ToLowerInvariant();
         var user = await _users.GetByEmailAsync(email, cancellationToken);
        if (user is null || !BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
        {
            throw new ApiException("Invalid email or password.", 401);
        }

        if (!user.IsActive)
        {
            throw new ApiException("User account is inactive.", 403);
        }

        return await IssueTokensAsync(user, cancellationToken);
    }

    public async Task<AuthResponse> RefreshAsync(RefreshTokenRequest request, CancellationToken cancellationToken)
    {
        var tokenHash = _tokenService.HashToken(request.RefreshToken);
        var storedToken = await _refreshTokens.GetByHashAsync(tokenHash, cancellationToken);
        if (storedToken is null || !storedToken.IsActive)
        {
            throw new ApiException("Refresh token is invalid or expired.", 401);
        }

        storedToken.RevokedAtUtc = DateTime.UtcNow;
        return await IssueTokensAsync(storedToken.User, cancellationToken, storedToken);
    }

    public async Task LogoutAsync(Guid userId, RefreshTokenRequest request, CancellationToken cancellationToken)
    {
        var tokenHash = _tokenService.HashToken(request.RefreshToken);
        var storedToken = await _refreshTokens.GetByHashAsync(tokenHash, cancellationToken);
        if (storedToken is not null && storedToken.UserId == userId && storedToken.RevokedAtUtc is null)
        {
            storedToken.RevokedAtUtc = DateTime.UtcNow;
            await _unitOfWork.SaveChangesAsync(cancellationToken);
        }
    }

    public async Task<string> ForgotPasswordAsync(ForgotPasswordRequest request, CancellationToken cancellationToken)
    {
        var user = await _users.GetByEmailAsync(request.Email.Trim().ToLowerInvariant(), cancellationToken)
            ?? throw new ApiException("User not found.", 404);
        var resetToken = _tokenService.CreateRefreshToken();
        await _passwordResetTokens.AddAsync(new PasswordResetToken
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            TokenHash = _tokenService.HashToken(resetToken),
            ExpiresAtUtc = DateTime.UtcNow.AddMinutes(30)
        }, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return resetToken;
    }

    public async Task ResetPasswordAsync(ResetPasswordRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.NewPassword) || request.NewPassword.Length < 8)
        {
            throw new ApiException("Password must be at least 8 characters.");
        }

        var tokenHash = _tokenService.HashToken(request.ResetToken);
        var resetToken = await _passwordResetTokens.Query()
            .FirstOrDefaultAsync(x => x.TokenHash == tokenHash, cancellationToken);
        if (resetToken is null || !resetToken.IsActive)
        {
            throw new ApiException("Reset token is invalid or expired.", 401);
        }

        var user = await _users.GetByIdAsync(resetToken.UserId, cancellationToken)
            ?? throw new ApiException("User not found.", 404);
        if (!string.Equals(user.Email, request.Email.Trim(), StringComparison.OrdinalIgnoreCase))
        {
            throw new ApiException("Reset token does not match this email.", 401);
        }

        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.NewPassword);
        resetToken.UsedAtUtc = DateTime.UtcNow;
        await _unitOfWork.SaveChangesAsync(cancellationToken);
    }

    private async Task<AuthResponse> IssueTokensAsync(
        User user,
        CancellationToken cancellationToken,
        RefreshToken? previousRefreshToken = null)
    {
        var accessTokenExpiresAt = DateTime.UtcNow.AddMinutes(_jwtOptions.AccessTokenMinutes);
        var refreshToken = _tokenService.CreateRefreshToken();
        var refreshTokenHash = _tokenService.HashToken(refreshToken);

        if (previousRefreshToken is not null)
        {
            previousRefreshToken.ReplacedByTokenHash = refreshTokenHash;
        }

        await _refreshTokens.AddAsync(new RefreshToken
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            TokenHash = refreshTokenHash,
            ExpiresAtUtc = DateTime.UtcNow.AddDays(_jwtOptions.RefreshTokenDays)
        }, cancellationToken);

        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return new AuthResponse(
            user.Id,
            user.FullName,
            user.Email,
            _tokenService.CreateAccessToken(user, accessTokenExpiresAt),
            refreshToken,
            accessTokenExpiresAt);
    }

    private static void ValidateRegistration(RegisterRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.FullName))
        {
            throw new ApiException("Full name is required.");
        }

        if (string.IsNullOrWhiteSpace(request.Email) || !request.Email.Contains('@'))
        {
            throw new ApiException("A valid email is required.");
        }

        if (string.IsNullOrWhiteSpace(request.Password) || request.Password.Length < 8)
        {
            throw new ApiException("Password must be at least 8 characters.");
        }
    }
}
