import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/smtp/commands/smtp_sendmail_command.dart';
import 'package:enough_mail/src/private/smtp/smtp_command.dart';
import 'package:test/test.dart';

/// Drives a DATA command through MAIL FROM / RCPT TO / DATA and returns the
/// payload that would be written to the socket after the `354` reply.
String transmit(SmtpCommand command) {
  var next = command.nextCommand(SmtpResponse(['250 ok']));
  while (next != null && next.startsWith('RCPT TO:')) {
    next = command.nextCommand(SmtpResponse(['250 ok']));
  }
  expect(next, 'DATA');

  return command.nextCommand(SmtpResponse(['354 go ahead']))!;
}

void main() {
  group('applySmtpTransparency', () {
    test('stuffs every line starting with a period', () {
      expect(
        applySmtpTransparency('a\r\n.\r\n.\r\n.NET rocks\r\nb\r\n'),
        'a\r\n..\r\n..\r\n..NET rocks\r\nb\r\n.',
      );
    });

    test('stuffs a leading period on the very first line', () {
      expect(applySmtpTransparency('.hidden\r\n'), '..hidden\r\n.');
    });

    test('terminates data that does not end with CRLF', () {
      expect(applySmtpTransparency('body'), 'body\r\n.');
      expect(applySmtpTransparency('body\r\n.'), 'body\r\n..\r\n.');
    });

    test('does not add an empty line when data already ends with CRLF', () {
      expect(applySmtpTransparency('body\r\n'), 'body\r\n.');
    });
  });

  group('SmtpSendMailTextCommand', () {
    test('body cannot terminate DATA early or inject commands', () {
      const from = MailAddress(null, 'me@example.com');
      const to = MailAddress(null, 'you@example.com');
      const body =
          'Subject: hi\r\n\r\n'
          'hello\r\n.\r\n.\r\n'
          'MAIL FROM:<spam@evil.example>\r\n'
          'RCPT TO:<victim@example.com>\r\n'
          'DATA\r\nspam\r\n.\r\n.\r\n';
      final command = SmtpSendMailTextCommand(body, from, [
        to.email,
      ], use8BitEncoding: false);
      final payload = transmit(command);
      // the end-of-data marker is completed by the CRLF the client appends
      final onWire = '$payload\r\n';
      final terminator = onWire.indexOf('\r\n.\r\n');
      expect(
        terminator,
        onWire.length - '\r\n.\r\n'.length,
        reason: 'the only CRLF.CRLF must be the final terminator',
      );
      expect(onWire, contains('\r\n..\r\n..\r\nMAIL FROM'));
    });
  });
}
