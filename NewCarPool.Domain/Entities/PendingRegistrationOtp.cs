namespace NewCarPool.Domain.Entities;

public sealed class PendingRegistrationOtp
{
    public Guid Id { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string OtpHash { get; set; } = string.Empty;
    public DateTime ExpiresAtUtc { get; set; }
    public DateTime ResendAvailableAtUtc { get; set; }
    public int FailedAttempts { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime? UsedAtUtc { get; set; }

    public bool IsActive => UsedAtUtc is null && ExpiresAtUtc > DateTime.UtcNow;
}
