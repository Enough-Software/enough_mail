import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';

void main() {
  late ServerSocket server;

  setUp(() async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  });

  tearDown(() => server.close());

  Future<SmtpClient> connect() async {
    final client = SmtpClient('test.example.com');
    await client.connectToServer(
      server.address.address,
      server.port,
      isSecure: false,
    );

    return client;
  }

  test('multi-line EHLO reply split across chunks', () async {
    server.listen((socket) {
      socket.write('220 mock ESMTP\r\n');
      socket.listen((_) async {
        socket.write('250-mock\r\n250-SIZE 1000\r\n');
        await socket.flush();
        await Future.delayed(const Duration(milliseconds: 100));
        socket.write('250-AUTH PLAIN\r\n250 8BITMIME\r\n');
      });
    });
    final client = await connect();
    final response = await client.ehlo();
    expect(response.responseLines, hasLength(4));
    expect(client.serverInfo.maxMessageSize, 1000);
    expect(client.serverInfo.supportsAuth(AuthMechanism.plain), isTrue);
    expect(client.serverInfo.supports8BitMime, isTrue);
    await client.disconnect();
  });

  test('single-line EHLO reply completes', () async {
    server.listen((socket) {
      socket.write('220 mock ESMTP\r\n');
      socket.listen((_) => socket.write('250 mock\r\n'));
    });
    final client = await connect();
    final response = await client.ehlo();
    expect(response.code, 250);
    expect(client.serverInfo.capabilities, ['mock']);
    await client.disconnect();
  });

  test('EHLO after STARTTLS replaces the capabilities', () async {
    server.listen((socket) {
      var count = 0;
      socket.write('220 mock ESMTP\r\n');
      socket.listen((_) {
        count++;
        socket.write(
          count == 1
              ? '250-mock\r\n250-STARTTLS\r\n250 AUTH LOGIN\r\n'
              : '250-mock\r\n250 AUTH PLAIN\r\n',
        );
      });
    });
    final client = await connect();
    await client.ehlo();
    expect(client.serverInfo.supportsStartTls, isTrue);
    await client.ehlo();
    expect(client.serverInfo.supportsStartTls, isFalse);
    expect(client.serverInfo.supportsAuth(AuthMechanism.login), isFalse);
    expect(client.serverInfo.supportsAuth(AuthMechanism.plain), isTrue);
    expect(client.serverInfo.capabilities, ['mock', 'AUTH PLAIN']);
    await client.disconnect();
  });
}
