using System.Threading.Tasks;
using Domain.Entities;
using Domain.Repositories;
using Microsoft.EntityFrameworkCore;

namespace Infrastructure.Repositories;

public class LinkRepository : ILinkRepository
{
    private readonly LinkSoDbContext _linkSoDbContext;

    public LinkRepository(LinkSoDbContext linkSoDbContext)
    {
        _linkSoDbContext = linkSoDbContext;
    }

    public async Task<Link> AddLink(string key, string target, LinkType linkType, int authorId,
        string password)
    {
        var newLink = new Link
        {
            Key = key,
            Target = target,
            LinkType = linkType,
            Password = password,
            UserId = authorId == 0 ? null : authorId
        };

        await _linkSoDbContext.Links.AddAsync(newLink);
        return newLink;
    }

    public async Task<Link> GetLink(string key)
    {
        return await _linkSoDbContext.Links.FirstOrDefaultAsync(x => x.Key == key);
    }

    public async Task DeleteLink(string key)
    {
        var link = await _linkSoDbContext.Links.FirstOrDefaultAsync(x => x.Key == key);
        if (link != null) _linkSoDbContext.Links.Remove(link);
    }
}