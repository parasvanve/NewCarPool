using NewCarPool.Domain.Enums;

namespace NewCarPool.Application.DTOs.Vehicles;

public sealed record VehicleDto(
    Guid Id,
    string VehicleName,
    string VehicleNumber,
    VehicleType VehicleType,
    string Color,
    int Seats,
    string? RcImagePath,
    string? VehicleImagePath,
    bool IsVerified);

public sealed record UpsertVehicleRequest(
    string VehicleName,
    string VehicleNumber,
    VehicleType VehicleType,
    string Color,
    int Seats,
    string? RcImagePath,
    string? VehicleImagePath);
