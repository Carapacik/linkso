using System.Threading.Tasks;
using Domain.Entities;

namespace Domain.Repositories;

public interface IUserRepository
{
    Task<User> AddUser(string login, string email, Password password);

    Task<User> GetUserByLogin(string login);

    Task<User> GetUserById(int id);
}