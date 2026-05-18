using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using NewCarPool.Api.Extensions;
using NewCarPool.Application.DTOs.Payments;
using NewCarPool.Application.Interfaces.Services;

namespace NewCarPool.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public sealed class PaymentsController : ControllerBase
{
    private readonly IPaymentService _paymentService;

    public PaymentsController(IPaymentService paymentService) => _paymentService = paymentService;

    [HttpPost]
    public async Task<ActionResult<PaymentDto>> Create(CreatePaymentRequest request, CancellationToken cancellationToken) =>
        Ok(await _paymentService.CreateAsync(User.GetUserId(), request, cancellationToken));

    [HttpPost("verify")]
    public async Task<ActionResult<PaymentDto>> Verify(VerifyPaymentRequest request, CancellationToken cancellationToken) =>
        Ok(await _paymentService.VerifyAsync(User.GetUserId(), request, cancellationToken));

    [HttpGet("history")]
    public async Task<ActionResult<IReadOnlyList<PaymentDto>>> History(CancellationToken cancellationToken) =>
        Ok(await _paymentService.HistoryAsync(User.GetUserId(), cancellationToken));
}
