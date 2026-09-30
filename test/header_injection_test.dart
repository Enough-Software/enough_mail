import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/smtp/commands/smtp_sendmail_command.dart';
import 'package:enough_mail/src/private/smtp/smtp_command.dart';
import 'package:test/test.dart';

/// Returns the header section of the rendered [message], one header per
/// physical line, so tests can check which header names actually appear.
List<String> headerLines(MimeMessage message) {
  final rendered = message.renderMessage();
  final end = rendered.indexOf('\r\n\r\n');

  return rendered.substring(0, end).split('\r\n');
}

void main() {
  const from = MailAddress('Me', 'me@example.com');
  const to = MailAddress('You', 'you@example.com');

  group('header injection', () {
    test('line breaks in a subject cannot start another header', () {
      final message =
          (MessageBuilder()
                ..from = [from]
                ..to = [to]
                ..subject = 'Hi\r\nReply-To: attacker@evil.example'
                ..addTextPlain('Body'))
              .buildMimeMessage();
      final lines = headerLines(message);
      expect(lines.where((l) => l.startsWith('Reply-To:')), isEmpty);
      expect(message.decodeSubject(), 'Hi Reply-To: attacker@evil.example');
    });

    test('line breaks in a custom header value are neutralised', () {
      final message =
          (MessageBuilder()
                ..from = [from]
                ..to = [to]
                ..setHeader('X-Custom', 'a\nX-Injected: yes\r\n\r\nbody')
                ..addTextPlain('Body'))
              .buildMimeMessage();
      final lines = headerLines(message);
      expect(lines.where((l) => l.startsWith('X-Injected:')), isEmpty);
      expect(message.getHeaderValue('X-Custom'), 'a X-Injected: yes body');
    });

    test('line breaks in an attachment file name are neutralised', () {
      final message =
          (MessageBuilder()
                ..from = [from]
                ..to = [to]
                ..addBinary(
                  Uint8List.fromList([1, 2, 3]),
                  MediaSubtype.applicationOctetStream.mediaType,
                  filename: 'a.txt\r\nX-Injected: yes',
                ))
              .buildMimeMessage();
      expect(message.renderMessage(), isNot(contains('\r\nX-Injected:')));
    });

    test('quotes in a display name cannot add recipients', () {
      const evil = MailAddress(
        'Bob" <attacker@evil.example>, "x',
        'bob@example.com',
      );
      expect(
        evil.encode(),
        r'"Bob\" <attacker@evil.example>, \"x" <bob@example.com>',
      );
      final message =
          (MessageBuilder()
                ..from = [from]
                ..to = [evil]
                ..addTextPlain('Body'))
              .buildMimeMessage();
      expect(message.recipientAddresses, ['bob@example.com']);
    });

    test('non-ASCII display names become bare phrase encoded-words', () {
      const address = MailAddress(r'Jörg "JJ" \ Jung', 'jj@example.com');
      final encoded = address.encode();
      // RFC 2047 section 5: an encoded-word must not be inside a quoted-string
      expect(encoded, startsWith('=?UTF-8?Q?'));
      expect(encoded, endsWith('?= <jj@example.com>'));
      // quotes and backslashes are encoded, not emitted:
      expect(encoded, isNot(contains('"')));
      expect(encoded, isNot(contains(r'\')));
      expect(MailAddress.parse(encoded).personalName, r'Jörg "JJ" \ Jung');
    });

    test('an email address with unsafe characters cannot be encoded', () {
      expect(
        () => const MailAddress(null, 'a@b>\r\nRCPT TO:<c@d>').encode(),
        throwsArgumentError,
      );
      expect(
        () => const MailAddress(null, 'a@b,attacker@evil.example').encode(),
        throwsArgumentError,
      );
      expect(MailAddress.isSafeEmail('"john doe"@example.com'), isTrue);
      expect(MailAddress.isSafeEmail('john doe@example.com'), isFalse);
    });
  });

  group('SMTP envelope', () {
    test('rejects addresses that could break out of MAIL FROM / RCPT TO', () {
      expect(
        () => validateEnvelopeAddress('a@b>\r\nRCPT TO:<c@d>', 'r'),
        throwsArgumentError,
      );
      expect(
        () => validateEnvelopeAddress('a@b c@d', 'r'),
        throwsArgumentError,
      );
      expect(() => validateEnvelopeAddress(null, 'from'), throwsArgumentError);
      expect(validateEnvelopeAddress('ok@example.com', 'r'), 'ok@example.com');
    });

    test('send command refuses unsafe recipients and missing sender', () {
      expect(
        () => SmtpSendMailTextCommand(
          'x',
          const MailAddress(null, 'me@example.com'),
          ['ok@example.com', 'a@b>\r\nRCPT TO:<c@d>'],
          use8BitEncoding: false,
        ),
        throwsArgumentError,
      );
      final message =
          (MessageBuilder()
                ..to = [to]
                ..addTextPlain('x'))
              .buildMimeMessage();
      expect(
        () => SmtpSendMailCommand(
          message,
          null,
          message.recipientAddresses,
          use8BitEncoding: false,
        ),
        throwsArgumentError,
        reason: 'no From must not become MAIL FROM:<null>',
      );
    });

    test('mailto links cannot smuggle recipients', () {
      final mailto = Uri.parse(
        'mailto:victim@example.com%3E%0D%0ARCPT%20TO:%3Cattacker@evil.example'
        '?cc=ok@example.com,%20also@example.com',
      );
      final message = MessageBuilder.prepareMailtoBasedMessage(
        mailto,
        from,
      ).buildMimeMessage();
      expect(message.recipientAddresses, [
        'ok@example.com',
        'also@example.com',
      ]);
    });
  });
}
