using System;
using System.Security.Claims;

namespace Application.Tools.Permissions;

public static class PermissionsExtensions
{
    public static UserClaims GetClaims(this ClaimsPrincipal claimsPrincipal)
    {
        int userId = default;
        foreach (var claim in claimsPrincipal.Claims)
            switch (claim.Type)
            {
                case CustomClaimTypes.UserId:
                    userId = Convert.ToInt32(claim.Value);
                    break;
            }

        return new UserClaims(userId);
    }
}