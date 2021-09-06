namespace WebApi;

public static class Constants
{
    // Main
    public const int LinkDefaultLength = 8;

    // User contraints
    public static class UserCts
    {
        public const int MinLoginLength = 3;
        public const int MaxLoginLength = 20;

        public const int MinPasswordLength = 6;
        public const int MaxPasswordLength = 30;

        public const string LoginRegex = @"^[A-Za-z0-9_]+$";
        public const string PasswordRegex = @"^[\S]+$";
    }

    public static class LinkCts
    {
        public const int MinPasswordLength = 1;
        public const int MaxPasswordLength = 64;
        public const string PasswordRegex = @"^[\S]+$";
    }
}