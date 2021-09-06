using System.ComponentModel.DataAnnotations;
using System.Threading.Tasks;
using Application.Services;
using Application.Tools.Permissions;
using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using WebApi.DTOs.Requests;
using WebApi.DTOs.Responses;
using WebApi.ExceptionHandling;

namespace WebApi.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
[Produces("application/json")]
public class LinkManagerController : ControllerBase
{
    private readonly LinkManagerService _linkManagerService;
    private readonly IMapper _mapper;

    public LinkManagerController(LinkManagerService linkManagerService, IMapper mapper)
    {
        _linkManagerService = linkManagerService;
        _mapper = mapper;
    }

    [HttpPost("create")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(string), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorDetails), StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<LinkCreateResponseDTO>> CreateLink([FromBody] LinkCreateRequestDTO linkCreateRequestDto)
    {
        var createdLink = await _linkManagerService.CreateLink(linkCreateRequestDto.Target,
            linkCreateRequestDto.LinkType, HttpContext.User.GetClaims(), linkCreateRequestDto.Password);

        return _mapper.Map<LinkCreateResponseDTO>(createdLink);
    }

    [HttpDelete("delete")]
    [ProducesResponseType(typeof(string), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ErrorDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ErrorDetails), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> DeleteLink([FromQuery] [Required] string key)
    {
        await _linkManagerService.DeleteLink(key, HttpContext.User.GetClaims());
        return Ok();
    }
}