import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class ConnectionInfo {
  final String host;
  final int port;
  final bool isSecure;
  const ConnectionInfo(this.host, this.port, this.isSecure);
}

/// Base class for socket-based clients
abstract class ClientBase {
  static const String initialClient = 'C';
  static const String initialServer = 'S';
  static const String initialApp = 'A';

  String logName;
  bool isLogEnabled;
  Socket socket;
  bool isSocketClosingExpected = false;
  bool isLoggedIn = false;
  bool isServerGreetingDone = false;
  ConnectionInfo connectionInfo;
  Completer<ConnectionInfo> _greetingsCompleter;

  void onDataReceived(Uint8List data);
  void onConnectionEstablished(
      ConnectionInfo connectionInfo, String serverGreeting);
  void onConnectionError(dynamic error);

  StreamSubscription _socketStreamSubscription;

  ClientBase({this.isLogEnabled = false, this.logName});

  /// Connects to the specified server.
  ///
  /// Specify [isSecure] if you do not want to connect to a secure service.
  Future<ConnectionInfo> connectToServer(String host, int port,
      {bool isSecure = true}) async {
    log('connecting to server $host:$port - secure: $isSecure',
        initial: initialApp);
    connectionInfo = ConnectionInfo(host, port, isSecure);
    var socket = isSecure
        ? await SecureSocket.connect(host, port)
        : await Socket.connect(host, port);

    connect(socket);
    _greetingsCompleter = Completer<ConnectionInfo>();
    return _greetingsCompleter.future;
  }

  /// Starts to liste on [socket].
  ///
  /// This is mainly useful for testing purposes, ensure to set [serverInfo] manually in this  case.
  void connect(Socket socket) {
    _socketStreamSubscription =
        socket.listen(_onDataReceived, onDone: onConnectionDone, onError: (e) {
      log('Socket error: $e', initial: 'A');
      isLoggedIn = false;
      if (!isSocketClosingExpected) {
        isSocketClosingExpected = true;
        onConnectionError(e);
      }
    });
    isSocketClosingExpected = false;
    this.socket = socket;
  }

  Future<void> upradeToSslSocket() async {
    var secureSocket = await SecureSocket.secure(socket);
    if (secureSocket != null) {
      log('now using secure connection.', initial: initialApp);
      await _socketStreamSubscription.cancel();
      isSocketClosingExpected = true;
      await socket.close();
      await socket.destroy();
      isSocketClosingExpected = false;
      connect(secureSocket);
    }
  }

  void _onDataReceived(Uint8List data) async {
    if (isServerGreetingDone) {
      onDataReceived(data);
    } else {
      isServerGreetingDone = true;
      final serverGreeting = String.fromCharCodes(data);
      onConnectionEstablished(connectionInfo, serverGreeting);
      _greetingsCompleter?.complete(connectionInfo);
    }
  }

  void onConnectionDone() {
    log('Done, connection closed', initial: initialApp);
    isLoggedIn = false;
    if (!isSocketClosingExpected) {
      isSocketClosingExpected = true;
      onConnectionError('onDone not expected');
    }
  }

  Future<void> disconnect() async {
    await _socketStreamSubscription.cancel();
    isSocketClosingExpected = true;
    await socket.close();
  }

  Future writeText(String text, [dynamic logObject]) {
    if (isLogEnabled) {
      logObject ??= text;
      log(logObject);
    }
    socket.write(text + '\r\n');
    return socket.flush();
  }

  void log(dynamic logObject, {bool isClient = true, String initial}) {
    if (isLogEnabled) {
      initial ??= (isClient == true) ? initialClient : initialServer;
      if (logName != null) {
        print('$logName $initial: $logObject');
      } else {
        print('$initial: $logObject');
      }
    }
  }
}
