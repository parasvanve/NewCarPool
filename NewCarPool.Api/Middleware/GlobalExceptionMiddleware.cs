using System.Net;
using NewCarPool.Application.Common;
using Microsoft.EntityFrameworkCore;

namespace NewCarPool.Api.Middleware;

public sealed class GlobalExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<GlobalExceptionMiddleware> _logger;
    private readonly IHostEnvironment _environment;

    public GlobalExceptionMiddleware(
        RequestDelegate next,
        ILogger<GlobalExceptionMiddleware> logger,
        IHostEnvironment environment)
    {
        _next = next;
        _logger = logger;
        _environment = environment;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (ApiException exception)
        {
            await WriteProblemAsync(context, exception.StatusCode, exception.Message);
        }
        catch (UnauthorizedAccessException exception)
        {
            await WriteProblemAsync(context, (int)HttpStatusCode.Unauthorized, exception.Message);
        }
        catch (DbUpdateException exception)
        {
            _logger.LogError(exception, "Database update error");
            var baseMessage = exception.InnerException?.Message ?? exception.Message;
            await WriteProblemAsync(context, (int)HttpStatusCode.BadRequest, $"Ride data could not be saved. {baseMessage}");
        }
        catch (Exception exception)
        {
            _logger.LogError(exception, "Unhandled exception");
            var message = _environment.IsDevelopment()
                ? (exception.InnerException?.Message ?? exception.Message)
                : "Unexpected server error.";
            await WriteProblemAsync(context, (int)HttpStatusCode.InternalServerError, message);
        }
    }

    private static async Task WriteProblemAsync(HttpContext context, int statusCode, string message)
    {
        context.Response.StatusCode = statusCode;
        await context.Response.WriteAsJsonAsync(new ApiError(statusCode, message, context.TraceIdentifier));
    }
}
