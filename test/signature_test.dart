import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/platform/signature_info.dart';

void main() {
  final now = DateTime.utc(2026, 11, 12, 12, 0);

  SignatureMessage? at(Duration remaining) => signatureMessage(now.add(remaining), now);

  test('says nothing when the expiry is not known', () {
    expect(signatureMessage(null, now), isNull);
  });

  group('plenty of time', () {
    test('7 days, counted down', () {
      final message = at(const Duration(days: 7))!;
      expect(message.text, 'Signature: 7 days left');
      expect(message.warning, isFalse);
    });

    test('6 days and 2 hours is still "6 days", never rounded up', () {
      expect(at(const Duration(days: 6, hours: 2))!.text, 'Signature: 6 days left');
    });

    test('3 days is the last calm message', () {
      final message = at(const Duration(days: 3, hours: 1))!;
      expect(message.text, 'Signature: 3 days left');
      expect(message.warning, isFalse);
    });
  });

  group('close to expiring', () {
    test('2 days left is a warning', () {
      final message = at(const Duration(days: 2, hours: 5))!;
      expect(message.text, startsWith('Signature: 2 days left'));
      expect(message.warning, isTrue);
    });

    test('1 day left uses the singular and is a warning', () {
      final message = at(const Duration(days: 1, hours: 3))!;
      expect(message.text, startsWith('Signature: 1 day left'));
      expect(message.warning, isTrue);
    });

    test('under a day says it expires today', () {
      final message = at(const Duration(hours: 5))!;
      expect(message.text, startsWith('Signature expires today'));
      expect(message.warning, isTrue);
    });

    test('the warnings tell the person what to do', () {
      for (final remaining in [const Duration(days: 2), const Duration(days: 1), const Duration(hours: 1)]) {
        expect(at(remaining)!.text, contains('AltStore'));
      }
    });
  });

  group('too late', () {
    test('at the moment of expiry', () {
      final message = at(Duration.zero)!;
      expect(message.text, startsWith('Signature expired'));
      expect(message.warning, isTrue);
    });

    test('after it', () {
      expect(at(const Duration(days: -3))!.text, startsWith('Signature expired'));
    });
  });
}
