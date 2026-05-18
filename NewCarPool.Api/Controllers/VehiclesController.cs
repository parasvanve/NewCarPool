using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using NewCarPool.Api.Extensions;
using NewCarPool.Application.DTOs.Vehicles;
using NewCarPool.Application.Interfaces.Services;

namespace NewCarPool.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public sealed class VehiclesController : ControllerBase
{
    private readonly IVehicleService _vehicleService;

    public VehiclesController(IVehicleService vehicleService) => _vehicleService = vehicleService;

    [HttpGet("mine")]
    public async Task<ActionResult<IReadOnlyList<VehicleDto>>> Mine(CancellationToken cancellationToken) =>
        Ok(await _vehicleService.GetMineAsync(User.GetUserId(), cancellationToken));

    [HttpPost]
    public async Task<ActionResult<VehicleDto>> Add(UpsertVehicleRequest request, CancellationToken cancellationToken) =>
        Ok(await _vehicleService.AddAsync(User.GetUserId(), request, cancellationToken));

    [HttpPut("{vehicleId:guid}")]
    public async Task<ActionResult<VehicleDto>> Update(Guid vehicleId, UpsertVehicleRequest request, CancellationToken cancellationToken) =>
        Ok(await _vehicleService.UpdateAsync(User.GetUserId(), vehicleId, request, cancellationToken));

    [HttpDelete("{vehicleId:guid}")]
    public async Task<IActionResult> Delete(Guid vehicleId, CancellationToken cancellationToken)
    {
        await _vehicleService.DeleteAsync(User.GetUserId(), vehicleId, cancellationToken);
        return NoContent();
    }
}
