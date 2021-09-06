namespace Application.Exceptions;

public static class ExceptionList
{
    internal static class LinkEx
    {
        // Bad Request
        public const string InvalidPassword = "Link.InvalidPassword";
        public const string InvalidTarget = "Link.InvalidTarget";
        public const string InvalidTargetEndPoint = "Link.InvalidTargetEndPoint";

        // Forbidden
        public const string WrongPassword = "Link.WrongPassword";

        // Not found
        public const string NotFound = "Link.NotFound";
    }

    internal static class UserEx
    {
        // Forbidden
        public const string TakenLogin = "User.TakenLogin";

        // Unathorized
        public const string NonExistingLogin = "User.NonExistingLogin";
        public const string WrongPassword = "User.WrongPassword.";
        public const string FailedValidation = "User.FailedValidation.";
    }
}