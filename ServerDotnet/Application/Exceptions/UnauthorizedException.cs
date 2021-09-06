namespace Application.Exceptions;

public class UnauthorizedException : ValueException
{
    public UnauthorizedException(string message) : base(message)
    {
    }
}