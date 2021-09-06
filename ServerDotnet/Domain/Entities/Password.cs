namespace Domain.Entities;

public class Password
{
    public string PasswordHash { get; set; }
    public string PasswordSalt { get; set; }
}