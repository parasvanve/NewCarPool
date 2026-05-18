using NewCarPool.Domain.Entities;

namespace NewCarPool.Application.Interfaces.Services;

public interface ITokenService
{
    string CreateAccessToken(User user, DateTime expiresAtUtc);
    string CreateRefreshToken();
    string HashToken(string token);
}
