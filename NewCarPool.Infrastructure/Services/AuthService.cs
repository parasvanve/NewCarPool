using Microsoft.Extensions.Options;
using Microsoft.EntityFrameworkCore;
using System.Net.Mail;
using System.Security.Cryptography;
using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Auth;
using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Application.Interfaces.Services;
using NewCarPool.Domain.Entities;
using NewCarPool.Infrastructure.Authentication;
using System.Text.RegularExpressions;

namespace NewCarPool.Infrastructure.Services;

public sealed class AuthService : IAuthService
{
    private readonly IUserRepository _users;
    private readonly IRefreshTokenRepository _refreshTokens;
    private readonly ITokenService _tokenService;
    private readonly IEmailService _emailService;
    private readonly IGenericRepository<PasswordResetToken> _passwordResetTokens;
    private readonly IGenericRepository<PendingRegistrationOtp> _pendingRegistrationOtps;
    private readonly IUnitOfWork _unitOfWork;
    private readonly JwtOptions _jwtOptions;

    public AuthService(
        IUserRepository users,
        IRefreshTokenRepository refreshTokens,
        ITokenService tokenService,
        IEmailService emailService,
        IGenericRepository<PasswordResetToken> passwordResetTokens,
        IGenericRepository<PendingRegistrationOtp> pendingRegistrationOtps,
        IUnitOfWork unitOfWork,
        IOptions<JwtOptions> jwtOptions)
    {
        _users = users;
        _refreshTokens = refreshTokens;
        _tokenService = tokenService;
        _emailService = emailService;
        _passwordResetTokens = passwordResetTokens;
        _pendingRegistrationOtps = pendingRegistrationOtps;
        _unitOfWork = unitOfWork;
        _jwtOptions = jwtOptions.Value;
    }

    public async Task<AuthResponse> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken)
    {
        if (!Regex.IsMatch(
      request.Password,
      @"^(?=.*[A-Za-z])(?=.*\d)(?=.*[@#$!%*?&])[A-Za-z\d@$!%*?&]{8,}$"))
        {
            throw new ApiException(
                "Password must contain at least 8 characters, one letter, one number, and one special character.");
        }
        if (!EmailDomainValidator.IsAllowed(request.Email))
        {
            throw new ApiException(
                "Only approved company email addresses are allowed.");
        }
        await Task.CompletedTask;
        throw new ApiException("Please verify OTP before creating an account.");
    }

    public async Task<RegisterOtpResponse> SendRegisterOtpAsync(SendRegisterOtpRequest request, CancellationToken cancellationToken)
    {
        ValidateRegistration(request);
        if (!Regex.IsMatch(request.Password, @"^(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$"))
        {
            throw new ApiException(
         "Password must be at least 8 characters long and contain at least one letter, one number, and one special character.");
        }
        if (request.Password != request.ConfirmPassword)
        {
            throw new ApiException("Password and Confirm Password do not match.");
        }
        if (!EmailDomainValidator.IsAllowed(request.Email))
        {
            throw new ApiException(
                "Only approved company email addresses are allowed.");
        }
      
        var email = request.Email.Trim().ToLowerInvariant();
        var phoneNumber = NormalizePhoneNumber(request.PhoneNumber);
        if (await _users.ExistsByEmailAsync(email, cancellationToken))
        {
            throw new ApiException("Email is already registered.", 409);
        }

        if (await _users.ExistsByPhoneNumberAsync(phoneNumber, cancellationToken))
        {
            throw new ApiException("Phone number is already registered.", 409);
        }

        var now = DateTime.UtcNow;
        var pending = await _pendingRegistrationOtps.Query()
            .FirstOrDefaultAsync(x => x.Email == email, cancellationToken);

        if (pending is not null && pending.UsedAtUtc is null && pending.ResendAvailableAtUtc > now)
        {
            throw new ApiException("Please wait 60 seconds before requesting another OTP.");
        }

        var otp = GenerateOtp();
        var resendAt = now.AddSeconds(60);
        if (pending is null)
        {
            pending = new PendingRegistrationOtp
            {
                Id = Guid.NewGuid(),
                Email = email,
                CreatedAtUtc = now
            };
            await _pendingRegistrationOtps.AddAsync(pending, cancellationToken);
        }

        pending.FullName = request.FullName.Trim();
        pending.PhoneNumber = phoneNumber;
        pending.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password);
        pending.OtpHash = _tokenService.HashToken(otp);
        pending.ExpiresAtUtc = now.AddMinutes(10);
        pending.ResendAvailableAtUtc = resendAt;
        pending.FailedAttempts = 0;
        pending.UsedAtUtc = null;
        pending.UpdatedAtUtc = now;

        await _unitOfWork.SaveChangesAsync(cancellationToken);
        try
        {
            await _emailService.SendAsync(
                email,
                "Your NewCarPool verification code",
                $"Your OTP is {otp}. It is valid for 10 minutes.",
                cancellationToken);
        }
        catch
        {
            _pendingRegistrationOtps.Delete(pending);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            throw;
        }

        return new RegisterOtpResponse("OTP sent to your email.", resendAt);
    }

    public async Task<AuthResponse> VerifyRegisterOtpAsync(VerifyRegisterOtpRequest request, CancellationToken cancellationToken)
    {
        if (!EmailDomainValidator.IsAllowed(request.Email))
        {
            throw new ApiException(
                "Only approved company email addresses are allowed.");
        }
        var email = request.Email.Trim().ToLowerInvariant();
        var otp = request.Otp.Trim();
        if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(otp))
        {
            throw new ApiException("Invalid OTP.");
        }

        var pending = await _pendingRegistrationOtps.Query()
            .FirstOrDefaultAsync(x => x.Email == email, cancellationToken)
            ?? throw new ApiException("Pending registration was not found.", 404);

        if (pending.UsedAtUtc is not null)
        {
            throw new ApiException("OTP was already used.");
        }

        if (pending.ExpiresAtUtc <= DateTime.UtcNow)
        {
            throw new ApiException("OTP expired.");
        }

        if (pending.FailedAttempts >= 5)
        {
            throw new ApiException("Too many attempts.", 429);
        }

        if (!string.Equals(pending.OtpHash, _tokenService.HashToken(otp), StringComparison.Ordinal))
        {
            pending.FailedAttempts++;
            pending.UpdatedAtUtc = DateTime.UtcNow;
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            throw new ApiException(pending.FailedAttempts >= 5 ? "Too many attempts." : "Invalid OTP.", pending.FailedAttempts >= 5 ? 429 : 400);
        }

        if (await _users.ExistsByEmailAsync(email, cancellationToken))
        {
            throw new ApiException("Email is already registered.", 409);
        }

        if (await _users.ExistsByPhoneNumberAsync(pending.PhoneNumber, cancellationToken))
        {
            throw new ApiException("Phone number is already registered.", 409);
        }

        var user = new User
        {
            Id = Guid.NewGuid(),
            FullName = pending.FullName,
            Email = pending.Email,
            PhoneNumber = pending.PhoneNumber,
            PasswordHash = pending.PasswordHash
        };

        pending.UsedAtUtc = DateTime.UtcNow;
        pending.UpdatedAtUtc = DateTime.UtcNow;
        await _users.AddAsync(user, cancellationToken);
        return await IssueTokensAsync(user, cancellationToken);
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken cancellationToken)
    {
        if (!EmailDomainValidator.IsAllowed(request.Email))
        {
            throw new ApiException(
                "Only approved company email addresses are allowed.");
        }
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

    private static void ValidateRegistration(SendRegisterOtpRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.FullName))
        {
            throw new ApiException("Full name is required.");
        }

        if (!IsValidEmail(request.Email))
        {
            throw new ApiException("Enter a valid email address.");
        }

        if (!IsValidIndianPhoneNumber(request.PhoneNumber))
        {
            throw new ApiException("Enter a valid phone number.");
        }

        if (string.IsNullOrWhiteSpace(request.Password) || request.Password.Length < 8)
        {
            throw new ApiException("Password is required.");
        }

        if (string.IsNullOrWhiteSpace(request.ConfirmPassword))
        {
            throw new ApiException("Confirm password is required.");
        }

        if (!string.Equals(request.Password, request.ConfirmPassword, StringComparison.Ordinal))
        {
            throw new ApiException("Passwords do not match.");
        }
    }

    private static string GenerateOtp() => RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");

    private static bool IsValidEmail(string? email)
    {
        if (string.IsNullOrWhiteSpace(email))
        {
            return false;
        }

        try
        {
            var address = new MailAddress(email.Trim());
            return string.Equals(address.Address, email.Trim(), StringComparison.OrdinalIgnoreCase);
        }
        catch
        {
            return false;
        }
    }

    private static bool IsValidIndianPhoneNumber(string? phoneNumber) =>
        !string.IsNullOrWhiteSpace(phoneNumber) &&
        System.Text.RegularExpressions.Regex.IsMatch(NormalizePhoneNumber(phoneNumber), "^[6-9][0-9]{9}$");

    private static string NormalizePhoneNumber(string phoneNumber)
    {
        var trimmed = phoneNumber.Trim().Replace(" ", string.Empty).Replace("-", string.Empty);
        if (trimmed.StartsWith("+91", StringComparison.Ordinal))
        {
            return trimmed[3..];
        }

        if (trimmed.StartsWith("91", StringComparison.Ordinal) && trimmed.Length == 12)
        {
            return trimmed[2..];
        }

        return trimmed;
    }
}
