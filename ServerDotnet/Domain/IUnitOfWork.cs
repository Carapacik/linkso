using System.Threading.Tasks;

namespace Domain;

public interface IUnitOfWork
{
    Task Commit();
}