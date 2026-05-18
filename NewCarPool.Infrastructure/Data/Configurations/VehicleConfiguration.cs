using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using NewCarPool.Domain.Entities;

namespace NewCarPool.Infrastructure.Data.Configurations;

public sealed class VehicleConfiguration : IEntityTypeConfiguration<Vehicle>
{
    public void Configure(EntityTypeBuilder<Vehicle> builder)
    {
        builder.ToTable("Vehicles");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.VehicleName).HasMaxLength(100).IsRequired();
        builder.Property(x => x.VehicleNumber).HasMaxLength(30).IsRequired();
        builder.Property(x => x.Color).HasMaxLength(40).IsRequired();
        builder.Property(x => x.RcImagePath).HasMaxLength(500);
        builder.Property(x => x.VehicleImagePath).HasMaxLength(500);
        builder.HasIndex(x => x.VehicleNumber).IsUnique();
        builder.HasOne(x => x.Owner)
            .WithMany(x => x.Vehicles)
            .HasForeignKey(x => x.OwnerId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
