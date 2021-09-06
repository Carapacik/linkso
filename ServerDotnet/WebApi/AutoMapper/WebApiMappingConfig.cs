using AutoMapper;

namespace WebApi.AutoMapper;

internal static class WebApiMappingConfig
{
    public static IMapper CreateWebApiMapper()
    {
        var mappingConfig = new MapperConfiguration(cfg => { cfg.AddProfile<WebApiMappingProfile>(); });
        return mappingConfig.CreateMapper();
    }
}