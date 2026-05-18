namespace NewCarPool.Application.DTOs.Admin;

public sealed record DashboardStatsDto(
    int TotalUsers,
    int ActiveUsers,
    int TotalVehicles,
    int VerifiedVehicles,
    int TotalRides,
    int CompletedRides,
    int TotalBookings,
    decimal TotalPayments);
