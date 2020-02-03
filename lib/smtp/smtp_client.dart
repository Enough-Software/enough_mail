import 'dart:io';
import 'dart:typed_data';
import 'package:enough_mail/smtp/smtp_events.dart';
import 'package:enough_mail/src/smtp/commands/smtp_connect_command.dart';
import 'package:event_bus/event_bus.dart';
import 'package:enough_mail/mime_message.dart';
import 'package:enough_mail/smtp/smtp_response.dart';
import 'package:enough_mail/src/smtp/smtp_command.dart';
import 'package:enough_mail/src/smtp/commands/all_commands.dart';
import 'package:enough_mail/src/util/uint8_list_reader.dart';

/// Keeps information about the remote IMAP server
///
/// Persist this information to improve initialization times.
class SmtpServerInfo {
  String host;
  bool isSecure;
  int port;
  String capabilitiesText;
  List<String> capabilities;
}

/// Low-level SMTP library for Dartlang
///
/// Compliant to Extended SMTP standard [RFC 5321].
class SmtpClient {
  /// Information about the IMAP service
  SmtpServerInfo serverInfo;

  /// Allows to listens for events
  ///
  /// If no event bus is specified in the constructor, an aysnchronous bus is used.
  /// Usage:
  /// ```
  /// eventBus.on<SmtpConnectionLostEvent>().listen((event) {
  ///   // All events are of type SmtpConnectionLostEvent (or subtypes of it).
  ///   _log(event.type);
  /// });
  ///
  /// eventBus.on<SmtpEvent>().listen((event) {
  ///   // All events are of type SmtpEvent (or subtypes of it).
  ///   _log(event.type);
  /// });
  /// ```
  EventBus eventBus;
  bool get isLoggedIn => _isLoggedIn;
  bool get isNotLoggedIn => !_isLoggedIn;

  bool _isLoggedIn = false;

  String _clientDomain;

  Socket _socket;
  final Uint8ListReader _uint8listReader = Uint8ListReader();
  bool _isLogEnabled;
  SmtpCommand _currentCommand;

  /// Creates a new instance with the optional [bus] event bus.
  ///
  /// Compare [eventBus] for more information.
  SmtpClient(String clientDomain, {EventBus bus, bool isLogEnabled = false}) {
    _clientDomain = clientDomain;
    bus ??= EventBus();
    eventBus = bus;
    _isLogEnabled = isLogEnabled;
  }

  /// Connects to the specified server.
  ///
  /// Specify [isSecure] if you do not want to connect to a secure service.
  Future<SmtpResponse> connectToServer(String host, int port,
      {bool isSecure = true}) async {
    _log('connecting to server $host:$port - secure: $isSecure');
    serverInfo = SmtpServerInfo();
    serverInfo.host = host;
    serverInfo.port = port;
    serverInfo.isSecure = isSecure;
    var cmd = SmtpConnectCommand();
    _currentCommand = cmd;
    var socket = isSecure
        ? await SecureSocket.connect(host, port)
        : await Socket.connect(host, port);
    connect(socket);
    return cmd.completer.future;
  }

  /// Starts to liste on [socket].
  ///
  /// This is mainly useful for testing purposes, ensure to set [serverInfo] manually in this  case.
  void connect(Socket socket) {
    socket.listen(onData, onDone: () {
      _log('Done, connection closed');
      _isLoggedIn = false;
      eventBus.fire(SmtpConnectionLostEvent());
    }, onError: (error) {
      _log('Error: $error');
      _isLoggedIn = false;
      eventBus.fire(SmtpConnectionLostEvent());
    });
    _socket = socket;
  }

  void onData(Uint8List data) {
    //print('onData: [${String.fromCharCodes(data).replaceAll("\r\n", "<CRLF>\n")}]');
    _uint8listReader.add(data);
    onServerResponse(_uint8listReader.readLines());
  }

  /// Issues the enhanced helo command to find out the capabilities of the SMTP server
  ///
  /// EHLO or HELO always needs to be the first command that is sent to the SMTP server.
  Future<SmtpResponse> ehlo() {
    return sendCommand(SmtpEhloCommand(_clientDomain));
  }

  /// Upgrades the current insure connection to SSL.
  ///
  /// Opportunistic TLS (Transport Layer Security) refers to extensions
  /// in plain text communication protocols, which offer a way to upgrade a plain text connection
  /// to an encrypted (TLS or SSL) connection instead of using a separate port for encrypted communication.
  Future<SmtpResponse> startTls() async {
    var response = await sendCommand(SmtpStartTlsCommand());
    if (response.isOkStatus) {
      _log('STARTTL: upgrading socket to secure one...');
      var secureSocket = await SecureSocket.secure(_socket);
      _log('STARTTL: now using secure connection.');
      if (secureSocket != null) {
        await _socket.close();
        await _socket.destroy();
        connect(secureSocket);
        //_socket = secureSocket;
        await ehlo();
      }
    }
    return response;
  }

  Future<SmtpResponse> sendMessage(MimeMessage message,
      [bool use8BitEncoding = true]) {
    return sendCommand(SmtpSendMailCommand(message, use8BitEncoding));
  }

  Future<SmtpResponse> login(String name, String password) {
    return sendCommand(SmtpAuthCommand(name, password));
  }

  Future<SmtpResponse> quit() async {
    var response = await sendCommand(SmtpQuitCommand(this));
    _isLoggedIn = false;
    return response;
  }

  Future<SmtpResponse> sendCommand(SmtpCommand command) {
    _currentCommand = command;
    _log('C: ${command.command}');
    _socket?.write(command.command + '\r\n');
    return command.completer.future;
  }

  void write(String commandText) {
    _log('C: $commandText');
    _socket?.write(commandText + '\r\n');
  }

  void onServerResponse(List<String> responseTexts) {
    if (_isLogEnabled) {
      for (var responseText in responseTexts) {
        _log('S: $responseText');
      }
    }
    var response = SmtpResponse(responseTexts);
    if (_currentCommand != null) {
      var commandText = _currentCommand.nextCommand(response);
      if (commandText != null) {
        write(commandText);
      } else if (_currentCommand.isCommandDone(response)) {
        _currentCommand.completer.complete(response);
        //_log("Done with command ${_currentCommand.command}");
        _currentCommand = null;
      }
    }
  }

  void close() {
    _socket?.close();
  }

  void _log(String text) {
    if (_isLogEnabled) {
      if (text.startsWith('C: AUTH PLAIN ')) {
        text = 'C: AUTH PLAIN <base64 code scrambled>';
      }
      print(text);
    }
  }
}
