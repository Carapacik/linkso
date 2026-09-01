import 'package:flutter_test/flutter_test.dart';
import 'package:linkso_client/src/features/shorten/domain/target_url_validator.dart';

void main() {
  group('validateTargetUrl', () {
    test('requires a non-empty value', () {
      expect(validateTargetUrl(''), TargetUrlValidationError.required);
      expect(validateTargetUrl('   '), TargetUrlValidationError.required);
    });

    test('accepts complete HTTP and HTTPS URLs', () {
      expect(validateTargetUrl('http://example.com'), isNull);
      expect(validateTargetUrl(' https://example.com/article?q=linkso '), isNull);
    });

    test('rejects incomplete URLs', () {
      expect(validateTargetUrl('example.com'), TargetUrlValidationError.invalid);
      expect(validateTargetUrl('https:///article'), TargetUrlValidationError.invalid);
    });

    test('rejects unsupported schemes', () {
      expect(validateTargetUrl('ftp://example.com/file'), TargetUrlValidationError.unsupportedScheme);
    });

    test('rejects values above the server limit', () {
      final oversizedUrl = 'https://example.com/${List<String>.filled(maximumTargetUrlLength, 'a').join()}';

      expect(validateTargetUrl(oversizedUrl), TargetUrlValidationError.tooLong);
    });
  });
}
