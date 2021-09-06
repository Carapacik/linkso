using Domain.Entities;
using FluentValidation;

namespace WebApi.DTOs.Requests;

public class LinkCreateRequestDTO
{
    public string Target { get; set; }

    public LinkType LinkType { get; set; }

    public string Password { get; set; }
}

public class LinkCreateValidator : AbstractValidator<LinkCreateRequestDTO>
{
    public const int MaxTargetLength = 512;

    public LinkCreateValidator()
    {
        RuleFor(x => x.Target).MaximumLength(MaxTargetLength);
    }
}