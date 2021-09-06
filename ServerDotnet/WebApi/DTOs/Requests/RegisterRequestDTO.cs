using FluentValidation;
using static WebApi.Constants.UserCts;

namespace WebApi.DTOs.Requests;

public class RegisterRequestDTO
{
    public string Login { get; init; }

    public string Email { get; init; }

    public string Password { get; init; }
}

public class RegisterValidator : AbstractValidator<RegisterRequestDTO>
{
    public RegisterValidator()
    {
        RuleFor(x => x.Login).Length(MinLoginLength, MaxLoginLength)
            .Matches(LoginRegex);

        RuleFor(x => x.Email).EmailAddress();

        RuleFor(x => x.Password).Length(MinPasswordLength, MaxPasswordLength)
            .Matches(PasswordRegex);
    }
}