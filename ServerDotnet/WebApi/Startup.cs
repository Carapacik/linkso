using System;
using System.Linq;
using Application;
using Application.Tools.Common;
using Application.Tools.Jwt;
using FluentValidation.AspNetCore;
using Hellang.Middleware.SpaFallback;
using Infrastructure;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.OpenApi.Models;
using WebApi.AutoMapper;
using WebApi.ExceptionHandling;

namespace WebApi;

public class Startup
{
    public Startup(IConfiguration configuration)
    {
        Configuration = configuration;
    }

    public IConfiguration Configuration { get; }

    // This method gets called by t�����he runtime. Use this method to add services to the container.
    public void ConfigureServices(IServiceCollection services)
    {
        // Application
        services.AddAuthorization(Configuration.GetSection(CommonSettings.Name), Configuration.GetSection(JwtSettings.Name));
        services.AddApplicationDependencies();

        // Infrastructure
        services.AddDatabase(Configuration.GetConnectionString("DefaultConnection"));
        services.AddInfrastructureDependencies();

        // Web Api
        services.AddSingleton(WebApiMappingConfig.CreateWebApiMapper());
        services.AddLogging();
        services.AddSpaFallback();
        services.AddControllers();
        services.AddFluentValidation(x => { x.RegisterValidatorsFromAssemblyContaining<Startup>(); });
        services.Configure<ApiBehaviorOptions>(options =>
        {
            options.InvalidModelStateResponseFactory = actionContext =>
            {
                var errorDetails = new ValidationErrorDetails(actionContext.ModelState.Keys.ToArray());
                return new BadRequestObjectResult(errorDetails);
            };
        });

        services.AddSwaggerGen(c =>
        {
            c.SwaggerDoc("v1", new OpenApiInfo { Title = "LinkSo.WebApi", Version = "v1" });

            // Set the comments path for the Swagger JSON and UI.
            // var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
            // var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
            // c.IncludeXmlComments(xmlPath);

            var jwtSecurityScheme = new OpenApiSecurityScheme
            {
                Scheme = "bearer",
                BearerFormat = "JWT",
                Name = "JWT Authentication",
                In = ParameterLocation.Header,
                Type = SecuritySchemeType.Http,
                Description = "Put your Token below!",

                Reference = new OpenApiReference
                {
                    Id = JwtBearerDefaults.AuthenticationScheme,
                    Type = ReferenceType.SecurityScheme
                }
            };

            c.AddSecurityDefinition(jwtSecurityScheme.Reference.Id, jwtSecurityScheme);
            c.AddSecurityRequirement(new OpenApiSecurityRequirement
            {
                { jwtSecurityScheme, Array.Empty<string>() }
            });
        });

        services.AddCors();
    }

    // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
    public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
    {
        if (env.IsDevelopment())
        {
            app.UseDeveloperExceptionPage();
            app.UseSwagger(c =>
            {
                c.PreSerializeFilters.Add((document, _) =>
                {
                    var paths = document.Paths.ToDictionary(item => item.Key.ToLowerInvariant(),
                        item => item.Value);
                    document.Paths.Clear();
                    foreach (var (key, value) in paths) document.Paths.Add(key, value);
                });
            });
            app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "WebApi v1"));

            app.UseCors(builder => builder
                .AllowAnyMethod()
                .AllowAnyHeader()
                .AllowAnyOrigin());
        }

        app.UseMiddleware<ExceptionMiddleware>();

        app.UseRouting();
        app.UseAuthentication();
        app.UseAuthorization();

        app.UseEndpoints(endpoints =>
        {
            endpoints.MapControllers();
            endpoints.MapControllerRoute("redirect",
                $"/{{*key:length({Constants.LinkDefaultLength})}}",
                new { controller = "RedirectProcessor", action = "ProcessRedirect" });
        });

        app.UseSpaFallback();

        app.UseDefaultFiles();
        app.UseStaticFiles();
    }
}