using System.Text.Json;
using System.Text.Json.Serialization;

namespace WebApi.ExceptionHandling;

public class ErrorDetails
{
    public ErrorDetails(string message)
    {
        Message = message;
    }

    [JsonPropertyName("message")] public string Message { get; }

    public override string ToString()
    {
        return JsonSerializer.Serialize(this);
    }
}