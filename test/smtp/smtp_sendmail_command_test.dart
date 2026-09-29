import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/smtp/commands/smtp_sendmail_command.dart';
import 'package:test/test.dart';

void main() {
  group('SmtpSendMailCommand', () {
    test('strips a Bcc header that was folded onto continuation lines', () {
      final message =
          (MessageBuilder()
                ..from = const [MailAddress('Me', 'me@example.com')]
                ..to = const [MailAddress('You', 'you@example.com')]
                ..cc = const [MailAddress('Carol', 'carol@example.com')]
                ..bcc = [
                  for (var i = 0; i < 6; i++)
                    MailAddress(
                      'Hidden Recipient Number $i',
                      'hidden.recipient.$i@example.com',
                    ),
                ]
                ..subject = 'Hello'
                ..addTextPlain('Body'))
              .buildMimeMessage();
      final rendered = message.renderMessage();
      expect(
        rendered,
        contains('\r\n\t'),
        reason: 'the fixture must actually fold the Bcc header',
      );

      final command = SmtpSendMailCommand(
        message,
        null,
        message.recipientAddresses,
        use8BitEncoding: false,
      );
      final data = command.getData();

      expect(data, isNot(contains('Bcc')));
      expect(data, isNot(contains('hidden.recipient')));
      expect(data, isNot(contains('\r\n\t')));
      expect(data, contains('To: "You" <you@example.com>\r\n'));
      expect(data, contains('Cc: "Carol" <carol@example.com>\r\n'));
      expect(data, contains('Subject: Hello\r\n'));
      expect(data, contains('Body'));
    });

    test('keeps every recipient in the envelope', () {
      final message =
          (MessageBuilder()
                ..from = const [MailAddress('Me', 'me@example.com')]
                ..to = const [MailAddress('You', 'you@example.com')]
                ..bcc = const [MailAddress('Hidden', 'hidden@example.com')]
                ..subject = 'Hello'
                ..addTextPlain('Body'))
              .buildMimeMessage();

      expect(message.recipientAddresses, [
        'you@example.com',
        'hidden@example.com',
      ]);
    });
  });
}
