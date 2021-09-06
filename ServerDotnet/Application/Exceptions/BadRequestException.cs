namespace Application.Exceptions;

public class BadRequestException : ValueException
{
    public BadRequestException(string message) : base(message)
    {
    }
}