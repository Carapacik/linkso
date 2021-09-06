using System.IdentityModel.Tokens.Jwt;
using System.Threading.Tasks;
using Application.Exceptions;
using Application.Tools.Hash;
using Application.Tools.Jwt;
using Application.Tools.Permissions;
using Domain;
using Domain.Repositories;
using static Application.Exceptions.ExceptionList;

namespace Application.Services;

public class UserService
{
    private readonly JwtHandler _jwtHandler;
    private readonly IUnitOfWork _unitOfWork;
    private readonly IUserRepository _userRepository;

    public UserService(IUserRepository userRepository, IUnitOfWork unitOfWork, JwtHandler jwtHandler)
    {
        _userRepository = userRepository;
        _unitOfWork = unitOfWork;
        _jwtHandler = jwtHandler;
    }

    public async Task<string> Register(string login, string email, string password)
    {
        if (await _userRepository.GetUserByLogin(login) != null)
            throw new ForbiddenException(UserEx.TakenLogin);

        var generatedPassword = HashingTools.QuickHash(password);
        var user = await _userRepository.AddUser(login, email, generatedPassword);
        await _unitOfWork.Commit();

        return new JwtSecurityTokenHandler().WriteToken(_jwtHandler.GenerateTokenOptions(user));
    }

    public async Task<string> Login(string login, string password)
    {
        var user = await _userRepository.GetUserByLogin(login);
        if (user == null)
            throw new UnauthorizedException(UserEx.NonExistingLogin);

        if (!HashingTools.ValidatePassword(password, user.Password))
            throw new UnauthorizedException(UserEx.WrongPassword);

        return new JwtSecurityTokenHandler().WriteToken(_jwtHandler.GenerateTokenOptions(user));
    }

    public async Task ValidateUser(UserClaims userClaims)
    {
        if (!userClaims.IsAuthenticated)
            throw new UnauthorizedException(UserEx.FailedValidation);

        var dbUser = await _userRepository.GetUserById(userClaims.UserId);
        if (dbUser == null)
            throw new UnauthorizedException(UserEx.FailedValidation);
    }
}