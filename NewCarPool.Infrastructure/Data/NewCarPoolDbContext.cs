using Microsoft.EntityFrameworkCore;
using NewCarPool.Domain.Entities;

namespace NewCarPool.Infrastructure.Data;

public sealed class NewCarPoolDbContext : DbContext
{
    public NewCarPoolDbContext(DbContextOptions<NewCarPoolDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users => Set<User>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<PasswordResetToken> PasswordResetTokens => Set<PasswordResetToken>();
    public DbSet<PendingRegistrationOtp> PendingRegistrationOtps => Set<PendingRegistrationOtp>();
    public DbSet<Vehicle> Vehicles => Set<Vehicle>();
    public DbSet<RideOffer> RideOffers => Set<RideOffer>();
    public DbSet<RideStop> RideStops => Set<RideStop>();
    public DbSet<RideChatGroup> RideChatGroups => Set<RideChatGroup>();
    public DbSet<RideChatMessage> RideChatMessages => Set<RideChatMessage>();
    public DbSet<RideBooking> RideBookings => Set<RideBooking>();
    public DbSet<RideLocationUpdate> RideLocationUpdates => Set<RideLocationUpdate>();
    public DbSet<Payment> Payments => Set<Payment>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<Review> Reviews => Set<Review>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(NewCarPoolDbContext).Assembly);
    }
}
