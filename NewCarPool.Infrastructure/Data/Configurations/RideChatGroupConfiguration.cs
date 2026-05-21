using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using NewCarPool.Domain.Entities;

namespace NewCarPool.Infrastructure.Data.Configurations;

public sealed class RideChatGroupConfiguration : IEntityTypeConfiguration<RideChatGroup>
{
    public void Configure(EntityTypeBuilder<RideChatGroup> builder)
    {
        builder.ToTable("RideChatGroups");
        builder.HasKey(x => x.Id);
        builder.HasIndex(x => x.RideOfferId).IsUnique();
        builder.HasOne(x => x.RideOffer)
            .WithOne(x => x.ChatGroup)
            .HasForeignKey<RideChatGroup>(x => x.RideOfferId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
