using NewCarPool.Domain.Enums;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using NewCarPool.Application.DTOs.Rides;

namespace NewCarPool.Application.DTOs.Rides;

public sealed record SharedRideDto(
    Guid RideId,
    string DriverName,
    GeoPointDto Origin,
    GeoPointDto Destination,
    IReadOnlyList<RideStopDto> Stops,
    DateTime DepartureTimeUtc,
    int AvailableSeats,
    decimal PricePerSeat,
    string? VehicleName,
    string? VehicleNumber,
    RideStatus Status);
