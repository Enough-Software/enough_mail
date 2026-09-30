import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';

/// A clear-text mock SMTP server that accepts any login and records requests.
void main() {
  late ServerSocket server;
  final requests = <String>[];

  setUp(() async {
    requests.clear();
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0)
      ..listen((socket) {
        socket.write('220 mock ESMTP\r\n');
        socket.listen((data) {
          final line = String.fromCharCodes(data);
          requests.add(line);
          if (line.startsWith('EHLO')) {
            socket.write('250-mock\r\n250-AUTH PLAIN\r\n250 8BITMIME\r\n');
          } else if (line.startsWith('AUTH')) {
            socket.write('235 ok\r\n');
          } else {
            socket.write('250 ok\r\n');
          }
        });
      });
  });

  tearDown(() => server.close());

  MailClient mailClient() => MailClient(
    MailAccount.fromManualSettings(
      name: 'test',
      email: 'user@example.com',
      password: 'secret',
      incomingHost: 'imap.invalid',
      outgoingHost: InternetAddress.loopbackIPv4.address,
      outgoingPort: server.port,
      outgoingSocketType: SocketType.plainNoStartTls,
    ),
  );

  MimeMessage message() =>
      (MessageBuilder()
            ..from = const [MailAddress('Me', 'me@example.com')]
            ..to = const [MailAddress('A', 'a@example.com')]
            ..subject = 'Hello'
            ..addTextPlain('Body'))
          .buildMimeMessage();

  test('an invalid envelope is reported as MailException', () async {
    final client = mailClient();
    await expectLater(
      client.sendMessage(
        message(),
        from: const MailAddress(null, 'me @example.com'),
        appendToSent: false,
      ),
      throwsA(isA<MailException>()),
    );
    await expectLater(
      client.sendMessage(
        message(),
        recipients: const [MailAddress(null, 'a>b@example.com')],
        appendToSent: false,
      ),
      throwsA(isA<MailException>()),
    );
    // the connection was established, but no transaction was started:
    expect(requests.any((r) => r.startsWith('EHLO')), isTrue);
    expect(requests.any((r) => r.startsWith('MAIL FROM')), isFalse);
    await client.disconnect();
  });
}
