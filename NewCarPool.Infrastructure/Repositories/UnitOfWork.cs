using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Infrastructure.Data;

namespace NewCarPool.Infrastructure.Repositories;

public sealed class UnitOfWork : IUnitOfWork
{
    private readonly NewCarPoolDbContext _dbContext;

    public UnitOfWork(NewCarPoolDbContext dbContext) => _dbContext = dbContext;

    public Task<int> SaveChangesAsync(CancellationToken cancellationToken) =>
        _dbContext.SaveChangesAsync(cancellationToken);
}
