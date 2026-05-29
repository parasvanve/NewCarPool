using Microsoft.OpenApi.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Data;
using NewCarPool.Application.Common;
using NewCarPool.Api.Hubs;
using NewCarPool.Api.Middleware;
using NewCarPool.Infrastructure;
using NewCarPool.Infrastructure.Data;
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

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<NewCarPoolDbContext>();
    db.Database.Migrate();

    using var connection = db.Database.GetDbConnection();
    if (connection.State != ConnectionState.Open)
    {
        connection.Open();
    }

    using var command = connection.CreateCommand();
    command.CommandText = """
        IF COL_LENGTH('RideOffers', 'OriginAddress') IS NULL
            ALTER TABLE RideOffers ADD OriginAddress nvarchar(500) NOT NULL CONSTRAINT DF_RideOffers_OriginAddress DEFAULT '';

        IF COL_LENGTH('RideOffers', 'DestinationAddress') IS NULL
            ALTER TABLE RideOffers ADD DestinationAddress nvarchar(500) NOT NULL CONSTRAINT DF_RideOffers_DestinationAddress DEFAULT '';

        IF COL_LENGTH('RideOffers', 'Notes') IS NULL
            ALTER TABLE RideOffers ADD Notes nvarchar(1000) NULL;

        IF COL_LENGTH('RideOffers', 'StartedAtUtc') IS NULL
            ALTER TABLE RideOffers ADD StartedAtUtc datetime2 NULL;

        IF COL_LENGTH('RideOffers', 'CompletedAtUtc') IS NULL
            ALTER TABLE RideOffers ADD CompletedAtUtc datetime2 NULL;

        IF COL_LENGTH('RideOffers', 'CancelledAtUtc') IS NULL
            ALTER TABLE RideOffers ADD CancelledAtUtc datetime2 NULL;

        IF COL_LENGTH('RideOffers', 'CancellationReason') IS NULL
            ALTER TABLE RideOffers ADD CancellationReason nvarchar(1000) NULL;

        IF OBJECT_ID('RideStops', 'U') IS NULL
        BEGIN
            CREATE TABLE RideStops (
                Id uniqueidentifier NOT NULL PRIMARY KEY,
                RideOfferId uniqueidentifier NOT NULL,
                Name nvarchar(200) NOT NULL,
                Address nvarchar(500) NOT NULL,
                Latitude float NOT NULL,
                Longitude float NOT NULL,
                StopOrder int NOT NULL,
                CreatedAtUtc datetime2 NOT NULL,
                CONSTRAINT FK_RideStops_RideOffers_RideOfferId FOREIGN KEY (RideOfferId) REFERENCES RideOffers(Id) ON DELETE CASCADE
            );
            CREATE UNIQUE INDEX IX_RideStops_RideOfferId_StopOrder ON RideStops(RideOfferId, StopOrder);
        END
        """;
    command.ExecuteNonQuery();
}

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

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
