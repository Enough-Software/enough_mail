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
  Socket _socket;
  bool isSocketClosingExpected = false;
  bool isLoggedIn = false;
  bool _isServerGreetingDone = false;
  ConnectionInfo connectionInfo;
  Completer<ConnectionInfo> _greetingsCompleter;
  final Duration connectionTimeout;

  void onDataReceived(Uint8List data);
  void onConnectionEstablished(
      ConnectionInfo connectionInfo, String serverGreeting);
  void onConnectionError(dynamic error);

  StreamSubscription _socketStreamSubscription;

  /// Creates a new base client
  ///
  /// Set [isLogEnabled] to `true` to see log output.
  /// Set the [logName] for adding the name to each log entry.
  /// Set the [connectionTimeout] in case the connection connection should timeout automatically after the given time.
  ClientBase({this.isLogEnabled = false, this.logName, this.connectionTimeout});

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
    _greetingsCompleter = Completer<ConnectionInfo>();
    _isServerGreetingDone = false;
    connect(socket);
    return _greetingsCompleter.future;
  }

  /// Starts to liste on [socket].
  ///
  /// This is mainly useful for testing purposes, ensure to set [serverInfo] manually in this  case.
  void connect(Socket socket) {
    _socket = socket;
    _writeFuture = null;
    if (connectionTimeout != null) {
      final timeoutStream = socket.timeout(connectionTimeout);
      _socketStreamSubscription = timeoutStream.listen(
        _onDataReceived,
        onDone: onConnectionDone,
        onError: _onConnectionError,
      );
    } else {
      _socketStreamSubscription = socket.listen(
        _onDataReceived,
        onDone: onConnectionDone,
        onError: _onConnectionError,
      );
    }
    isSocketClosingExpected = false;
  }

  void _onConnectionError(dynamic e) async {
    log('Socket error: $e', initial: initialApp);
    isLoggedIn = false;
    _writeFuture = null;
    if (!isSocketClosingExpected) {
      isSocketClosingExpected = true;
      try {
        await _socketStreamSubscription.cancel();
      } catch (e, s) {
        log('Unable to cancel stream subscription: $e $s', initial: initialApp);
      }
      try {
        onConnectionError(e);
      } catch (e, s) {
        log('Unable to call onConnectionError: $e, $s', initial: initialApp);
      }
    }
  }

  Future<void> upradeToSslSocket() async {
    await _socketStreamSubscription.pause();
    var secureSocket = await SecureSocket.secure(_socket);
    if (secureSocket != null) {
      log('now using secure connection.', initial: initialApp);
      await _socketStreamSubscription.cancel();
      isSocketClosingExpected = true;
      await _socket.destroy();
      isSocketClosingExpected = false;
      connect(secureSocket);
    }
  }

  void _onDataReceived(Uint8List data) async {
    if (_isServerGreetingDone) {
      onDataReceived(data);
    } else {
      _isServerGreetingDone = true;
      final serverGreeting = String.fromCharCodes(data);
      log(serverGreeting, isClient: false);
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
    if (_socketStreamSubscription != null) {
      await _socketStreamSubscription.cancel();
    }
    isSocketClosingExpected = true;
    if (_socket != null) {
      await _socket.close();
    }
  }

  Future _writeFuture;

  /// Writes the specified [text].
  ///
  /// When the log is enabled it will either log the specified [logObject] or just the [text].
  Future writeText(String text, [dynamic logObject]) async {
    final previousWriteFuture = _writeFuture;
    if (previousWriteFuture != null) {
      try {
        await previousWriteFuture;
      } catch (e, s) {
        print('Unable to await previous write future: $e $s');
        _writeFuture = null;
      }
    }
    if (isLogEnabled) {
      logObject ??= text;
      log(logObject);
    }
    _socket.write(text + '\r\n');
    final future = _socket.flush();
    _writeFuture = future;
    await future;
    _writeFuture = null;
  }

  /// Writes the specified [data].
  ///
  /// When the log is enabled it will either log the specified [logObject] or just the length of the data.
  Future writeData(List<int> data, [dynamic logObject]) async {
    final previousWriteFuture = _writeFuture;
    if (previousWriteFuture != null) {
      try {
        await previousWriteFuture;
      } catch (e, s) {
        print('Unable to await previous write future: $e $s');
        _writeFuture = null;
      }
    }
    if (isLogEnabled) {
      logObject ??= '<${data.length} bytes>';
      log(logObject);
    }
    _socket.add(data);
    final future = _socket.flush();
    _writeFuture = future;
    await future;
    _writeFuture = null;
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

class _QueuedText {
  final String text;
  final dynamic logObject;
  _QueuedText(this.text, this.logObject);
}
