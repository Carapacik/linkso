using System.Text;
using Application.Services;
using Application.Tools.Common;
using Application.Tools.Jwt;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;

namespace Application;

public static class ApplicationServicesExtensions
{
    public static void AddAuthorization(this IServiceCollection services, IConfigurationSection commonSection,
        IConfigurationSection jwtSection)
    {
        services.Configure<CommonSettings>(commonSection);
        var commonSettings = new CommonSettings();
        commonSection.Bind(commonSettings);

        services.Configure<JwtSettings>(jwtSection);
        var jwtSettings = new JwtSettings();
        jwtSection.Bind(jwtSettings);

        services.AddAuthentication(opt =>
        {
            opt.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
            opt.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
        }).AddJwtBearer(options =>
        {
            options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidateAudience = true,
                ValidateLifetime = true,
                ValidateIssuerSigningKey = true,
                ValidIssuer = commonSettings.BackendAddress,
                ValidAudience = commonSettings.BackendAddress,
                IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSettings.SecurityKey))
            };
        });
    }

    public static void AddApplicationDependencies(this IServiceCollection services)
    {
        services.AddScoped<LinkGenerator>();
        services.AddScoped<JwtHandler>();

        services.AddScoped<UserService>();
        services.AddScoped<LinkManagerService>();
        services.AddScoped<LinkService>();
        services.AddScoped<UserService>();
    }
}