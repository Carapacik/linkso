using System.Threading.Tasks;
using Domain.Entities;
using Domain.Repositories;
using Microsoft.EntityFrameworkCore;

namespace Infrastructure.Repositories;

public class UserRepository : IUserRepository
{
    private readonly LinkSoDbContext _linkSoDbContext;

    public UserRepository(LinkSoDbContext linkSoDbContext)
    {
        _linkSoDbContext = linkSoDbContext;
    }

    public async Task<User> AddUser(string login, string email, Password password)
    {
        var newUser = new User
        {
            Login = login,
            Email = email,
            Password = password
        };
        await _linkSoDbContext.Users.AddAsync(newUser);
        return newUser;
    }

    public async Task<User> GetUserByLogin(string login)
    {
        return await _linkSoDbContext.Users.FirstOrDefaultAsync(x => x.Login == login);
    }

    public async Task<User> GetUserById(int id)
    {
        return await _linkSoDbContext.Users.FindAsync(id);
    }
}