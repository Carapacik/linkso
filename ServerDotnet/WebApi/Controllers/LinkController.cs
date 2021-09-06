using System.Threading.Tasks;
using Application.Services;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using WebApi.DTOs.Requests;
using WebApi.DTOs.Responses;
using WebApi.ExceptionHandling;

namespace WebApi.Controllers;

[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class LinkController : ControllerBase
{
    private readonly LinkService _linkService;
    private readonly IMapper _mapper;

    public LinkController(LinkService linkService, IMapper mapper)
    {
        _linkService = linkService;
        _mapper = mapper;
    }

    [HttpPost("access")]
    [ProducesResponseType(typeof(string), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ErrorDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ErrorDetails), StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<string>> ProcessAccess([FromBody] LinkAccessRequest linkAccessRequest)
    {
        return await _linkService.AccessProtectedLink(linkAccessRequest.Key, linkAccessRequest.Password);
    }

    [HttpGet("info")]
    [ProducesResponseType(typeof(string), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorDetails), StatusCodes.Status404NotFound)]
    public async Task<ActionResult<LinkInfoResponseDTO>> GetLinkInfo([FromQuery] string key)
    {
        var link = await _linkService.GetLinkInfo(key);
        return _mapper.Map<LinkInfoResponseDTO>(link);
    }
}