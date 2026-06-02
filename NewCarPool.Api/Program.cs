using Microsoft.OpenApi.Models;
using Microsoft.AspNetCore.Mvc;
using NewCarPool.Application.Common;
using NewCarPool.Api.Hubs;
using NewCarPool.Api.Middleware;
using NewCarPool.Infrastructure;
using NewCarPool.Infrastructure.Hubs;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers()
    .ConfigureApiBehaviorOptions(options =>
    {
        options.InvalidModelStateResponseFactory = context =>
        {
            var errors = context.ModelState
                .Where(x => x.Value?.Errors.Count > 0)
                .ToDictionary(
                    x => x.Key,
                    x => x.Value!.Errors.Select(error => error.ErrorMessage).ToArray());

            return new BadRequestObjectResult(new ApiError(
                StatusCodes.Status400BadRequest,
                "Validation failed.",
                context.HttpContext.TraceIdentifier,
                errors));
        };
    });
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddInfrastructure(builder.Configuration);
builder.Services.AddSignalR();
builder.Services.AddHealthChecks();
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("Admin", policy => policy.RequireClaim("is_admin", "true"));
});
builder.Services.AddCors(options =>
{
    options.AddPolicy("MobileClient", policy =>
        policy.AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials()
            .SetIsOriginAllowed(_ => true));
});
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "NewCarPool API",
        Version = "v1",
        Description = "Ride sharing API with dynamic driver/passenger behavior, JWT auth, refresh tokens, maps, and realtime tracking."
    });
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Enter a valid JWT access token."
    });
    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI();

app.UseMiddleware<GlobalExceptionMiddleware>();
app.UseHttpsRedirection();
app.UseCors("MobileClient");
app.UseStaticFiles();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHealthChecks("/health");
app.MapHub<TrackingHub>("/hubs/tracking");
app.MapHub<AppRealtimeHub>("/hubs/notifications");

app.Run();
