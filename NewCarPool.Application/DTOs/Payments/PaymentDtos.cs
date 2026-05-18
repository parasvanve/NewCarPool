using NewCarPool.Domain.Enums;

namespace NewCarPool.Application.DTOs.Payments;

public sealed record PaymentDto(
    Guid Id,
    Guid BookingId,
    decimal Amount,
    string TransactionId,
    PaymentStatus PaymentStatus,
    PaymentMethod PaymentMethod,
    DateTime CreatedAtUtc);

public sealed record CreatePaymentRequest(
    Guid BookingId,
    decimal Amount,
    string TransactionId,
    PaymentMethod PaymentMethod);

public sealed record VerifyPaymentRequest(string TransactionId);
