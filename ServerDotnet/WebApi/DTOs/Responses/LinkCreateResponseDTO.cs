using Domain.Entities;

namespace WebApi.DTOs.Responses;

public class LinkCreateResponseDTO
{
    public string Key { get; set; }

    public string Target { get; set; }

    public LinkType LinkType { get; set; }
}