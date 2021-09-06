using System.Threading.Tasks;
using Domain;

namespace Infrastructure;

public class UnitOfWork : IUnitOfWork
{
    private readonly LinkSoDbContext _context;

    public UnitOfWork(LinkSoDbContext context)
    {
        _context = context;
    }

    public async Task Commit()
    {
        await _context.SaveChangesAsync();
    }
}