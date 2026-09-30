import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/smtp/commands/smtp_send_bdat_command.dart';
import 'package:enough_mail/src/private/smtp/commands/smtp_sendmail_command.dart';
import 'package:enough_mail/src/private/smtp/smtp_command.dart';
import 'package:test/test.dart';

SmtpResponse _reply(String line) => SmtpResponse([line]);

MimeMessage _message() =>
    (MessageBuilder()
          ..from = const [MailAddress('Me', 'me@example.com')]
          ..to = const [
            MailAddress('A', 'a@example.com'),
            MailAddress('B', 'b@example.com'),
          ]
          ..subject = 'Hello'
          ..addTextPlain('Body'))
        .buildMimeMessage();

void main() {
  group('SmtpSendMailCommand state machine', () {
    test('fails when MAIL FROM is rejected', () {
      final command = SmtpSendMailCommand(_message(), null, [
        'a@example.com',
      ], use8BitEncoding: false);
      final rejection = _reply('550 5.1.8 sender rejected');
      expect(command.nextCommand(rejection), isNull);
      expect(command.isCommandDone(rejection), isTrue);
      expect(command.failureResponse, isNull);
    });

    test('resets the transaction when a recipient is rejected', () {
      final message = _message();
      final command = SmtpSendMailCommand(
        message,
        null,
        message.recipientAddresses,
        use8BitEncoding: false,
      );
      expect(command.nextCommand(_reply('250 ok')), 'RCPT TO:<a@example.com>');
      expect(
        command.nextCommand(_reply('550 5.1.1 unknown user')),
        'RCPT TO:<b@example.com>',
      );
      expect(command.nextCommand(_reply('250 ok')), 'RSET');
      final resetReply = _reply('250 flushed');
      expect(command.nextCommand(resetReply), isNull);
      expect(command.isCommandDone(resetReply), isTrue);
      expect(command.failureResponse?.code, 550);
    });

    test('does not send the payload when DATA is refused', () {
      final command = SmtpSendMailCommand(_message(), null, [
        'a@example.com',
      ], use8BitEncoding: false);
      expect(command.nextCommand(_reply('250 ok')), 'RCPT TO:<a@example.com>');
      expect(command.nextCommand(_reply('250 ok')), 'DATA');
      expect(command.nextCommand(_reply('451 4.3.0 try later')), 'RSET');
      expect(command.failureResponse?.code, 451);
      expect(command.isCommandDone(_reply('250 ok')), isTrue);
    });

    test('completes after the payload was accepted', () {
      final command =
          SmtpSendMailCommand(_message(), null, [
              'a@example.com',
            ], use8BitEncoding: false)
            ..nextCommand(_reply('250 ok'))
            ..nextCommand(_reply('250 ok'));
      final payload = command.nextCommand(_reply('354 go'));
      expect(payload, endsWith('\r\n.'));
      final accepted = _reply('250 queued');
      expect(command.nextCommand(accepted), isNull);
      expect(command.isCommandDone(accepted), isTrue);
      expect(command.failureResponse, isNull);
    });
  });

  group('SmtpSendBdatMailCommand state machine', () {
    test('sends SMTPUTF8 together with BODY=8BITMIME', () {
      final command = SmtpSendBdatMailCommand(
        _message(),
        null,
        ['a@example.com'],
        use8BitEncoding: true,
        supportUnicode: true,
      );
      expect(
        command.command,
        'MAIL FROM:<me@example.com> BODY=8BITMIME SMTPUTF8',
      );
    });

    test('resets the transaction when a chunk is rejected', () {
      // more than one 512 KiB chunk:
      final command = SmtpSendBdatMailTextCommand(
        'x' * (600 * 1024),
        const MailAddress(null, 'me@example.com'),
        ['a@example.com'],
        use8BitEncoding: false,
        supportUnicode: false,
      );
      expect(command.next(_reply('250 ok'))?.text, 'RCPT TO:<a@example.com>');
      expect(command.next(_reply('250 ok'))?.data, isNotNull);
      expect(command.next(_reply('554 5.6.0 rejected'))?.text, 'RSET');
      expect(command.failureResponse?.code, 554);
      expect(command.isCommandDone(_reply('250 ok')), isTrue);
    });

    test('a rejected last chunk fails the command directly', () {
      final command =
          SmtpSendBdatMailCommand(
              _message(),
              null,
              ['a@example.com'],
              use8BitEncoding: false,
              supportUnicode: false,
            )
            ..next(_reply('250 ok'))
            ..next(_reply('250 ok'));
      final rejection = _reply('554 5.6.0 rejected');
      expect(command.next(rejection), isNull);
      expect(command.isCommandDone(rejection), isTrue);
    });
  });

  group('envelope validation', () {
    final client = SmtpClient('test.example.com');
    const recipients = [MailAddress(null, 'a@example.com')];

    test('a missing sender is reported as SmtpException', () {
      final message = MimeMessage();
      expect(message.fromEmail, isNull);
      final matcher = throwsA(
        isA<SmtpException>().having(
          (e) => e.message,
          'message',
          contains('sender'),
        ),
      );
      expect(
        () => client.sendMessage(message, recipients: recipients),
        matcher,
      );
      expect(
        () => client.sendChunkedMessage(
          message,
          recipients: recipients,
          supportUnicode: false,
        ),
        matcher,
      );
    });

    test('unsafe envelope addresses are reported as SmtpException', () {
      const from = MailAddress(null, 'me@example.com');
      const unsafeFrom = MailAddress(null, 'me @example.com');
      const unsafeRecipients = [MailAddress(null, 'a>b@example.com')];
      final matcher = throwsA(isA<SmtpException>());
      expect(() => client.sendMessage(_message(), from: unsafeFrom), matcher);
      expect(
        () => client.sendMessageText('x', from, unsafeRecipients),
        matcher,
      );
      expect(
        () => client.sendChunkedMessageText(
          'x',
          unsafeFrom,
          recipients,
          supportUnicode: false,
        ),
        matcher,
      );
    });
  });

  test('sendMessage fails with the rejection and resets the session', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <String>[];
    server.listen((socket) {
      socket.write('220 mock ESMTP\r\n');
      socket.listen((data) {
        final request = String.fromCharCodes(data);
        requests.add(request);
        if (request.startsWith('EHLO')) {
          socket.write('250 mock\r\n');
        } else if (request.startsWith('RCPT TO:<b@')) {
          socket.write('550 5.1.1 no such user\r\n');
        } else if (request.startsWith('DATA')) {
          socket.write('354 go\r\n');
        } else {
          socket.write('250 ok\r\n');
        }
      });
    });
    final client = SmtpClient('test.example.com');
    await client.connectToServer(
      server.address.address,
      server.port,
      isSecure: false,
    );
    await client.ehlo();
    await expectLater(
      client.sendMessage(_message()),
      throwsA(isA<SmtpException>().having((e) => e.response.code, 'code', 550)),
    );
    expect(requests.any((r) => r.startsWith('RSET')), isTrue);
    expect(requests.any((r) => r.startsWith('DATA')), isFalse);
    // the connection is still usable:
    final noop = await client.sendCommand(SmtpCommand('NOOP'));
    expect(noop.code, 250);
    await client.disconnect();
    await server.close();
  });
}
