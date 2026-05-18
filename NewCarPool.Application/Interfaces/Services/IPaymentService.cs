using NewCarPool.Application.DTOs.Payments;

namespace NewCarPool.Application.Interfaces.Services;

public interface IPaymentService
{
    Task<PaymentDto> CreateAsync(Guid userId, CreatePaymentRequest request, CancellationToken cancellationToken);
    Task<PaymentDto> VerifyAsync(Guid userId, VerifyPaymentRequest request, CancellationToken cancellationToken);
    Task<IReadOnlyList<PaymentDto>> HistoryAsync(Guid userId, CancellationToken cancellationToken);
}
