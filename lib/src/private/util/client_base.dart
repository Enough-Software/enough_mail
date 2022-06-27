import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Provides connection information
class ConnectionInfo {
  /// Creates a new connection info
  const ConnectionInfo(this.host, this.port, {required this.isSecure});

  /// The host
  final String host;

  /// The port
  final int port;

  /// `true` when a secure socket is used
  final bool isSecure;
}

/// Base class for socket-based clients
abstract class ClientBase {
  /// Creates a new base client
  ///
  /// Set [isLogEnabled] to `true` to see log output.
  /// Set the [logName] for adding the name to each log entry.
  /// [onBadCertificate] is an optional handler for unverifiable certificates.
  /// The handler receives the [X509Certificate], and can inspect it and decide
  /// (or let the user decide) whether to accept the connection or not.
  /// The handler should return true to continue the [SecureSocket] connection.
  ClientBase({
    this.isLogEnabled = false,
    this.logName,
    this.onBadCertificate,
  });

  /// Initial for a client log output
  static const String initialClient = 'C';

  /// Initial for a server log output
  static const String initialServer = 'S';

  /// Initial for an app log output
  static const String initialApp = 'A';

  /// The name shown in log entries to differentiate this server
  String? logName;

  /// `true` when the log is enabled
  bool isLogEnabled;

  late Socket _socket;

  /// `true` when it is expected that the socket is closed
  bool isSocketClosingExpected = false;

  /// `true` after the user has authenticated
  bool isLoggedIn = false;

  bool _isServerGreetingDone = false;

  /// Information about the connection
  late ConnectionInfo connectionInfo;
  late Completer<ConnectionInfo> _greetingsCompleter;

  bool _isConnected = false;

  /// Ist the client currently connected?
  bool get isConnected => _isConnected;

  /// Handles unverifiable certificates.
  ///
  /// The handler receives the [X509Certificate], and can inspect it and decide
  /// (or let the user decide) whether to accept the connection or not.
  /// The handler should return true to continue the [SecureSocket] connection.
  final bool Function(X509Certificate)? onBadCertificate;

  /// Is called when data is received
  void onDataReceived(Uint8List data);

  /// Is called after the initial connection has been established
  FutureOr<void> onConnectionEstablished(
      ConnectionInfo connectionInfo, String serverGreeting);

  /// Is called when the connection encountered an error
  void onConnectionError(dynamic error);

  late StreamSubscription _socketStreamSubscription;

  /// Connects to the specified server.
  ///
  /// Specify [isSecure] if you do not want to connect to a secure service.
  Future<ConnectionInfo> connectToServer(
    String host,
    int port, {
    bool isSecure = true,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    logApp('connecting to server $host:$port - '
        'secure: $isSecure, timeout: $timeout');
    connectionInfo = ConnectionInfo(host, port, isSecure: isSecure);
    final socket = isSecure
        ? await SecureSocket.connect(
            host,
            port,
            onBadCertificate: onBadCertificate,
          ).timeout(timeout)
        : await Socket.connect(host, port).timeout(timeout);
    _greetingsCompleter = Completer<ConnectionInfo>();
    _isServerGreetingDone = false;
    connect(socket);
    return _greetingsCompleter.future;
  }

  /// Starts to listen on the given [socket].
  ///
  /// This is mainly useful for testing purposes, ensure to set
  /// [connectionInformation] manually in this  case, e.g.
  /// ```dart
  /// await client.connect(socket, connectionInformation:
  /// ConnectionInfo(host, port, isSecure));
  /// ```
  void connect(Socket socket, {ConnectionInfo? connectionInformation}) {
    if (connectionInformation != null) {
      connectionInfo = connectionInformation;
      _greetingsCompleter = Completer<ConnectionInfo>();
    }
    _socket = socket;
    _writeFuture = null;
    // if (connectionTimeout != null) {
    //   final timeoutStream = socket.timeout(connectionTimeout!);
    //   _socketStreamSubscription = timeoutStream.listen(
    //     _onDataReceived,
    //     onDone: onConnectionDone,
    //     onError: _onConnectionError,
    //   );
    // } else {
    _socketStreamSubscription = socket.listen(
      _onDataReceived,
      onDone: onConnectionDone,
      onError: _onConnectionError,
    );
    // }
    _isConnected = true;
    isSocketClosingExpected = false;
  }

  Future<void> _onConnectionError(Object e, StackTrace s) async {
    logApp('Socket error: $e $s');
    isLoggedIn = false;
    _isConnected = false;
    _writeFuture = null;
    if (!isSocketClosingExpected) {
      isSocketClosingExpected = true;
      try {
        await _socketStreamSubscription.cancel();
      } catch (e, s) {
        logApp('Unable to cancel stream subscription: $e $s');
      }
      try {
        onConnectionError(e);
      } catch (e, s) {
        logApp('Unable to call onConnectionError: $e, $s');
      }
    }
  }

  /// Upgrades the current connection to a secure socket
  Future<void> upgradeToSslSocket() async {
    _socketStreamSubscription.pause();
    final secureSocket = await SecureSocket.secure(_socket);
    logApp('now using secure connection.');
    await _socketStreamSubscription.cancel();
    isSocketClosingExpected = true;
    _socket.destroy();
    isSocketClosingExpected = false;
    connect(secureSocket);
  }

  Future<void> _onDataReceived(Uint8List data) async {
    if (_isServerGreetingDone) {
      onDataReceived(data);
    } else {
      _isServerGreetingDone = true;
      final serverGreeting = String.fromCharCodes(data);
      log(serverGreeting, isClient: false);
      onConnectionEstablished(connectionInfo, serverGreeting);
      _greetingsCompleter.complete(connectionInfo);
    }
  }

  /// Informs about a closed connection
  void onConnectionDone() {
    logApp('Done, connection closed');
    isLoggedIn = false;
    _isConnected = false;
    if (!isSocketClosingExpected) {
      isSocketClosingExpected = true;
      onConnectionError('onDone not expected');
    }
  }

  /// Disconnects from the service
  Future<void> disconnect() async {
    if (_isConnected) {
      logApp('disconnecting');
      isLoggedIn = false;
      _isConnected = false;
      isSocketClosingExpected = true;
      try {
        await _socketStreamSubscription.cancel();
      } catch (e) {
        print('unable to cancel subscription $e');
      }
      try {
        await _socket.close();
      } catch (e) {
        print('unable to close socket $e');
      }
    }
  }

  Future? _writeFuture;

  /// Writes the specified [text].
  ///
  /// When the log is enabled it will either log the specified [logObject]
  /// or just the [text].
  ///
  /// When a [timeout] is specified and occurs, it will
  /// throw a [TimeoutException] after the specified time.
  Future writeText(String text, [dynamic logObject, Duration? timeout]) async {
    final previousWriteFuture = _writeFuture;
    if (previousWriteFuture != null) {
      try {
        await previousWriteFuture;
      } catch (e, s) {
        print('Unable to await previous write '
            'future $previousWriteFuture: $e $s');
        _writeFuture = null;
        rethrow;
      }
    }
    if (isLogEnabled) {
      logObject ??= text;
      log(logObject);
    }
    _socket.write('$text\r\n');

    final future =
        timeout == null ? _socket.flush() : _socket.flush().timeout(timeout);
    _writeFuture = future;
    await future;
    _writeFuture = null;
  }

  /// Writes the specified [data].
  ///
  /// When the log is enabled it will either log the specified
  /// [logObject] or just the length of the data.
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

  /// Logs the data from the app-side
  void logApp(dynamic logObject) => log(logObject, initial: initialApp);

  /// Logs the data from the client-side
  void logClient(dynamic logObject) => log(logObject, initial: initialClient);

  /// Logs the data from the server-side
  void logServer(dynamic logObject) => log(logObject, initial: initialServer);

  /// Logs the data
  void log(dynamic logObject, {bool isClient = true, String? initial}) {
    if (isLogEnabled) {
      initial ??= (isClient == true) ? initialClient : initialServer;
      if (logName != null) {
        print('$logName $initial: $logObject');
      } else {
        print('$initial: $logObject');
      }
    }
  }

  void _onTimeout(Completer completer, Duration duration) {
    // print(
    //     '$completer triggers timeout after $duration on
    //      $this at ${DateTime.now()}');
    completer.completeError(createClientError('timeout'));
  }

  /// Subclasses need to be able to create client specific exceptions
  Object createClientError(String message);
}

/// Extends Completer instances
extension ExtensionCompleter on Completer {
  /// Adds a timeout to a completer
  void timeout(Duration? duration, ClientBase client) {
    if (duration != null) {
      Future.delayed(duration).then((value) {
        if (!isCompleted) {
          client._onTimeout(this, duration);
        }
      });
    }
  }
}

// class _QueuedText {
//   final String text;
//   final dynamic logObject;
//   _QueuedText(this.text, this.logObject);
// }
