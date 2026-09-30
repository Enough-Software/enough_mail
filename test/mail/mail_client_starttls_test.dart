import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';

/// Minimal clear-text mock servers that do NOT offer STARTTLS.
///
/// Every command the client sends is recorded so the tests can prove that no
/// credentials were transmitted.
void main() {
  late ServerSocket server;
  final requests = <String>[];

  setUp(() async {
    requests.clear();
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  });

  tearDown(() => server.close());

  void serveImapWithoutStartTls() {
    server.listen((socket) {
      socket.write('* OK IMAP4rev1 server ready\r\n');
      socket.listen((data) {
        final line = String.fromCharCodes(data);
        requests.add(line);
        final tag = line.split(' ').first;
        if (line.contains(' CAPABILITY')) {
          socket.write(
            '* CAPABILITY IMAP4rev1 AUTH=PLAIN AUTH=LOGIN\r\n'
            '$tag OK done\r\n',
          );
        } else if (line.contains(' LOGIN ')) {
          socket.write('$tag OK [CAPABILITY IMAP4rev1] logged in\r\n');
        } else {
          socket.write('$tag OK done\r\n');
        }
      });
    });
  }

  void serveSmtpWithoutStartTls() {
    server.listen((socket) {
      socket.write('220 mock ESMTP\r\n');
      socket.listen((data) {
        final line = String.fromCharCodes(data);
        requests.add(line);
        if (line.startsWith('EHLO')) {
          socket.write('250-mock\r\n250-AUTH PLAIN LOGIN\r\n250 8BITMIME\r\n');
        } else if (line.startsWith('AUTH')) {
          socket.write('235 ok\r\n');
        } else {
          socket.write('250 ok\r\n');
        }
      });
    });
  }

  MailAccount account({
    required SocketType incoming,
    required SocketType outgoing,
  }) => MailAccount.fromManualSettings(
    name: 'test',
    email: 'user@example.com',
    password: 'secret',
    incomingHost: InternetAddress.loopbackIPv4.address,
    incomingPort: server.port,
    incomingSocketType: incoming,
    outgoingHost: InternetAddress.loopbackIPv4.address,
    outgoingPort: server.port,
    outgoingSocketType: outgoing,
  );

  test('IMAP: refuses clear-text login when STARTTLS is not offered', () async {
    serveImapWithoutStartTls();
    final client = MailClient(
      account(incoming: SocketType.starttls, outgoing: SocketType.ssl),
    );
    await expectLater(client.connect(), throwsA(isA<MailException>()));
    expect(requests.any((r) => r.contains('CAPABILITY')), isTrue);
    expect(requests.any((r) => r.contains('LOGIN')), isFalse);
  });

  test('IMAP: SocketType.plain also requires STARTTLS', () async {
    serveImapWithoutStartTls();
    final client = MailClient(
      account(incoming: SocketType.plain, outgoing: SocketType.ssl),
    );
    await expectLater(client.connect(), throwsA(isA<MailException>()));
    expect(requests.any((r) => r.contains('LOGIN')), isFalse);
  });

  test('IMAP: plainNoStartTls explicitly allows clear-text login', () async {
    serveImapWithoutStartTls();
    final client = MailClient(
      account(incoming: SocketType.plainNoStartTls, outgoing: SocketType.ssl),
    );
    await client.connect();
    expect(requests.any((r) => r.contains('LOGIN')), isTrue);
    await client.disconnect();
  });

  test('SMTP: refuses clear-text AUTH when STARTTLS is not offered', () async {
    serveSmtpWithoutStartTls();
    final client = MailClient(
      account(incoming: SocketType.ssl, outgoing: SocketType.starttls),
    );
    final message = MessageBuilder.buildSimpleTextMessage(
      const MailAddress('me', 'user@example.com'),
      [const MailAddress('you', 'other@example.com')],
      'hello',
    );
    await expectLater(
      client.sendMessage(message, appendToSent: false),
      throwsA(isA<MailException>()),
    );
    expect(requests.any((r) => r.startsWith('EHLO')), isTrue);
    expect(requests.any((r) => r.startsWith('AUTH')), isFalse);
  });
}
