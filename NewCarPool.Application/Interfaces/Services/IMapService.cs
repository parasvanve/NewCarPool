using NewCarPool.Application.DTOs.Maps;

namespace NewCarPool.Application.Interfaces.Services;

public interface IMapService
{
    Task<RouteResultDto> CalculateRouteAsync(RouteRequest request, CancellationToken cancellationToken);
    Task<IReadOnlyList<GeocodeResultDto>> SearchPlacesAsync(string query, double? latitude, double? longitude, CancellationToken cancellationToken);
    Task<ReverseGeocodeResultDto> ReverseGeocodeAsync(double latitude, double longitude, CancellationToken cancellationToken);
}
