using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using NewCarPool.Domain.Entities;

namespace NewCarPool.Infrastructure.Data.Configurations;

public sealed class RideLocationUpdateConfiguration : IEntityTypeConfiguration<RideLocationUpdate>
{
    public void Configure(EntityTypeBuilder<RideLocationUpdate> builder)
    {
        builder.ToTable("RideLocationUpdates");
        builder.HasKey(x => x.Id);
        builder.HasIndex(x => new { x.RideOfferId, x.CreatedAtUtc });
        builder.HasOne(x => x.RideOffer)
            .WithMany(x => x.LocationUpdates)
            .HasForeignKey(x => x.RideOfferId)
            .OnDelete(DeleteBehavior.Cascade);
        builder.HasOne(x => x.Driver)
            .WithMany()
            .HasForeignKey(x => x.DriverId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
