using Microsoft.EntityFrameworkCore;
using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Domain.Entities;
using NewCarPool.Infrastructure.Data;

namespace NewCarPool.Infrastructure.Repositories;

public sealed class RefreshTokenRepository : IRefreshTokenRepository
{
    private readonly NewCarPoolDbContext _dbContext;

    public RefreshTokenRepository(NewCarPoolDbContext dbContext) => _dbContext = dbContext;

    public async Task AddAsync(RefreshToken token, CancellationToken cancellationToken) =>
        await _dbContext.RefreshTokens.AddAsync(token, cancellationToken);

    public Task<RefreshToken?> GetByHashAsync(string tokenHash, CancellationToken cancellationToken) =>
        _dbContext.RefreshTokens
            .Include(x => x.User)
            .FirstOrDefaultAsync(x => x.TokenHash == tokenHash, cancellationToken);
}
