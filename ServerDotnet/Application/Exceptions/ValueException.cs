using System;

namespace Application.Exceptions;

public abstract class ValueException : Exception
{
    protected ValueException(string message) : base(message)
    {
        Value = message;
    }

    public string Value { get; }
}