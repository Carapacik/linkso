using System;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Application.Exceptions;
using Application.Tools.Common;
using Application.Tools.Permissions;
using Domain;
using Domain.Entities;
using Domain.Repositories;
using Microsoft.Extensions.Options;
using static Application.Exceptions.ExceptionList;

namespace Application.Services;

public class LinkManagerService
{
    private readonly IOptions<CommonSettings> _commonSettings;
    private readonly LinkGenerator _linkGenerator;
    private readonly ILinkRepository _linkRepository;
    private readonly IUnitOfWork _unitOfWork;

    public LinkManagerService(IOptions<CommonSettings> commonSettings, ILinkRepository linkRepository, IUnitOfWork unitOfWork,
        LinkGenerator linkGenerator)
    {
        _commonSettings = commonSettings;
        _linkRepository = linkRepository;
        _unitOfWork = unitOfWork;
        _linkGenerator = linkGenerator;
    }


    public async Task<Link> CreateLink(string targetUrl, LinkType linkType, UserClaims userClaims,
        string password = null)
    {
        // Adds http:// if needed
        var uri = new UriBuilder(targetUrl).Uri;
        targetUrl = uri.ToString();

        if (!ValidateUrl(targetUrl))
            throw new BadRequestException(LinkEx.InvalidTarget);

        var backendUri = new Uri(_commonSettings.Value.BackendAddress);
        if (backendUri.Host == uri.Host)
            throw new BadRequestException(LinkEx.InvalidTargetEndPoint);

        if (linkType == LinkType.Private)
            if (string.IsNullOrWhiteSpace(password))
                throw new BadRequestException(LinkEx.InvalidPassword);

        var key = _linkGenerator.GenerateFullUrl();

        var addedLink = await _linkRepository.AddLink(key, targetUrl, linkType, userClaims.UserId, password);
        await _unitOfWork.Commit();
        return addedLink;
    }

    public async Task DeleteLink(string shortUrl, UserClaims userClaims)
    {
        await _linkRepository.DeleteLink(shortUrl);
        await _unitOfWork.Commit();
    }

    private static bool ValidateUrl(string url)
    {
        var pattern = @"^(http(s)?:\/\/.)?(www\.)?[-0-9\p{L}@:%._\+~#=]{0,256}\.[a-z]{0,6}\b([-0-9\p{L}@:%_\+.~#?&//=]*)$";
        Regex rgx = new(pattern, RegexOptions.Compiled | RegexOptions.IgnoreCase);
        return rgx.IsMatch(url);
    }
}