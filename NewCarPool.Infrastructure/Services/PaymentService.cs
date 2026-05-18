using Microsoft.EntityFrameworkCore;
using NewCarPool.Application.Common;
using NewCarPool.Application.DTOs.Payments;
using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Application.Interfaces.Services;
using NewCarPool.Domain.Entities;
using NewCarPool.Domain.Enums;

namespace NewCarPool.Infrastructure.Services;

public sealed class PaymentService : IPaymentService
{
    private readonly IGenericRepository<Payment> _payments;
    private readonly IGenericRepository<RideBooking> _bookings;
    private readonly IUnitOfWork _unitOfWork;

    public PaymentService(IGenericRepository<Payment> payments, IGenericRepository<RideBooking> bookings, IUnitOfWork unitOfWork)
    {
        _payments = payments;
        _bookings = bookings;
        _unitOfWork = unitOfWork;
    }

    public async Task<PaymentDto> CreateAsync(Guid userId, CreatePaymentRequest request, CancellationToken cancellationToken)
    {
        var booking = await _bookings.GetByIdAsync(request.BookingId, cancellationToken) ?? throw new ApiException("Booking not found.", 404);
        if (booking.PassengerId != userId)
        {
            throw new ApiException("You can only pay for your own booking.", 403);
        }

        var payment = new Payment
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            BookingId = request.BookingId,
            Amount = request.Amount,
            TransactionId = request.TransactionId.Trim(),
            PaymentMethod = request.PaymentMethod
        };
        await _payments.AddAsync(payment, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return Map(payment);
    }

    public async Task<PaymentDto> VerifyAsync(Guid userId, VerifyPaymentRequest request, CancellationToken cancellationToken)
    {
        var payment = await _payments.Query().FirstOrDefaultAsync(x => x.TransactionId == request.TransactionId, cancellationToken)
            ?? throw new ApiException("Payment not found.", 404);
        if (payment.UserId != userId)
        {
            throw new ApiException("You cannot verify this payment.", 403);
        }

        payment.PaymentStatus = PaymentStatus.Verified;
        payment.VerifiedAtUtc = DateTime.UtcNow;
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return Map(payment);
    }

    public async Task<IReadOnlyList<PaymentDto>> HistoryAsync(Guid userId, CancellationToken cancellationToken) =>
        await _payments.Query().Where(x => x.UserId == userId).OrderByDescending(x => x.CreatedAtUtc).Select(x => Map(x)).ToListAsync(cancellationToken);

    private static PaymentDto Map(Payment payment) =>
        new(payment.Id, payment.BookingId, payment.Amount, payment.TransactionId, payment.PaymentStatus, payment.PaymentMethod, payment.CreatedAtUtc);
}
