import 'package:flutter_test/flutter_test.dart';
import 'package:linkso_client/src/features/shorten/domain/shorten_form_validator.dart';

void main() {
  group('title validation', () {
    test('allows empty and bounded titles', () {
      expect(validateLinkTitle(''), isNull);
      expect(validateLinkTitle(_repeat('A', maximumLinkTitleLength)), isNull);
    });

    test('rejects a title above 120 characters', () {
      expect(validateLinkTitle(_repeat('A', maximumLinkTitleLength + 1)), TitleValidationError.tooLong);
    });
  });

  group('custom slug validation', () {
    test('allows an empty or valid custom slug', () {
      expect(validateCustomSlug(''), isNull);
      expect(validateCustomSlug(' Team_link-42 '), isNull);
    });

    test('matches server length, character and reserved rules', () {
      expect(validateCustomSlug('ab'), SlugValidationError.tooShort);
      expect(validateCustomSlug(_repeat('a', maximumCustomSlugLength + 1)), SlugValidationError.tooLong);
      expect(validateCustomSlug('-team'), SlugValidationError.invalidFormat);
      expect(validateCustomSlug('team.'), SlugValidationError.invalidFormat);
      expect(validateCustomSlug('API'), SlugValidationError.reserved);
    });
  });

  group('password validation', () {
    test('requires 8 to 128 characters', () {
      expect(validateLinkPassword(''), PasswordValidationError.required);
      expect(validateLinkPassword('short'), PasswordValidationError.tooShort);
      expect(validateLinkPassword(_repeat('A', minimumLinkPasswordLength)), isNull);
      expect(validateLinkPassword(_repeat('A', maximumLinkPasswordLength + 1)), PasswordValidationError.tooLong);
    });
  });

  group('expiration validation', () {
    test('allows no expiration or a future value', () {
      final now = DateTime(2026, 8, 28, 12);
      expect(validateExpiration(null, now), isNull);
      expect(validateExpiration(now.add(const Duration(minutes: 1)), now), isNull);
    });

    test('rejects current and past values', () {
      final now = DateTime(2026, 8, 28, 12);
      expect(validateExpiration(now, now), ExpirationValidationError.notFuture);
      expect(validateExpiration(now.subtract(const Duration(seconds: 1)), now), ExpirationValidationError.notFuture);
    });
  });
}

String _repeat(String value, int count) => List<String>.filled(count, value).join();
