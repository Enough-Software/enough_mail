import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/pop/pop_events.dart';
import 'package:enough_mail/pop/pop_exception.dart';
import 'package:enough_mail/pop/pop_response.dart';
import 'package:enough_mail/src/pop/commands/all_commands.dart';
import 'package:enough_mail/src/pop/parsers/pop_standard_parser.dart';
import 'package:enough_mail/src/pop/pop_command.dart';
import 'package:enough_mail/src/util/client_base.dart';
import 'package:enough_mail/src/util/uint8_list_reader.dart';
import 'package:event_bus/event_bus.dart';

/// Client to access POP3 compliant servers.
/// Compare https://tools.ietf.org/html/rfc1939 for details.
class PopClient extends ClientBase {
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
  final EventBus _eventBus;

  final Uint8ListReader _uint8listReader = Uint8ListReader();
  PopCommand? _currentCommand;
  String? _currentFirstResponseLine;
  final PopStandardParser _standardParser = PopStandardParser();
  late PopServerInfo _serverInfo;
  set serverInfo(PopServerInfo info) => _serverInfo = info;

  /// Set the [eventBus] to add your specific `EventBus` to listen to SMTP events.
  /// Set [isLogEnabled] to `true` to see log output.
  /// Set the [logName] for adding the name to each log entry.
  /// Set the [connectionTimeout] in case the connection connection should timeout automatically after the given time.
  PopClient({
    EventBus? bus,
    bool isLogEnabled = false,
    String? logName,
    Duration? connectionTimeout,
  })  : _eventBus = bus ?? EventBus(),
        super(
            isLogEnabled: isLogEnabled,
            logName: logName,
            connectionTimeout: connectionTimeout);

  @override
  void onConnectionEstablished(
      ConnectionInfo connectionInfo, String serverGreeting) {
    _serverInfo = PopServerInfo();
    if (serverGreeting.startsWith('+OK')) {
      final chunks = serverGreeting.split(' ');
      _serverInfo.timestamp = chunks.last;
    }
  }

  @override
  void onConnectionError(dynamic error) {
    eventBus.fire(PopConnectionLostEvent(this));
  }

  @override
  void onDataReceived(Uint8List data) {
    _uint8listReader.add(data);
    if (_currentFirstResponseLine == null) {
      _currentFirstResponseLine = _uint8listReader.readLine();
      if (_currentFirstResponseLine != null &&
          _currentFirstResponseLine!.startsWith('-ERR')) {
        onServerResponse([_currentFirstResponseLine]);
        return;
      }
    }
    if (_currentCommand!.isMultiLine) {
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
  Future<void> startTls() async {
    await sendCommand(PopStartTlsCommand());
    log('STTL: upgrading socket to secure one...', initial: 'A');
    await upradeToSslSocket();
  }

  /// Logs the user in with the default `USER` and `PASS` commands.
  Future<void> login(String? name, String? password) async {
    await sendCommand(PopUserCommand(name));
    await sendCommand(PopPassCommand(password));
    isLoggedIn = true;
  }

  /// Logs the user in with the `APOP` command.
  Future<void> loginWithApop(String name, String password) async {
    await sendCommand(PopApopCommand(name, password, _serverInfo.timestamp));
    isLoggedIn = true;
  }

  /// Ends the POP session and also removes any messages that have been marked as deleted
  Future<void> quit() async {
    await sendCommand(PopQuitCommand(this));
    isLoggedIn = false;
  }

  /// Checks the status ie the total number of messages and their size
  Future<PopStatus> status() {
    return sendCommand(PopStatusCommand());
  }

  /// Checks the ID and size of all messages or of the message with the specified [messageId]
  Future<List<MessageListing>> list([int? messageId]) {
    return sendCommand(PopListCommand(messageId));
  }

  /// Checks the ID and UID of all messages or of the message with the specified [messageId]
  /// This command is optional and may not be supported by all servers.
  Future<List<MessageListing>> uidList([int? messageId]) {
    return sendCommand(PopUidListCommand(messageId));
  }

  /// Downloads the message with the specified [messageId]
  Future<MimeMessage> retrieve(int? messageId) {
    return sendCommand(PopRetrieveCommand(messageId));
  }

  /// Downloads the first [numberOfLines] lines of the message with the [messageId]
  Future<MimeMessage> retrieveTopLines(int messageId, int numberOfLines) {
    return sendCommand(PopRetrieveCommand(messageId));
  }

  /// Marks the message with the specified [messageId] as deleted
  Future<void> delete(int? messageId) {
    return sendCommand(PopDeleteCommand(messageId));
  }

  /// Keeps any messages that are marked as deleted
  Future<void> reset() {
    return sendCommand(PopResetCommand());
  }

  /// Keeps the connection alive
  Future<void> noop() {
    return sendCommand(PopNoOpCommand());
  }

  Future<T> sendCommand<T>(PopCommand<T> command) {
    _currentCommand = command;
    _currentFirstResponseLine = null;
    writeText(command.command, command);
    return command.completer.future;
  }

  void onServerResponse(List<String?> responseTexts) {
    if (isLogEnabled) {
      for (var responseText in responseTexts) {
        log(responseText, isClient: false);
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
        writeText(commandText);
      } else if (command.isCommandDone(response)) {
        if (response.isFailedStatus) {
          command.completer.completeError(PopException(this, response));
        } else {
          command.completer.complete(response.result);
        }
        //_log("Done with command ${_currentCommand.command}");
        _currentCommand = null;
      }
    }
  }

  /// Closes the connection. Deprecated: use `disconnect()` instead.
  @deprecated
  Future<dynamic> closeConnection() {
    return disconnect();
  }
}
