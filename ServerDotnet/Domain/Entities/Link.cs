namespace Domain.Entities;

public class Link
{
    public string Key { get; set; }

    public string Target { get; set; }

    public int? UserId { get; set; }

    public User User { get; set; }

    public string Password { get; set; }

    public LinkType LinkType { get; set; } = LinkType.Public;
}