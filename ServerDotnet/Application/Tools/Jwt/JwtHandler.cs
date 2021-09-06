using System;
using System.Collections.Generic;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Application.Tools.Common;
using Application.Tools.Permissions;
using Domain.Entities;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace Application.Tools.Jwt;

public class JwtHandler
{
    private readonly IOptions<CommonSettings> _commonSettings;
    private readonly IOptions<JwtSettings> _jwtSettings;

    public JwtHandler(IOptions<JwtSettings> jwtSettings, IOptions<CommonSettings> commonSettings)
    {
        _jwtSettings = jwtSettings;
        _commonSettings = commonSettings;
    }

    public JwtSecurityToken GenerateTokenOptions(User user)
    {
        var tokenOptions = new JwtSecurityToken(
            _commonSettings.Value.BackendAddress,
            _commonSettings.Value.BackendAddress,
            GetClaims(user),
            expires: DateTime.Now.AddMinutes(Convert.ToDouble(_jwtSettings.Value.ExpiryInMinutes)),
            signingCredentials: GetSigningCredentials());
        return tokenOptions;
    }

    private SigningCredentials GetSigningCredentials()
    {
        var key = Encoding.UTF8.GetBytes(_jwtSettings.Value.SecurityKey);
        var secret = new SymmetricSecurityKey(key);
        return new SigningCredentials(secret, SecurityAlgorithms.HmacSha256);
    }

    private static IEnumerable<Claim> GetClaims(User user)
    {
        var claims = new List<Claim>
        {
            new(CustomClaimTypes.UserId, user.Id.ToString())
        };

        return claims;
    }
}