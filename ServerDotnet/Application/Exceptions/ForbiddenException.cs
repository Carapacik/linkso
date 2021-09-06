namespace Application.Exceptions;

public class ForbiddenException : ValueException
{
    public ForbiddenException(string message) : base(message)
    {
    }
}