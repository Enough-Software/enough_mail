import 'dart:convert';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';

/// A minimal POP3 server whose mailbox grows by one message per session.
class PopLoopbackServer {
  PopLoopbackServer._(this._server);

  static Future<PopLoopbackServer> start() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final server = PopLoopbackServer._(socket);
    socket.listen(server._onConnection);

    return server;
  }

  final ServerSocket _server;
  final requests = <String>[];
  int sessions = 0;

  /// Additional messages reported by `STAT` on top of the session count
  int extraMessages = 0;

  /// The id whose next `RETR` fails once with `-ERR`
  int? failRetrieveOnce;

  String get host => _server.address.address;
  int get port => _server.port;

  Future<void> close() => _server.close();

  void _onConnection(Socket socket) {
    sessions++;
    final messageCount = sessions + extraMessages;
    socket.write('+OK POP3 ready\r\n');
    socket.listen((data) {
      for (final line in utf8.decode(data).split('\r\n')) {
        if (line.isEmpty) {
          continue;
        }
        requests.add(line);
        final command = line.split(' ').first.toUpperCase();
        switch (command) {
          case 'STAT':
            socket.write('+OK $messageCount ${messageCount * 100}\r\n');
            break;
          case 'RETR':
            final id = line.split(' ').last;
            if (int.tryParse(id) == failRetrieveOnce) {
              failRetrieveOnce = null;
              socket.write('-ERR temporary failure\r\n');
              break;
            }
            socket.write(
              '+OK 100 octets\r\nSubject: message $id\r\n\r\nbody $id\r\n.\r\n',
            );
            break;
          case 'AUTH':
            final payload = utf8.decode(base64.decode(line.split(' ').last));
            if (payload.contains('Bearer bad')) {
              final details = base64.encode(utf8.encode('{"status":"401"}'));
              socket.write('+ $details\r\n');
            } else {
              socket.write('+OK welcome\r\n');
            }
            break;
          case 'QUIT':
            socket
              ..write('+OK bye\r\n')
              ..destroy();
            break;
          default:
            socket.write('+OK\r\n');
        }
      }
      if (utf8.decode(data) == '\r\n') {
        // empty client response after an XOAUTH2 error challenge
        socket.write('-ERR [AUTH] invalid credentials\r\n');
      }
    }, onError: (_) {});
  }
}

MailAccount _account(PopLoopbackServer server) =>
    MailAccount.fromManualSettings(
      name: 'test',
      email: 'user@example.com',
      password: 'secret',
      incomingHost: server.host,
      incomingPort: server.port,
      incomingType: ServerType.pop,
      incomingSocketType: SocketType.plainNoStartTls,
      outgoingHost: server.host,
    );

void main() {
  late PopLoopbackServer server;

  setUp(() async {
    server = await PopLoopbackServer.start();
  });

  tearDown(() => server.close());

  test('polling detects new messages and ends the previous session', () async {
    final mailClient = MailClient(_account(server));
    final loaded = <MimeMessage>[];
    mailClient.eventStream.listen((event) {
      if (event is MailLoadEvent) {
        loaded.add(event.message);
      }
    });
    await mailClient.connect();
    final inbox = await mailClient.selectInbox();
    expect(inbox.messagesExists, 1);
    await mailClient.startPolling(const Duration(milliseconds: 100));
    await Future.delayed(const Duration(milliseconds: 350));
    await mailClient.stopPolling();
    expect(loaded, isNotEmpty);
    expect(loaded.first.sequenceId, 2);
    expect(loaded.first.decodeSubject(), 'message 2');
    expect(inbox.messagesExists, greaterThanOrEqualTo(2));
    // the first session was ended with QUIT before the second one started
    expect(server.requests.indexOf('QUIT'), greaterThan(0));
    await mailClient.disconnect();
  });

  test('a failed retrieve does not skip the remaining new messages', () async {
    final mailClient = MailClient(_account(server));
    final loaded = <int?>[];
    mailClient.eventStream.listen((event) {
      if (event is MailLoadEvent) {
        loaded.add(event.message.sequenceId);
      }
    });
    await mailClient.connect();
    final inbox = await mailClient.selectInbox();
    expect(inbox.messagesExists, 1);
    // the next session reports 4 messages, but message 2 cannot be loaded:
    server
      ..extraMessages = 2
      ..failRetrieveOnce = 2;
    await mailClient.startPolling(const Duration(milliseconds: 100));
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (loaded.length < 4 && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    await mailClient.stopPolling();
    // the failed poll must not have advanced the known message count:
    expect(loaded, containsAllInOrder([2, 3, 4, 5]));
    await mailClient.disconnect();
  });

  test('AUTH XOAUTH2', () async {
    final client = PopClient();
    await client.connectToServer(server.host, server.port, isSecure: false);
    await client.authenticateWithOAuth2('user@example.com', 'good');
    expect(client.isLoggedIn, isTrue);
    expect(server.requests.last, startsWith('AUTH XOAUTH2 '));
    await client.disconnect();

    final failing = PopClient();
    await failing.connectToServer(server.host, server.port, isSecure: false);
    await expectLater(
      failing.authenticateWithOAuth2('user@example.com', 'bad'),
      throwsA(
        isA<PopException>().having(
          (e) => e.response.result,
          'result',
          contains('invalid credentials'),
        ),
      ),
    );
    expect(failing.isLoggedIn, isFalse);
    // the final -ERR was consumed, so the session is still in sync:
    await failing.noop();
    await failing.disconnect();
  });
}
