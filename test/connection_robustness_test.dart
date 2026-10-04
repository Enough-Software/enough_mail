import 'dart:async';
import 'dart:convert';
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

  /// Logs in and selects INBOX on a mock server that answers `LOGIN` and
  /// `SELECT` only. Returns the client and the server side of the connection.
  Future<(ImapClient, Socket)> connectAndSelectInbox() async {
    final serverSide = Completer<Socket>();
    server.listen((socket) {
      serverSide.complete(socket);
      socket.write('* OK mock ready\r\n');
      utf8.decoder.bind(socket).transform(const LineSplitter()).listen((line) {
        final tag = line.substring(0, line.indexOf(' '));
        if (line.contains(' LOGIN ')) {
          socket.write('$tag OK [CAPABILITY IMAP4rev1 IDLE] logged in\r\n');
        } else if (line.contains(' SELECT ')) {
          socket.write('* 1 EXISTS\r\n$tag OK [READ-WRITE] selected\r\n');
        }
        // never answer any other command
      }, onError: (_) {});
    });
    final client = ImapClient();
    await client.connectToServer(host, server.port, isSecure: false);
    await client.login('user', 'password');
    await client.selectMailbox(
      Mailbox(
        encodedName: 'INBOX',
        encodedPath: 'INBOX',
        flags: [],
        pathSeparator: '/',
      ),
    );

    return (client, await serverSide.future);
  }

  // Until the IDLE command is written nobody listens to its task, which is
  // the case while it waits in the queue behind a pending command.
  test('IMAP: disconnecting while IDLE waits behind a pending command '
      'leaves no unhandled error', () async {
    final (client, _) = await connectAndSelectInbox();
    final pending = expectLater(client.noop(), throwsA(isA<ImapException>()));
    await client.idleStart();
    await client.disconnect();
    await pending;
  });

  test('IMAP: losing the connection while IDLE waits behind a pending command '
      'leaves no unhandled error', () async {
    final (client, serverSide) = await connectAndSelectInbox();
    final pending = expectLater(client.noop(), throwsA(isA<ImapException>()));
    await client.idleStart();
    serverSide.destroy();
    await pending;
  });

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

  test(
    'IMAP: a pending command fails plainly when the client disconnects',
    () async {
      server.listen((socket) {
        socket.write('* OK mock ready\r\n');
        // never answer any command
      });
      final client = ImapClient();
      await client.connectToServer(host, server.port, isSecure: false);
      final pending = expectLater(
        client.noop(),
        throwsA(
          isA<ImapException>().having(
            (e) => e.message,
            'message',
            'client disconnected',
          ),
        ),
      );
      await client.disconnect();
      await pending;
    },
  );

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
