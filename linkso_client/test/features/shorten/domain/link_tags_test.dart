import 'package:flutter_test/flutter_test.dart';
import 'package:linkso_client/src/features/shorten/domain/link_tags.dart';

void main() {
  test('normalizes and deduplicates comma-separated tags', () {
    expect(parseLinkTags(' Work, work, Product   Launch\nPersonal '), ['Work', 'Product Launch', 'Personal']);
  });

  test('validates tag length and distinct tag count', () {
    expect(validateLinkTags(List.filled(33, 'x').join()), LinkTagsValidationError.tooLong);
    expect(validateLinkTags(List.generate(11, (index) => 'tag $index').join(',')), LinkTagsValidationError.tooMany);
  });
}
