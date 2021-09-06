using Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Infrastructure.Configurations;

public class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.ToTable("user");

        builder.OwnsOne(x => x.Password, password =>
        {
            password.Property(x => x.PasswordHash).HasColumnName("password_hash");
            password.Property(x => x.PasswordSalt).HasColumnName("password_salt");
        });

        builder.HasIndex(p => p.Login).IsUnique();
        builder.Property(x => x.Login).IsRequired().HasMaxLength(20);

        builder.Property(x => x.Email).IsRequired();


        builder.Property(x => x.RegisterDate).IsRequired();
    }
}