using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using NewCarPool.Application.Interfaces.Services;

namespace NewCarPool.Api.Controllers;

[ApiController]
[Authorize(Policy = "Admin")]
[Route("api/[controller]")]
public sealed class AdminController : ControllerBase
{
    private readonly IAdminService _adminService;

    public AdminController(IAdminService adminService) => _adminService = adminService;

    [HttpGet("users")]
    public async Task<IActionResult> Users(CancellationToken cancellationToken) =>
        Ok(await _adminService.GetUsersAsync(cancellationToken));

    [HttpPost("users/{userId:guid}/block")]
    public async Task<IActionResult> BlockUser(Guid userId, CancellationToken cancellationToken)
    {
        await _adminService.BlockUserAsync(userId, cancellationToken);
        return NoContent();
    }

    [HttpPost("vehicles/{vehicleId:guid}/verify")]
    public async Task<IActionResult> VerifyVehicle(Guid vehicleId, CancellationToken cancellationToken)
    {
        await _adminService.VerifyVehicleAsync(vehicleId, cancellationToken);
        return NoContent();
    }

    [HttpGet("rides")]
    public async Task<IActionResult> Rides(CancellationToken cancellationToken) =>
        Ok(await _adminService.GetRidesAsync(cancellationToken));

    [HttpGet("dashboard")]
    public async Task<IActionResult> Dashboard(CancellationToken cancellationToken) =>
        Ok(await _adminService.GetStatsAsync(cancellationToken));
}
