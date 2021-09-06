using System;
using System.Security.Cryptography;
using Domain.Entities;
using Microsoft.AspNetCore.Cryptography.KeyDerivation;

namespace Application.Tools.Hash;

public static class HashingTools
{
    private const int Iterations = 10000;
    private const int BytesRequested = 256 / 8;

    public static bool ValidatePassword(string password, Password passwordEncrypted)
    {
        var hashedPassword = HashPassword(password, StringToSalt(passwordEncrypted.PasswordSalt));
        return passwordEncrypted.PasswordHash == hashedPassword;
    }

    public static Password QuickHash(string password)
    {
        var salt = GenerateSalt();
        var hash = HashPassword(password, salt);
        return new Password
        {
            PasswordHash = hash,
            PasswordSalt = SaltToString(salt)
        };
    }

    private static byte[] GenerateSalt()
    {
        var salt = new byte[128 / 8];
        using var rng = RandomNumberGenerator.Create();
        rng.GetBytes(salt);

        return salt;
    }

    private static string HashPassword(string password, byte[] salt)
    {
        return Convert.ToBase64String(KeyDerivation.Pbkdf2(password, salt,
            KeyDerivationPrf.HMACSHA1, Iterations, BytesRequested));
    }

    private static byte[] StringToSalt(string saltString)
    {
        return Convert.FromBase64String(saltString);
    }

    private static string SaltToString(byte[] salt)
    {
        return Convert.ToBase64String(salt);
    }
}