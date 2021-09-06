using Domain.Entities;

namespace WebApi.DTOs.Responses;

public class LinkInfoResponseDTO
{
    public string Key { get; set; }

    public LinkType LinkType { get; set; }
}