using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using NewCarPool.Domain.Entities;

namespace NewCarPool.Infrastructure.Data.Configurations;

public sealed class RideStopConfiguration : IEntityTypeConfiguration<RideStop>
{
    public void Configure(EntityTypeBuilder<RideStop> builder)
    {
        builder.ToTable("RideStops");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Name).HasMaxLength(200).IsRequired();
        builder.Property(x => x.Address).HasMaxLength(500).IsRequired();
        builder.HasIndex(x => new { x.RideOfferId, x.StopOrder }).IsUnique();
        builder.HasOne(x => x.RideOffer)
            .WithMany(x => x.IntermediateStops)
            .HasForeignKey(x => x.RideOfferId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
