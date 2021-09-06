namespace Application.Tools.Permissions;

public class UserClaims
{
    public UserClaims(int userId)
    {
        UserId = userId;
    }

    public int UserId { get; }

    public bool IsAuthenticated => UserId != default;
}