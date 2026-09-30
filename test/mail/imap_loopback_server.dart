import 'dart:io';

/// A minimal stateful IMAP server for MailClient tests.
///
/// Records every received command line in [requests].
class ImapLoopbackServer {
  ImapLoopbackServer._(this._server);

  static Future<ImapLoopbackServer> start() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final server = ImapLoopbackServer._(socket);
    socket.listen(server._onConnection);

    return server;
  }

  final ServerSocket _server;
  final requests = <String>[];
  final _sockets = <Socket>[];

  /// The number of connections that were accepted
  int connections = 0;

  String get host => _server.address.address;
  int get port => _server.port;

  Future<void> close() async {
    for (final socket in _sockets) {
      socket.destroy();
    }
    await _server.close();
  }

  void _onConnection(Socket socket) {
    connections++;
    _sockets.add(socket);
    socket.write(
      '* OK [CAPABILITY IMAP4rev1 AUTH=PLAIN AUTH=XOAUTH2] ready\r\n',
    );
    var buffer = '';
    socket.listen((data) {
      buffer += String.fromCharCodes(data);
      while (true) {
        final end = buffer.indexOf('\r\n');
        if (end == -1) {
          return;
        }
        final line = buffer.substring(0, end);
        buffer = buffer.substring(end + 2);
        _onLine(socket, line);
      }
    }, onError: (_) {});
  }

  void _onLine(Socket socket, String line) {
    requests.add(line);
    final space = line.indexOf(' ');
    if (space == -1) {
      return;
    }
    final tag = line.substring(0, space);
    final rest = line.substring(space + 1);
    final command = rest.split(' ').first.toUpperCase();
    switch (command) {
      case 'CAPABILITY':
        socket.write(
          '* CAPABILITY IMAP4rev1 AUTH=PLAIN AUTH=XOAUTH2\r\n$tag OK done\r\n',
        );
        break;
      case 'LOGIN':
      case 'AUTHENTICATE':
        socket.write('$tag OK [CAPABILITY IMAP4rev1] authenticated\r\n');
        break;
      case 'LIST':
        socket.write(
          '* LIST (\\HasNoChildren) "/" INBOX\r\n$tag OK LIST completed\r\n',
        );
        break;
      case 'SELECT':
      case 'EXAMINE':
        socket.write(
          '* 1 EXISTS\r\n* 0 RECENT\r\n* OK [UIDVALIDITY 1] ok\r\n'
          '* OK [UIDNEXT 2] ok\r\n$tag OK [READ-WRITE] done\r\n',
        );
        break;
      case 'LOGOUT':
        socket
          ..write('* BYE\r\n$tag OK done\r\n')
          ..destroy();
        break;
      default:
        socket.write('$tag OK done\r\n');
    }
  }
}
