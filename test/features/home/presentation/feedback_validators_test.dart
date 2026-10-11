import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/features/home/presentation/validators/feedback_validators.dart';

void main() {
  test('Title rejects whitespace and oversized text', () {
    expect(FeedbackValidators.title('   '), isNotNull);
    expect(FeedbackValidators.title('a' * 101), isNotNull);
    expect(FeedbackValidators.title('a' * 100), isNull);
  });
  test('Content enforces trimmed minimum and maximum', () {
    expect(FeedbackValidators.content('   '), isNotNull);
    expect(FeedbackValidators.content('  123456789  '), isNotNull);
    expect(FeedbackValidators.content(' 1234567890 '), isNull);
    expect(FeedbackValidators.content('a' * 1000), isNull);
    expect(FeedbackValidators.content('a' * 1001), isNotNull);
  });
}
