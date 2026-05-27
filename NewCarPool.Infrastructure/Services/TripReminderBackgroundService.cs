using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using NewCarPool.Domain.Entities;
using NewCarPool.Domain.Enums;
using NewCarPool.Infrastructure.Data;

namespace NewCarPool.Infrastructure.Services;

public sealed class TripReminderBackgroundService : BackgroundService
{
    private static readonly int[] ReminderWindowsMinutes = [60, 30, 10];
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<TripReminderBackgroundService> _logger;

    public TripReminderBackgroundService(
        IServiceScopeFactory scopeFactory,
        ILogger<TripReminderBackgroundService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await GenerateRemindersAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Trip reminder background job failed.");
            }

            await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
        }
    }

    private async Task GenerateRemindersAsync(CancellationToken cancellationToken)
    {
        await using var scope = _scopeFactory.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<NewCarPoolDbContext>();
        var now = DateTime.UtcNow;

        foreach (var window in ReminderWindowsMinutes)
        {
            var from = now.AddMinutes(window).AddSeconds(-40);
            var to = now.AddMinutes(window).AddSeconds(40);

            var rides = await db.RideOffers
                .AsNoTracking()
                .Where(r =>
                    (r.Status == RideStatus.Open || r.Status == RideStatus.Full || r.Status == RideStatus.Started) &&
                    r.DepartureTimeUtc >= from &&
                    r.DepartureTimeUtc <= to)
                .Select(r => new
                {
                    Ride = r,
                    DriverName = r.Driver.FullName,
                    Bookings = r.Bookings
                        .Where(b => b.Status == BookingStatus.Confirmed)
                        .Select(b => new
                        {
                            b.PassengerId,
                            b.PassengerPickupName
                        })
                        .ToList()
                })
                .ToListAsync(cancellationToken);

            foreach (var row in rides)
            {
                var ride = row.Ride;
                if (ride.Status is RideStatus.Completed or RideStatus.Cancelled) continue;

                var title = "Upcoming ride reminder";
                var driverMessage =
                    $"Your ride starts in {window} minutes. Route: {ShortName(ride.OriginName)} to {ShortName(ride.DestinationName)}.";
                await CreateReminderIfMissingAsync(
                    db,
                    ride.Id,
                    ride.DriverId,
                    window,
                    title,
                    driverMessage,
                    cancellationToken);

                foreach (var booking in row.Bookings)
                {
                    var pickup = ShortName(booking.PassengerPickupName);
                    var passengerMessage =
                        $"Your ride starts in {window} minutes. Pickup: {pickup}. Driver: {row.DriverName}.";
                    await CreateReminderIfMissingAsync(
                        db,
                        ride.Id,
                        booking.PassengerId,
                        window,
                        title,
                        passengerMessage,
                        cancellationToken);
                }
            }
        }

        await db.SaveChangesAsync(cancellationToken);
    }

    private static async Task CreateReminderIfMissingAsync(
        NewCarPoolDbContext db,
        Guid rideId,
        Guid userId,
        int windowMinutes,
        string title,
        string message,
        CancellationToken cancellationToken)
    {
        var exists = await db.Notifications
            .AsNoTracking()
            .AnyAsync(n =>
                n.UserId == userId &&
                n.RideId == rideId &&
                n.Type == NotificationType.TripReminder &&
                n.Title == title &&
                n.Message == message,
                cancellationToken);
        if (exists) return;

        db.Notifications.Add(new Notification
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Title = title,
            Message = message,
            Type = NotificationType.TripReminder,
            RideId = rideId,
            IsRead = false,
            CreatedAtUtc = DateTime.UtcNow
        });
    }

    private static string ShortName(string? value)
    {
        var text = value?.Trim() ?? string.Empty;
        if (text.Length == 0) return "Location";
        var idx = text.IndexOf(',');
        return idx > 0 ? text[..idx].Trim() : text;
    }
}
