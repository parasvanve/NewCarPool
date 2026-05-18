namespace NewCarPool.Domain.Entities;

public sealed class PasswordResetToken
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string TokenHash { get; set; } = string.Empty;
    public DateTime ExpiresAtUtc { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime? UsedAtUtc { get; set; }

    public bool IsActive => UsedAtUtc is null && ExpiresAtUtc > DateTime.UtcNow;
    public User User { get; set; } = default!;
}
