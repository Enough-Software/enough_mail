import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/util/client_base.dart';
import 'package:test/test.dart';

import 'mock_socket.dart';

void main() {
  late ServerSocket server;
  late String host;

  setUp(() async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    host = server.address.address;
  });

  tearDown(() => server.close());

  test('connect fails when the server closes before greeting', () async {
    server.listen((socket) => socket.destroy());
    final client = SmtpClient('test.example.com');
    await expectLater(
      client.connectToServer(host, server.port, isSecure: false),
      throwsA(isA<SmtpException>()),
    );
  });

  test('a manually connected socket may close before the greeting', () async {
    final connection = MockConnection();
    final client = SmtpClient('test.example.com')
      ..connect(
        connection.socketClient,
        connectionInformation: const ConnectionInfo(
          'smtp.example.com',
          587,
          isSecure: false,
        ),
      );
    // closing the stream before any greeting must not raise an unhandled
    // error for a greeting that nobody awaits
    await connection.socketClient.close();
    await Future.delayed(const Duration(milliseconds: 20));
    expect(client.isConnected, isFalse);
  });

  test('connect fails when no greeting arrives within the timeout', () async {
    server.listen((socket) {
      // keep the socket open and stay silent
    });
    final client = ImapClient();
    await expectLater(
      client.connectToServer(
        host,
        server.port,
        isSecure: false,
        timeout: const Duration(milliseconds: 300),
      ),
      throwsA(isA<ImapException>()),
    );
    expect(client.isConnected, isFalse);
  });

  test('SMTP: a pending command fails when the connection is lost', () async {
    server.listen((socket) {
      socket.write('220 mock ESMTP\r\n');
      socket.listen((_) => socket.destroy());
    });
    final client = SmtpClient('test.example.com');
    await client.connectToServer(host, server.port, isSecure: false);
    await expectLater(client.ehlo(), throwsA(isA<SmtpException>()));
  });

  test('POP: a pending command fails when the connection is lost', () async {
    server.listen((socket) {
      socket.write('+OK mock ready\r\n');
      socket.listen((_) => socket.destroy());
    });
    final client = PopClient();
    await client.connectToServer(host, server.port, isSecure: false);
    await expectLater(client.status(), throwsA(isA<PopException>()));
  });

  test('POP: a malformed multi-line reply fails the command', () async {
    server.listen((socket) {
      socket.write('+OK mock ready\r\n');
      socket.listen((_) => socket.write('+OK\r\nnot a listing\r\n.\r\n'));
    });
    final client = PopClient();
    await client.connectToServer(host, server.port, isSecure: false);
    await expectLater(client.list(), throwsA(isA<PopException>()));
  });

  test('a pending command fails when the client disconnects', () async {
    server.listen((socket) {
      socket.write('220 mock ESMTP\r\n');
      // never answer any command
    });
    final client = SmtpClient('test.example.com');
    await client.connectToServer(host, server.port, isSecure: false);
    final pending = expectLater(client.ehlo(), throwsA(isA<SmtpException>()));
    await client.disconnect();
    await pending;
  });
}
