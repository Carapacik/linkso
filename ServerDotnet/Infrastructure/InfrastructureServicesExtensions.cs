using Domain;
using Domain.Repositories;
using Infrastructure.Repositories;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Infrastructure;

public static class InfrastructureServicesExtensions
{
    public static void AddInfrastructureDependencies(this IServiceCollection services)
    {
        services.AddScoped<ILinkRepository, LinkRepository>();
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<IUnitOfWork, UnitOfWork>();
    }

    public static void AddDatabase(this IServiceCollection serviceCollection, string connectionString)
    {
        serviceCollection.AddDbContext<LinkSoDbContext>(options =>
            ConfigureDatabase(options, connectionString));
    }

    public static void ConfigureDatabase(this DbContextOptionsBuilder dbOptions, string connectionString)
    {
        dbOptions.UseNpgsql(connectionString, b =>
        {
            b.MigrationsAssembly("Migrations");
            b.UseQuerySplittingBehavior(QuerySplittingBehavior.SingleQuery);
        }).UseSnakeCaseNamingConvention();
    }
}