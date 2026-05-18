using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using NewCarPool.Api.Extensions;
using NewCarPool.Application.DTOs.Users;
using NewCarPool.Application.Interfaces.Services;

namespace NewCarPool.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/profile")]
public sealed class ProfileController : ControllerBase
{
    private readonly IUserProfileService _profileService;
    private readonly IWebHostEnvironment _environment;

    public ProfileController(IUserProfileService profileService, IWebHostEnvironment environment)
    {
        _profileService = profileService;
        _environment = environment;
    }

    [HttpGet]
    public async Task<ActionResult<UserProfileDto>> Get(CancellationToken cancellationToken) =>
        Ok(await _profileService.GetProfileAsync(User.GetUserId(), cancellationToken));

    [HttpPut]
    public async Task<ActionResult<UserProfileDto>> Update(UpdateProfileRequest request, CancellationToken cancellationToken) =>
        Ok(await _profileService.UpdateProfileAsync(User.GetUserId(), request, cancellationToken));

    [HttpPost("image")]
    [RequestSizeLimit(5_000_000)]
    public async Task<ActionResult<UserProfileDto>> UploadImage(IFormFile file, CancellationToken cancellationToken)
    {
        var relativePath = await SaveUploadAsync(file, "profiles", cancellationToken);
        return Ok(await _profileService.UpdateProfileImageAsync(User.GetUserId(), relativePath, cancellationToken));
    }

    private async Task<string> SaveUploadAsync(IFormFile file, string folder, CancellationToken cancellationToken)
    {
        if (file.Length == 0)
        {
            throw new BadHttpRequestException("File is empty.");
        }

        var uploads = Path.Combine(_environment.WebRootPath ?? Path.Combine(_environment.ContentRootPath, "wwwroot"), "uploads", folder);
        Directory.CreateDirectory(uploads);
        var fileName = $"{Guid.NewGuid()}{Path.GetExtension(file.FileName)}";
        var path = Path.Combine(uploads, fileName);
        await using var stream = System.IO.File.Create(path);
        await file.CopyToAsync(stream, cancellationToken);
        return $"/uploads/{folder}/{fileName}";
    }
}
