using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using NewCarPool.Application.DTOs.Maps;
using NewCarPool.Application.Interfaces.Services;

namespace NewCarPool.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public sealed class MapsController : ControllerBase
{
    private readonly IMapService _mapService;

    public MapsController(IMapService mapService) => _mapService = mapService;

    [HttpPost("route")]
    public async Task<ActionResult<RouteResultDto>> Route(RouteRequest request, CancellationToken cancellationToken) =>
        Ok(await _mapService.CalculateRouteAsync(request, cancellationToken));

    [HttpGet("geocode")]
    public async Task<ActionResult<IReadOnlyList<GeocodeResultDto>>> Search(
        [FromQuery] string query,
        [FromQuery] double? latitude,
        [FromQuery] double? longitude,
        CancellationToken cancellationToken) =>
        Ok(await _mapService.SearchPlacesAsync(query, latitude, longitude, cancellationToken));

    [HttpGet("reverse-geocode")]
    public async Task<ActionResult<ReverseGeocodeResultDto>> ReverseGeocode(
        [FromQuery] double latitude,
        [FromQuery] double longitude,
        CancellationToken cancellationToken) =>
        Ok(await _mapService.ReverseGeocodeAsync(latitude, longitude, cancellationToken));
}
