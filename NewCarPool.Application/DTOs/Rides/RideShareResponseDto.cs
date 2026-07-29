using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NewCarPool.Application.DTOs.Rides
{
    public sealed record RideShareResponseDto(
    string DriverName,
    string Origin,
    string Destination,
    string DepartureTime,
    int AvailableSeats,
    decimal PricePerSeat,
    string ShareUrl);
}
