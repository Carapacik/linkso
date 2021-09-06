namespace Application.Exceptions;

public class NotFoundException : ValueException
{
    public NotFoundException(string message) : base(message)
    {
    }
}