using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using NewCarPool.Domain.Entities;

namespace NewCarPool.Infrastructure.Data.Configurations;

public sealed class PendingRegistrationOtpConfiguration : IEntityTypeConfiguration<PendingRegistrationOtp>
{
    public void Configure(EntityTypeBuilder<PendingRegistrationOtp> builder)
    {
        builder.ToTable("PendingRegistrationOtps");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.FullName).HasMaxLength(150).IsRequired();
        builder.Property(x => x.Email).HasMaxLength(256).IsRequired();
        builder.Property(x => x.PhoneNumber).HasMaxLength(30).IsRequired();
        builder.Property(x => x.PasswordHash).HasMaxLength(500).IsRequired();
        builder.Property(x => x.OtpHash).HasMaxLength(128).IsRequired();
        builder.HasIndex(x => x.Email).IsUnique();
        builder.HasIndex(x => x.PhoneNumber);
    }
}
