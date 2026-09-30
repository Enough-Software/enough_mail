import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tz.initializeTimeZones);

  group('DateCodec', () {
    test('renders half-hour zones west of Greenwich correctly', () {
      final date = tz.TZDateTime(
        tz.getLocation('America/St_Johns'),
        2022,
        1,
        7,
        22,
        18,
      );
      expect(DateCodec.encodeDate(date), 'Fri, 07 Jan 2022 22:18:00 -0330');
      final india = tz.TZDateTime(
        tz.getLocation('Asia/Kolkata'),
        2022,
        1,
        7,
        22,
        18,
      );
      expect(DateCodec.encodeDate(india), 'Fri, 07 Jan 2022 22:18:00 +0530');
    });

    test('applies the obsolete two and three digit year rules', () {
      expect(DateCodec.decodeDate('1 Jan 99 00:00:00 +0000')?.year, 1999);
      expect(DateCodec.decodeDate('1 Jan 49 00:00:00 +0000')?.year, 2049);
      expect(DateCodec.decodeDate('1 Jan 105 00:00:00 +0000')?.year, 2005);
      expect(DateCodec.decodeDate('1 Jan 99999999 00:00:00 +0000'), isNull);
    });
  });

  group('header encoding', () {
    test('Q encoding of names with astral characters is complete', () {
      const address = MailAddress('Bob 😀', 'b@example.com');
      final encoded = address.encode();
      expect(encoded, endsWith('?= <b@example.com>'));
      expect(MailAddress.parse(encoded).personalName, 'Bob 😀');
    });

    test('phrase encoded-words only contain the allowed characters', () {
      const name = 'Dr. Müller, Jr. (Vertrieb) <x>';
      final encoded = const MailAddress(name, 'm@example.com').encode();
      expect(
        encoded,
        '=?UTF-8?Q?Dr=2E_M=C3=BCller=2C_Jr=2E_=28Vertrieb=29_=3Cx=3E?= '
        '<m@example.com>',
      );
      final parsed = MailAddress.parse(encoded);
      expect(parsed.personalName, name);
      expect(parsed.email, 'm@example.com');
    });

    test('long phrases are split into several short encoded-words', () {
      final name = 'Ä' * 40;
      final encoded = MailAddress(name, 'l@example.com').encode();
      final words = encoded.substring(0, encoded.indexOf(' <')).split(' ');
      expect(words.length, greaterThan(1));
      for (final word in words) {
        expect(
          word,
          matches(RegExp(r'^=\?UTF-8\?Q\?[A-Za-z0-9!*+\-/=_]*\?=$')),
        );
        expect(word.length, lessThanOrEqualTo(75));
      }
      expect(MailAddress.parse(encoded).personalName, name);
    });

    test('ASCII names with specials stay quoted-strings', () {
      expect(
        const MailAddress('Doe, John', 'j@example.com').encode(),
        '"Doe, John" <j@example.com>',
      );
    });

    test('B encoding keeps surrounding text and astral characters', () {
      final encoded = MailCodec.base64.encodeHeader('a😀b', nameLength: 7);
      expect(encoded, isNot(contains('�')));
      expect(MailCodec.decodeHeader(encoded), 'a😀b');
    });

    test('folding never splits an encoded word', () {
      final message =
          (MessageBuilder()
                ..from = const [MailAddress('Me', 'me@example.com')]
                ..to = [
                  for (var i = 0; i < 4; i++)
                    MailAddress(
                      'Müller, Hans-Jürgen (Vertrieb $i)',
                      'hans.$i@example.com',
                    ),
                ]
                ..subject = 'x'
                ..addTextPlain('Body'))
              .buildMimeMessage();
      final rendered = message.renderMessage();
      final headerSection = rendered.substring(rendered.indexOf('\r\n\r\n'));
      for (final line
          in rendered
              .substring(0, rendered.length - headerSection.length)
              .split('\r\n')) {
        expect(
          '=?'.allMatches(line).length,
          '?='.allMatches(line).length,
          reason: 'encoded word split across lines in [$line]',
        );
      }
      expect(message.to?.length, 4);
      expect(message.to?.last.personalName, 'Müller, Hans-Jürgen (Vertrieb 3)');
    });
  });
}
