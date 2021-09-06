using System.Threading.Tasks;
using Application.Services;
using Application.Tools.Permissions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using WebApi.DTOs.Requests;
using WebApi.ExceptionHandling;

namespace WebApi.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
[Produces("application/json")]
public class UserController : ControllerBase
{
    private readonly UserService _userService;

    public UserController(UserService userService)
    {
        _userService = userService;
    }

    /// <summary>
    ///     Register a new user account
    /// </summary>
    /// <param name="registerRequestDto"></param>
    /// <response code="200">Successfully registered</response>
    /// <response code="400">Invalid input data</response>
    /// <response code="403">Cannot register account with the specified data</response>
    /// <returns></returns>
    [HttpPost("register")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(string), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ValidationErrorDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ErrorDetails), StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<string>> Register([FromBody] RegisterRequestDTO registerRequestDto)
    {
        return await _userService.Register(registerRequestDto.Login, registerRequestDto.Email, registerRequestDto.Password);
    }

    /// <summary>
    ///     Log into an existing account
    /// </summary>
    /// <param name="loginRequestDto"></param>
    /// <response code="200">Successfully logged in</response>
    /// <response code="400">Invalid input data</response>
    /// <response code="401">Invalid credentials</response>
    /// <returns></returns>
    [HttpPost("login")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(string), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ValidationErrorDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ErrorDetails), StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<string>> Login([FromBody] LoginRequestDTO loginRequestDto)
    {
        return await _userService.Login(loginRequestDto.Login, loginRequestDto.Password);
    }

    [HttpGet("validateCredentials")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorDetails), StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> Validate()
    {
        await _userService.ValidateUser(HttpContext.User.GetClaims());
        return Ok();
    }
}