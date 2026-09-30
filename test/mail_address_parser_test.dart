import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/util/mail_address_parser.dart';
import 'package:test/test.dart';

void main() {
  group('MailAddressParser', () {
    test('resolves quoted-pairs in display names', () {
      final addresses = MailAddressParser.parseEmailAddresses(
        r'"Bob\" <attacker@evil.example>, \"x" <bob@example.com>',
      );
      expect(addresses, hasLength(1));
      expect(addresses.first.email, 'bob@example.com');
      expect(addresses.first.personalName, 'Bob" <attacker@evil.example>, "x');
    });

    test('handles characters outside the BMP in display names', () {
      final addresses = MailAddressParser.parseEmailAddresses(
        '"😀 Bob" <bob@example.com>, 🎉 <party@example.com>',
      );
      expect(addresses.map((a) => a.email), [
        'bob@example.com',
        'party@example.com',
      ]);
      expect(addresses.first.personalName, '😀 Bob');
    });

    test('keeps a trailing single-character part', () {
      final addresses = MailAddressParser.parseEmailAddresses('a@b.c, x@y.z');
      expect(addresses.map((a) => a.email), ['a@b.c', 'x@y.z']);
      expect(MailAddress.parse('a@b.c').email, 'a@b.c');
    });
  });
}
