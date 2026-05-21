using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using NewCarPool.Domain.Entities;

namespace NewCarPool.Infrastructure.Data.Configurations;

public sealed class RideChatMessageConfiguration : IEntityTypeConfiguration<RideChatMessage>
{
    public void Configure(EntityTypeBuilder<RideChatMessage> builder)
    {
        builder.ToTable("RideChatMessages");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Message).HasMaxLength(2000).IsRequired();
        builder.HasIndex(x => new { x.RideChatGroupId, x.CreatedAtUtc });
        builder.HasOne(x => x.RideChatGroup)
            .WithMany(x => x.Messages)
            .HasForeignKey(x => x.RideChatGroupId)
            .OnDelete(DeleteBehavior.Cascade);
        builder.HasOne(x => x.SenderUser)
            .WithMany(x => x.RideChatMessages)
            .HasForeignKey(x => x.SenderUserId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
