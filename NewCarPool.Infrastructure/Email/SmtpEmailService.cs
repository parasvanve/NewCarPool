using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Options;
using NewCarPool.Application.Common;
using NewCarPool.Application.Interfaces.Services;

namespace NewCarPool.Infrastructure.Email;

public sealed class SmtpEmailService : IEmailService
{
    private readonly SmtpOptions _options;

    public SmtpEmailService(IOptions<SmtpOptions> options) => _options = options.Value;

    public async Task SendAsync(string toEmail, string subject, string body, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(_options.Host) ||
            string.IsNullOrWhiteSpace(_options.FromEmail))
        {
            throw new ApiException("Email service is not configured.");
        }

        using var message = new MailMessage
        {
            From = new MailAddress(_options.FromEmail, _options.FromName),
            Subject = subject,
            Body = body,
            IsBodyHtml = false
        };
        message.To.Add(toEmail);

        using var client = new SmtpClient(_options.Host, _options.Port)
        {
            EnableSsl = true
        };

        if (!string.IsNullOrWhiteSpace(_options.Username))
        {
            client.Credentials = new NetworkCredential(_options.Username, _options.Password);
        }

        using var registration = cancellationToken.Register(client.SendAsyncCancel);
        await client.SendMailAsync(message, cancellationToken);
    }
}
