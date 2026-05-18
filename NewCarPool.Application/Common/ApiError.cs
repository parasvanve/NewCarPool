namespace NewCarPool.Application.Common;

public sealed record ApiError(
    int Status,
    string Title,
    string TraceId,
    IReadOnlyDictionary<string, string[]>? Errors = null);
