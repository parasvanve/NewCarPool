namespace NewCarPool.Application.Interfaces.Services;

public interface IEmailService
{
    Task SendAsync(string toEmail, string subject, string body, CancellationToken cancellationToken);
}
