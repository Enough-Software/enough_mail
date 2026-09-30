import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/smtp/commands/smtp_send_bdat_command.dart';
import 'package:enough_mail/src/private/smtp/smtp_command.dart';
import 'package:test/test.dart';

void main() {
  group('removeBccHeader', () {
    test('removes a folded Bcc header', () {
      const message =
          'To: a@example.com\r\n'
          'Bcc: "Hidden One" <h1@example.com>,\r\n'
          '\t"Hidden Two" <h2@example.com>\r\n'
          'Subject: x\r\n'
          '\r\n'
          'body\r\n';
      expect(
        removeBccHeader(message),
        'To: a@example.com\r\nSubject: x\r\n\r\nbody\r\n',
      );
    });

    test('is case-insensitive', () {
      const message = 'bcc: h@example.com\r\nTo: a@example.com\r\n\r\nbody';
      expect(removeBccHeader(message), 'To: a@example.com\r\n\r\nbody');
    });

    test('removes a Bcc header that is the last header', () {
      const message = 'To: a@example.com\r\nBcc: h@example.com\r\n\r\nbody';
      expect(removeBccHeader(message), 'To: a@example.com\r\n\r\nbody');
    });

    test('leaves body lines starting with Bcc: untouched', () {
      const message =
          'To: a@example.com\r\n\r\n'
          'Bcc: keep this line\r\n'
          '  and this indented one\r\n';
      expect(removeBccHeader(message), message);
    });
  });

  test('BDAT path strips a folded Bcc header as well', () {
    final message =
        (MessageBuilder()
              ..from = const [MailAddress('Me', 'me@example.com')]
              ..to = const [MailAddress('You', 'you@example.com')]
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
    expect(message.renderMessage(), contains('\r\n\t'));
    final command = SmtpSendBdatMailCommand(
      message,
      null,
      message.recipientAddresses,
      use8BitEncoding: false,
      supportUnicode: false,
    );
    final data = command.getData();
    expect(data, isNot(contains('Bcc')));
    expect(data, isNot(contains('hidden.recipient')));
    expect(data, contains('To: "You" <you@example.com>\r\n'));
    expect(data, contains('Body'));
  });
}
