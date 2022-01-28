import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:event_bus/event_bus.dart';

import '../mime_message.dart';
import '../private/pop/commands/all_commands.dart';
import '../private/pop/parsers/pop_standard_parser.dart';
import '../private/pop/pop_command.dart';
import '../private/util/client_base.dart';
import '../private/util/uint8_list_reader.dart';
import 'pop_events.dart';
import 'pop_exception.dart';
import 'pop_response.dart';

/// Client to access POP3 compliant servers.
/// Compare https://tools.ietf.org/html/rfc1939 for details.
class PopClient extends ClientBase {
  /// Creates a new PopClient
  ///
  /// Set the [eventBus] to add your specific `EventBus` to listen to POP events
  ///
  /// Set [isLogEnabled] to `true` to see log output.
  ///
  /// Set the [logName] for adding the name to each log entry.
  ///
  /// [onBadCertificate] is an optional handler for unverifiable certificates.
  /// The handler receives the [X509Certificate], and can inspect it and decide
  /// (or let the user decide) whether to accept the connection or not.
  /// The handler should return true to continue the [SecureSocket] connection.
  PopClient({
    EventBus? bus,
    bool isLogEnabled = false,
    String? logName,
    bool Function(X509Certificate)? onBadCertificate,
  })  : _eventBus = bus ?? EventBus(),
        super(
          isLogEnabled: isLogEnabled,
          logName: logName,
          onBadCertificate: onBadCertificate,
        );

  /// Allows to listens for events
  ///
  /// If no event bus is specified in the constructor,
  /// an aysnchronous bus is used.
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

  /// Information about the remote POP server
  late PopServerInfo serverInfo;

  @override
  FutureOr<void> onConnectionEstablished(
      ConnectionInfo connectionInfo, String serverGreeting) {
    if (serverGreeting.startsWith('+OK')) {
      final chunks = serverGreeting.split(' ');
      serverInfo = PopServerInfo(chunks.last);
    } else {
      serverInfo = PopServerInfo('');
    }
  }

  @override
  void onConnectionError(dynamic error) {
    eventBus.fire(PopConnectionLostEvent(this));
  }

  @override
  void onDataReceived(Uint8List data) {
    _uint8listReader.add(data);
    _currentFirstResponseLine ??= _uint8listReader.readLine();
    final currentLine = _currentFirstResponseLine;
    if (currentLine != null && currentLine.startsWith('-ERR')) {
      onServerResponse([currentLine]);
      return;
    }
    if (_currentCommand?.isMultiLine ?? false) {
      final lines = _uint8listReader.readLinesToCrLfDotCrLfSequence();
      if (lines != null) {
        if (currentLine != null) {
          lines.insert(0, currentLine);
        }
        onServerResponse(lines);
      }
    } else if (currentLine != null) {
      onServerResponse([currentLine]);
    }
  }

  /// Upgrades the current insure connection to SSL.
  ///
  /// Opportunistic TLS (Transport Layer Security) refers to extensions
  /// in plain text communication protocols, which offer a way to upgrade
  /// a plain text connection
  /// to an encrypted (TLS or SSL) connection instead of using a separate
  /// port for encrypted communication.
  Future<void> startTls() async {
    await sendCommand(PopStartTlsCommand());
    log('STTL: upgrading socket to secure one...', initial: 'A');
    await upradeToSslSocket();
  }

  /// Logs the user in with the default `USER` and `PASS` commands.
  Future<void> login(String name, String password) async {
    await sendCommand(PopUserCommand(name));
    await sendCommand(PopPassCommand(password));
    isLoggedIn = true;
  }

  /// Logs the user in with the `APOP` command.
  Future<void> loginWithApop(String name, String password) async {
    await sendCommand(PopApopCommand(name, password, serverInfo.timestamp));
    isLoggedIn = true;
  }

  /// Ends the POP session.
  ///
  /// Also removes any messages that have been marked as deleted
  Future<void> quit() async {
    await sendCommand(PopQuitCommand(this));
    isLoggedIn = false;
  }

  /// Checks the status ie the total number of messages and their size
  Future<PopStatus> status() => sendCommand(PopStatusCommand());

  /// Checks the ID and size of all messages
  /// or of the message with the specified [messageId]
  Future<List<MessageListing>> list([int? messageId]) =>
      sendCommand(PopListCommand(messageId));

  /// Checks the ID and UID of all messages
  /// or of the message with the specified [messageId]
  ///
  /// This command is optional and may not be supported by all servers.
  Future<List<MessageListing>> uidList([int? messageId]) =>
      sendCommand(PopUidListCommand(messageId));

  /// Downloads the message with the specified [messageId]
  Future<MimeMessage> retrieve(int? messageId) =>
      sendCommand(PopRetrieveCommand(messageId));

  /// Downloads the first [numberOfLines] lines of the message
  /// with the given [messageId]
  Future<MimeMessage> retrieveTopLines(int messageId, int numberOfLines) =>
      sendCommand(PopRetrieveCommand(messageId));

  /// Marks the message with the specified [messageId] as deleted
  Future<void> delete(int messageId) =>
      sendCommand(PopDeleteCommand(messageId));

  /// Keeps any messages that are marked as deleted
  Future<void> reset() => sendCommand(PopResetCommand());

  /// Keeps the connection alive
  Future<void> noop() => sendCommand(PopNoOpCommand());

  /// Sends the specified command to the remote POP server
  Future<T> sendCommand<T>(PopCommand<T> command) {
    _currentCommand = command;
    _currentFirstResponseLine = null;
    writeText(command.command, command);
    return command.completer.future;
  }

  /// Processes server responses
  void onServerResponse(List<String> responseTexts) {
    if (isLogEnabled) {
      for (final responseText in responseTexts) {
        log(responseText, isClient: false);
      }
    }
    final command = _currentCommand;
    if (command == null) {
      print('ignoring response starting with [${responseTexts.first}] '
          'with ${responseTexts.length} lines.');
    }
    if (command != null) {
      var parser = command.parser;
      parser ??= _standardParser;
      final response = parser.parse(responseTexts);
      final commandText = command.nextCommand(response);
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

  @override
  Object createClientError(String message) =>
      PopException.message(this, message);
}
