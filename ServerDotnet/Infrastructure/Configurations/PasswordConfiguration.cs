using Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Infrastructure.Configurations;

public class PasswordConfiguration : IEntityTypeConfiguration<Password>
{
    public void Configure(EntityTypeBuilder<Password> builder)
    {
    }
}