import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/services/user_agent.dart';

void main() {
  group('parseCustomUserAgent', () {
    test('blank means the app default', () {
      expect(parseCustomUserAgent(null), isNull);
      expect(parseCustomUserAgent('   '), isNull);
    });

    test('a normal string passes, trimmed', () {
      expect(parseCustomUserAgent('  VLC/3.0.20 LibVLC/3.0.20 '),
          'VLC/3.0.20 LibVLC/3.0.20');
    });

    test('line breaks, control and non-ASCII characters are refused', () {
      expect(() => parseCustomUserAgent('a\nb: c'), throwsFormatException);
      expect(() => parseCustomUserAgent('a\u0000b'), throwsFormatException);
      expect(() => parseCustomUserAgent('café'), throwsFormatException);
    });

    test('too long is refused', () {
      expect(() => parseCustomUserAgent('x' * 201), throwsFormatException);
      expect(parseCustomUserAgent('x' * 200), 'x' * 200);
    });
  });
}
