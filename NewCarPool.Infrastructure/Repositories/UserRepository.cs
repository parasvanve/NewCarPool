using Microsoft.EntityFrameworkCore;
using NewCarPool.Application.Interfaces.Repositories;
using NewCarPool.Domain.Entities;
using NewCarPool.Infrastructure.Data;

namespace NewCarPool.Infrastructure.Repositories;

public sealed class UserRepository : IUserRepository
{
    private readonly NewCarPoolDbContext _dbContext;

    public UserRepository(NewCarPoolDbContext dbContext) => _dbContext = dbContext;

    public Task<User?> GetByIdAsync(Guid id, CancellationToken cancellationToken) =>
        _dbContext.Users.FirstOrDefaultAsync(x => x.Id == id, cancellationToken);

    public Task<User?> GetByEmailAsync(string email, CancellationToken cancellationToken) =>
        _dbContext.Users.FirstOrDefaultAsync(x => x.Email == email, cancellationToken);

    public Task<bool> ExistsByEmailAsync(string email, CancellationToken cancellationToken) =>
        _dbContext.Users.AnyAsync(x => x.Email == email, cancellationToken);

    public async Task AddAsync(User user, CancellationToken cancellationToken) =>
        await _dbContext.Users.AddAsync(user, cancellationToken);
}
