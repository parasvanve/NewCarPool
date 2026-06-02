using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Application.Interfaces.Services;
using NewCarPool.Infrastructure.Authentication;
using NewCarPool.Infrastructure.Data;
using NewCarPool.Infrastructure.Repositories;
using NewCarPool.Infrastructure.Services;

namespace NewCarPool.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<JwtOptions>(configuration.GetSection(JwtOptions.SectionName));
        var jwtOptions = configuration.GetSection(JwtOptions.SectionName).Get<JwtOptions>()
            ?? throw new InvalidOperationException("Jwt configuration is missing.");

        services.AddDbContext<NewCarPoolDbContext>(options =>
            options.UseSqlServer(
                configuration.GetConnectionString("DefaultConnection"),
                sqlOptions =>
                {
                    sqlOptions.EnableRetryOnFailure(
                        maxRetryCount: 5,
                        maxRetryDelay: TimeSpan.FromSeconds(10),
                        errorNumbersToAdd: null);
                }));
        services.AddHttpClient("OpenRouteService", client =>
        {
            client.BaseAddress = new Uri(configuration["ExternalApis:OpenRouteServiceBaseUrl"] ?? "https://api.openrouteservice.org");
        });
        services.AddHttpClient("Nominatim", client =>
        {
            client.BaseAddress = new Uri(configuration["ExternalApis:NominatimBaseUrl"] ?? "https://nominatim.openstreetmap.org");
            client.DefaultRequestHeaders.UserAgent.ParseAdd("NewCarPool/1.0");
        });

        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidateAudience = true,
                    ValidateIssuerSigningKey = true,
                    ValidateLifetime = true,
                    ValidIssuer = jwtOptions.Issuer,
                    ValidAudience = jwtOptions.Audience,
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.SigningKey)),
                    ClockSkew = TimeSpan.FromMinutes(1)
                };

                options.Events = new JwtBearerEvents
                {
                    OnMessageReceived = context =>
                    {
                        var accessToken = context.Request.Query["access_token"];
                        var path = context.HttpContext.Request.Path;
                        if (!string.IsNullOrWhiteSpace(accessToken) &&
                            (path.StartsWithSegments("/hubs/tracking") || path.StartsWithSegments("/hubs/notifications")))
                        {
                            context.Token = accessToken;
                        }

                        return Task.CompletedTask;
                    }
                };
            });

        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped(typeof(IGenericRepository<>), typeof(GenericRepository<>));
        services.AddScoped<IRideRepository, RideRepository>();
        services.AddScoped<IRefreshTokenRepository, RefreshTokenRepository>();
        services.AddScoped<IUnitOfWork, UnitOfWork>();
        services.AddScoped<ITokenService, TokenService>();
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IRideService, RideService>();
        services.AddScoped<IBookingService, BookingService>();
        services.AddScoped<ITrackingService, TrackingService>();
        services.AddScoped<IUserProfileService, UserProfileService>();
        services.AddScoped<IVehicleService, VehicleService>();
        services.AddScoped<IPaymentService, PaymentService>();
        services.AddScoped<INotificationService, NotificationService>();
        services.AddScoped<IReviewService, ReviewService>();
        services.AddScoped<IMapService, MapService>();
        services.AddScoped<IAdminService, AdminService>();
        services.AddHostedService<TripReminderBackgroundService>();

        return services;
    }
}
