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
        builder.Property(x => x.MessageType).IsRequired();
        builder.Property(x => x.AttachmentUrl).HasMaxLength(1000);
        builder.Property(x => x.AttachmentFileName).HasMaxLength(255);
        builder.Property(x => x.AttachmentContentType).HasMaxLength(100);
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
