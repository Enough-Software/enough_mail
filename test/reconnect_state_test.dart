import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';

/// The clients are reused for a new connection after the previous one was
/// lost in the middle of a reply. The partial reply must not corrupt the
/// parsing of the replies of the new connection.
void main() {
  late ServerSocket server;
  late String host;

  setUp(() async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    host = server.address.address;
  });

  tearDown(() => server.close());

  /// Sends the [greeting] on every connection, answers the first command of
  /// the first connection with the [partialReply] and closes that
  /// connection. Later connections are answered with [reply].
  void serve({
    required String greeting,
    required String partialReply,
    required String Function(String request) reply,
  }) {
    var connections = 0;
    server.listen((socket) {
      connections++;
      final isFirst = connections == 1;
      socket.write(greeting);
      socket.listen((data) async {
        if (isFirst) {
          socket.write(partialReply);
          await socket.flush();
          socket.destroy();
        } else {
          socket.write(reply(String.fromCharCodes(data)));
        }
      });
    });
  }

  test('SMTP: a partial reply of a lost connection is discarded', () async {
    serve(
      greeting: '220 mock ESMTP\r\n',
      partialReply: '250-mock\r\n250-PIPELINING\r\n250-SI',
      reply: (_) => '250 mock\r\n',
    );
    final client = SmtpClient('test.example.com');
    await client.connectToServer(host, server.port, isSecure: false);
    await expectLater(client.ehlo(), throwsA(isA<SmtpException>()));
    await client.connectToServer(host, server.port, isSecure: false);
    final response = await client.ehlo().timeout(const Duration(seconds: 5));
    expect(response.code, 250);
    expect(client.serverInfo.capabilities, ['mock']);
    await client.disconnect();
  });

  test('POP: a partial reply of a lost connection is discarded', () async {
    serve(
      greeting: '+OK mock ready\r\n',
      partialReply: '+OK 3 10',
      reply: (_) => '+OK 5 200\r\n',
    );
    final client = PopClient();
    await client.connectToServer(host, server.port, isSecure: false);
    await expectLater(client.status(), throwsA(isA<PopException>()));
    await client.connectToServer(host, server.port, isSecure: false);
    final status = await client.status().timeout(const Duration(seconds: 5));
    expect(status.numberOfMessages, 5);
    await client.disconnect();
  });

  test('IMAP: a partial literal of a lost connection is discarded', () async {
    serve(
      greeting: '* OK mock ready\r\n',
      partialReply: '* 1 FETCH (BODY[] {100}\r\npartial',
      reply: (request) => '${request.split(' ').first} OK done\r\n',
    );
    final client = ImapClient();
    await client.connectToServer(host, server.port, isSecure: false);
    await expectLater(client.noop(), throwsA(isA<ImapException>()));
    await client.connectToServer(host, server.port, isSecure: false);
    await client.noop().timeout(const Duration(seconds: 5));
    await client.disconnect();
  });
}
