namespace NewCarPool.Application.Common;

public sealed class ApiException : Exception
{
    public ApiException(string message, int statusCode = 400) : base(message)
    {
        StatusCode = statusCode;
    }

    public int StatusCode { get; }
}
