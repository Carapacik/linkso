using FluentValidation;
using static WebApi.Constants.UserCts;

namespace WebApi.DTOs.Requests;

public class LoginRequestDTO
{
    public string Login { get; init; }

    public string Password { get; init; }
}

public class LoginValidator : AbstractValidator<LoginRequestDTO>
{
    public LoginValidator()
    {
        RuleFor(x => x.Login).Length(MinLoginLength, MaxLoginLength)
            .Matches(LoginRegex);

        RuleFor(x => x.Password).Length(MinPasswordLength, MaxPasswordLength)
            .Matches(PasswordRegex);
    }
}