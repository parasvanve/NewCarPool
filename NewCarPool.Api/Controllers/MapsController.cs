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
    public async Task<ActionResult<IReadOnlyList<GeocodeResultDto>>> Search([FromQuery] string query, CancellationToken cancellationToken) =>
        Ok(await _mapService.SearchPlacesAsync(query, cancellationToken));
}
