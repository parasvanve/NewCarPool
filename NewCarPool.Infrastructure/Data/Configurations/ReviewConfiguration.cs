using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using NewCarPool.Domain.Entities;

namespace NewCarPool.Infrastructure.Data.Configurations;

public sealed class ReviewConfiguration : IEntityTypeConfiguration<Review>
{
    public void Configure(EntityTypeBuilder<Review> builder)
    {
        builder.ToTable("Reviews");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Comment).HasMaxLength(1000);
        builder.HasIndex(x => new { x.RideOfferId, x.ReviewerId, x.RevieweeId }).IsUnique();
        builder.HasOne(x => x.RideOffer)
            .WithMany()
            .HasForeignKey(x => x.RideOfferId)
            .OnDelete(DeleteBehavior.Cascade);
        builder.HasOne(x => x.Reviewer)
            .WithMany()
            .HasForeignKey(x => x.ReviewerId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(x => x.Reviewee)
            .WithMany()
            .HasForeignKey(x => x.RevieweeId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
