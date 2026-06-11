using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using NewCarPool.Domain.Entities;

namespace NewCarPool.Infrastructure.Data.Configurations;

public sealed class RideOfferConfiguration : IEntityTypeConfiguration<RideOffer>
{
    public void Configure(EntityTypeBuilder<RideOffer> builder)
    {
        builder.ToTable("RideOffers");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.OriginName).HasMaxLength(300).IsRequired();
        builder.Property(x => x.OriginAddress).HasMaxLength(500).IsRequired();
        builder.Property(x => x.DestinationName).HasMaxLength(300).IsRequired();
        builder.Property(x => x.DestinationAddress).HasMaxLength(500).IsRequired();
        builder.Property(x => x.PricePerSeat).HasPrecision(10, 2);
        builder.Property(x => x.Notes).HasMaxLength(1000);
        builder.Property(x => x.CancellationReason).HasMaxLength(1000);
        builder.Property(x => x.VehicleName).HasMaxLength(100);
        builder.Property(x => x.VehicleNumber).HasMaxLength(30);
        builder.Property(x => x.RoutePolyline).HasMaxLength(8000);
        builder.Property(x => x.DistanceKm).HasPrecision(9, 2);
        builder.HasIndex(x => new { x.Id, x.LastDriverLocationAtUtc });
        builder.HasIndex(x => new { x.DepartureTimeUtc, x.Status });
        builder.HasOne(x => x.Driver)
            .WithMany(x => x.OfferedRides)
            .HasForeignKey(x => x.DriverId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(x => x.Vehicle)
            .WithMany(x => x.RideOffers)
            .HasForeignKey(x => x.VehicleId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
