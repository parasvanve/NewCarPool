using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using NewCarPool.Domain.Entities;

namespace NewCarPool.Infrastructure.Data.Configurations;

public sealed class RideBookingConfiguration : IEntityTypeConfiguration<RideBooking>
{
    public void Configure(EntityTypeBuilder<RideBooking> builder)
    {
        builder.ToTable("RideBookings");
        builder.HasKey(x => x.Id);
        builder.HasIndex(x => new { x.RideOfferId, x.PassengerId });
        builder.Property(x => x.PassengerPickupName).HasMaxLength(300);
        builder.Property(x => x.PassengerPickupAddress).HasMaxLength(500);
        builder.Property(x => x.PassengerDropName).HasMaxLength(300);
        builder.Property(x => x.PassengerDropAddress).HasMaxLength(500);
        builder.HasOne(x => x.RideOffer)
            .WithMany(x => x.Bookings)
            .HasForeignKey(x => x.RideOfferId)
            .OnDelete(DeleteBehavior.Cascade);
        builder.HasOne(x => x.Passenger)
            .WithMany(x => x.Bookings)
            .HasForeignKey(x => x.PassengerId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
