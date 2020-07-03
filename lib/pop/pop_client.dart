import 'dart:io';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/pop/pop_events.dart';
import 'package:enough_mail/pop/pop_response.dart';
import 'package:enough_mail/src/pop/commands/all_commands.dart';
import 'package:enough_mail/src/pop/parsers/pop_standard_parser.dart';
import 'package:enough_mail/src/pop/pop_command.dart';
import 'package:enough_mail/src/util/uint8_list_reader.dart';
import 'package:event_bus/event_bus.dart';

/// Client to access POP3 compliant servers.
/// Compare https://tools.ietf.org/html/rfc1939 for details.
class PopClient {
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
  EventBus get eventBus => _eventBus;
  EventBus _eventBus;
  bool _isSocketClosingExpected = false;
  bool get isLoggedIn => _isLoggedIn;
  bool get isNotLoggedIn => !_isLoggedIn;

  bool _isLoggedIn = false;
  Socket _socket;
  final Uint8ListReader _uint8listReader = Uint8ListReader();
  bool _isLogEnabled;
  PopCommand _currentCommand;
  String _currentFirstResponseLine;
  final PopStandardParser _standardParser = PopStandardParser();
  PopServerInfo _serverInfo;
  set serverInfo(PopServerInfo info) => _serverInfo = info;

  PopClient({EventBus bus, bool isLogEnabled = false}) {
    bus ??= EventBus();
    _eventBus = bus;
    _isLogEnabled = isLogEnabled;
  }

  /// Connects to the specified server.
  ///
  /// Specify [isSecure] if you do not want to connect to a secure service.
  Future<PopResponse> connectToServer(String host, int port,
      {bool isSecure = true}) async {
    _log('connecting to server $host:$port - secure: $isSecure');
    var cmd = PopConnectCommand(this);
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
      if (!_isSocketClosingExpected) {
        eventBus.fire(PopConnectionLostEvent());
      }
    }, onError: (error) {
      _log('Error: $error');
      _isLoggedIn = false;
      if (!_isSocketClosingExpected) {
        eventBus.fire(PopConnectionLostEvent());
      }
    });
    _isSocketClosingExpected = false;
    _socket = socket;
  }

  void onData(Uint8List data) {
    //print('onData: [${String.fromCharCodes(data).replaceAll("\r\n", "<CRLF>\n")}]');
    _uint8listReader.add(data);
    if (_currentFirstResponseLine == null) {
      _currentFirstResponseLine = _uint8listReader.readLine();
      if (_currentFirstResponseLine != null &&
          _currentFirstResponseLine.startsWith('-ERR')) {
        onServerResponse([_currentFirstResponseLine]);
        return;
      }
    }
    if (_currentCommand.isMultiLine) {
      var lines = _uint8listReader.readLinesToCrLfDotCrLfSequence();
      if (lines != null) {
        if (_currentFirstResponseLine != null) {
          lines.insert(0, _currentFirstResponseLine);
        }
        onServerResponse(lines);
      }
    } else if (_currentFirstResponseLine != null) {
      onServerResponse([_currentFirstResponseLine]);
    }
  }

  /// Upgrades the current insure connection to SSL.
  ///
  /// Opportunistic TLS (Transport Layer Security) refers to extensions
  /// in plain text communication protocols, which offer a way to upgrade a plain text connection
  /// to an encrypted (TLS or SSL) connection instead of using a separate port for encrypted communication.
  Future<PopResponse> startTls() async {
    var response = await sendCommand(PopStartTlsCommand());
    if (response.isOkStatus) {
      _log('STTL: upgrading socket to secure one...');
      var secureSocket = await SecureSocket.secure(_socket);
      if (secureSocket != null) {
        _log('STTL: now using secure connection.');
        _isSocketClosingExpected = true;
        await _socket.close();
        await _socket.destroy();
        _isSocketClosingExpected = false;
        connect(secureSocket);
      }
    }
    return response;
  }

  /// Logs the user in with the default `USER` and `PASS` commands.
  Future<PopResponse> login(String name, String password) async {
    var response = await sendCommand(PopUserCommand(name));
    if (response.isFailedStatus) {
      return response;
    }
    response = await sendCommand(PopPassCommand(password));
    _isLoggedIn = response.isOkStatus;
    return response;
  }

  /// Logs the user in with the `APOP` command.
  Future<PopResponse> loginWithApop(String name, String password) async {
    var response = await sendCommand(
        PopApopCommand(name, password, _serverInfo?.timestamp));
    _isLoggedIn = response.isOkStatus;
    return response;
  }

  /// Ends the POP session and also removes any messages that have been marked as deleted
  Future<PopResponse> quit() async {
    var response = await sendCommand(PopQuitCommand(this));
    _isLoggedIn = false;
    return response;
  }

  /// Checks the status ie the total number of messages and their size
  Future<PopResponse<PopStatus>> status() {
    return sendCommand(PopStatusCommand());
  }

  /// Checks the ID and size of all messages or of the message with the specified [messageId]
  Future<PopResponse<List<MessageListing>>> list([int messageId]) {
    return sendCommand(PopListCommand(messageId));
  }

  /// Checks the ID and UID of all messages or of the message with the specified [messageId]
  /// This command is optional and may not be supported by all servers.
  Future<PopResponse<List<MessageListing>>> uidList([int messageId]) {
    return sendCommand(PopUidListCommand(messageId));
  }

  /// Downloads the message with the specified [messageId]
  Future<PopResponse<MimeMessage>> retrieve(int messageId) {
    return sendCommand(PopRetrieveCommand(messageId));
  }

  /// Downloads the first [numberOfLines] lines of the message with the [messageId]
  Future<PopResponse<MimeMessage>> retrieveTopLines(
      int messageId, int numberOfLines) {
    return sendCommand(PopRetrieveCommand(messageId));
  }

  /// Marks the message with the specified [messageId] as deleted
  Future<PopResponse> delete(int messageId) {
    return sendCommand(PopDeleteCommand(messageId));
  }

  /// Keeps any messages that are marked as deleted
  Future<PopResponse> reset() {
    return sendCommand(PopResetCommand());
  }

  /// Keeps the connection alive
  Future<PopResponse> noop() {
    return sendCommand(PopNoOpCommand());
  }

  Future<PopResponse> sendCommand(PopCommand command) {
    _currentCommand = command;
    _currentFirstResponseLine = null;
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
    var command = _currentCommand;
    if (command == null) {
      print(
          'ignoring response starting with [${responseTexts.first}] with ${responseTexts.length} lines.');
    }
    if (command != null) {
      var parser = command.parser;
      parser ??= _standardParser;
      var response = parser.parse(responseTexts);
      var commandText = command.nextCommand(response);
      if (commandText != null) {
        write(commandText);
      } else if (command.isCommandDone(response)) {
        command.completer.complete(response);
        //_log("Done with command ${_currentCommand.command}");
        _currentCommand = null;
      }
    }
  }

  Future<dynamic> closeConnection() {
    _isSocketClosingExpected = true;
    return _socket?.close();
  }

  void _log(String text) {
    if (_isLogEnabled) {
      if (text.startsWith('C: PASS ')) {
        text = 'C: PASS <password scrambled>';
      }
      print(text);
    }
  }
}
