using FluentValidation;
using static WebApi.Constants.LinkCts;

namespace WebApi.DTOs.Requests;

public class LinkAccessRequest
{
    public string Key { get; set; }

    public string Password { get; set; }
}

public class LinkAccessValidator : AbstractValidator<LinkAccessRequest>
{
    public LinkAccessValidator()
    {
        RuleFor(x => x.Key).Length(Constants.LinkDefaultLength);

        RuleFor(x => x.Password).Length(MinPasswordLength, MaxPasswordLength)
            .Matches(PasswordRegex);
    }
}