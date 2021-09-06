using AutoMapper;
using Domain.Entities;
using WebApi.DTOs.Responses;

namespace WebApi.AutoMapper;

public class WebApiMappingProfile : Profile
{
    public WebApiMappingProfile()
    {
        CreateMap<Link, LinkInfoResponseDTO>();
        CreateMap<Link, LinkCreateResponseDTO>();
    }
}