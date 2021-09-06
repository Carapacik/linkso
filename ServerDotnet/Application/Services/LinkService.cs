using System.Threading.Tasks;
using Application.Exceptions;
using Domain.Entities;
using Domain.Repositories;
using static Application.Exceptions.ExceptionList;

namespace Application.Services;

public class LinkService
{
    private readonly ILinkRepository _linkRepository;

    public LinkService(ILinkRepository linkRepository)
    {
        _linkRepository = linkRepository;
    }

    public async Task<Link> GetLinkInfo(string key)
    {
        var link = await _linkRepository.GetLink(key);
        if (link == null) throw new NotFoundException(LinkEx.NotFound);
        return link;
    }

    public async Task<string> GetLinkFullUrl(string key)
    {
        var link = await GetLinkInfo(key);

        if (link.LinkType == LinkType.Private)
            return $"/p/{link.Key}";
        return link.Target;
    }

    public async Task<string> AccessProtectedLink(string key, string password)
    {
        var link = await GetLinkInfo(key);

        if (link.LinkType == LinkType.Private)
        {
            if (string.IsNullOrWhiteSpace(password))
                throw new BadRequestException(LinkEx.InvalidPassword);

            if (password != link.Password)
                throw new ForbiddenException(LinkEx.WrongPassword);
        }

        return link.Target;
    }
}