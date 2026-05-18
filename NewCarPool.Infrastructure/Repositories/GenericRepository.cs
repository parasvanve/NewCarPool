using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;
using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Infrastructure.Data;

namespace NewCarPool.Infrastructure.Repositories;

public sealed class GenericRepository<TEntity> : IGenericRepository<TEntity> where TEntity : class
{
    private readonly NewCarPoolDbContext _dbContext;

    public GenericRepository(NewCarPoolDbContext dbContext) => _dbContext = dbContext;

    public IQueryable<TEntity> Query() => _dbContext.Set<TEntity>();

    public Task<TEntity?> GetByIdAsync(Guid id, CancellationToken cancellationToken) =>
        _dbContext.Set<TEntity>().FindAsync([id], cancellationToken).AsTask();

    public async Task<IReadOnlyList<TEntity>> ListAsync(Expression<Func<TEntity, bool>> predicate, CancellationToken cancellationToken) =>
        await _dbContext.Set<TEntity>().Where(predicate).ToListAsync(cancellationToken);

    public async Task AddAsync(TEntity entity, CancellationToken cancellationToken) =>
        await _dbContext.Set<TEntity>().AddAsync(entity, cancellationToken);

    public void Update(TEntity entity) => _dbContext.Set<TEntity>().Update(entity);

    public void Delete(TEntity entity) => _dbContext.Set<TEntity>().Remove(entity);
}
