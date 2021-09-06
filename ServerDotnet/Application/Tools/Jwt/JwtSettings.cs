namespace Application.Tools.Jwt;

public class JwtSettings
{
    public const string Name = "JwtSettings";

    public string SecurityKey { get; init; }

    public int ExpiryInMinutes { get; init; }
}