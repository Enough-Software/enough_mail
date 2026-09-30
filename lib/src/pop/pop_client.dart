import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
  /// Set [isLogEnabled] to `true` to see log output.
  ///
  /// Set the [logName] for adding the name to each log entry.
  ///
  /// [onBadCertificate] is an optional handler for unverifiable certificates.
  /// The handler receives the [X509Certificate], and can inspect it and decide
  /// (or let the user decide) whether to accept the connection or not.
  /// The handler should return true to continue the [SecureSocket] connection.
  ///
  /// [securityContext] is an optional [SecurityContext] for mTLS
  /// (mutual TLS / client certificate authentication).
  PopClient({
    bool isLogEnabled = false,
    String? logName,
    bool Function(X509Certificate)? onBadCertificate,
    SecurityContext? securityContext,
  }) : super(
         isLogEnabled: isLogEnabled,
         logName: logName,
         onBadCertificate: onBadCertificate,
         securityContext: securityContext,
       );

  /// Allows listening to events fired by this [PopClient].
  ///
  /// Usage:
  /// ```dart
  /// popClient.eventStream.whereType<PopConnectionLostEvent>().listen((event) {
  ///   _log(event.type);
  /// });
  /// ```
  Stream<PopEvent> get eventStream => _eventController.stream;
  final StreamController<PopEvent> _eventController =
      StreamController<PopEvent>.broadcast();

  final Uint8ListReader _uint8listReader = Uint8ListReader();
  PopCommand? _currentCommand;
  String? _currentFirstResponseLine;
  final PopStandardParser _standardParser = PopStandardParser();

  /// Information about the remote POP server
  late PopServerInfo serverInfo;

  @override
  FutureOr<void> onConnectionEstablished(
    ConnectionInfo connectionInfo,
    String serverGreeting,
  ) {
    // discard any partial reply of a previous connection
    _uint8listReader.clear();
    _currentFirstResponseLine = null;
    if (serverGreeting.startsWith('+OK')) {
      final chunks = serverGreeting.split(' ');
      serverInfo = PopServerInfo(chunks.last.trimRight());
    } else {
      serverInfo = PopServerInfo('');
    }
  }

  @override
  void onConnectionError(dynamic error) {
    // a command awaiting its response would otherwise hang forever:
    _failCurrentCommand(
      PopException.message(this, 'connection lost: $error'),
      StackTrace.current,
    );
    if (!_eventController.isClosed) {
      _eventController.add(PopConnectionLostEvent(this));
    }
  }

  @override
  Future<void> disconnect() {
    _failCurrentCommand(
      PopException.message(this, 'client disconnected'),
      StackTrace.current,
    );

    return super.disconnect();
  }

  void _failCurrentCommand(Object error, StackTrace stackTrace) {
    final command = _currentCommand;
    _currentCommand = null;
    _currentFirstResponseLine = null;
    if (command != null && !command.completer.isCompleted) {
      command.completer.completeError(error, stackTrace);
    }
  }

  /// Writes to the socket and fails the [command] when writing fails,
  /// instead of leaving it pending with an unhandled asynchronous error.
  void _write(Future<void> Function() write, PopCommand command) {
    unawaited(
      write().catchError((Object e, StackTrace s) {
        if (_currentCommand == command) {
          _currentCommand = null;
        }
        if (!command.completer.isCompleted) {
          command.completer.completeError(
            e is PopException
                ? e
                : PopException.message(this, 'unable to send command: $e'),
            s,
          );
        }
      }),
    );
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
    await upgradeToSslSocket();
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

  /// Logs the user in with the given [user] and [accessToken] via OAuth 2.0
  /// using the `AUTH XOAUTH2` mechanism.
  Future<void> authenticateWithOAuth2(String user, String accessToken) async {
    await sendCommand(PopAuthXOAuth2Command(user, accessToken));
    isLoggedIn = true;
  }

  /// Ends the POP session.
  ///
  /// Also removes any messages that have been marked as deleted
  Future<void> quit() async {
    await sendCommand(PopQuitCommand(this));
    isLoggedIn = false;
    await disconnect();
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
  ///
  /// The [messageId] is stored as the message's `sequenceId`.
  Future<MimeMessage> retrieve(int messageId) async {
    final message = await sendCommand(PopRetrieveCommand(messageId));

    return message..sequenceId = messageId;
  }

  /// Downloads the first [numberOfLines] lines of the message
  /// with the given [messageId]
  ///
  /// The [messageId] is stored as the message's `sequenceId`.
  Future<MimeMessage> retrieveTopLines(int messageId, int numberOfLines) async {
    final message = await sendCommand(PopTopCommand(messageId, numberOfLines));

    return message..sequenceId = messageId;
  }

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
    _write(() => writeText(command.command, command), command);

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
      logApp(
        'ignoring response starting with '
        '[${responseTexts.isEmpty ? '' : responseTexts.first}] '
        'with ${responseTexts.length} lines.',
      );

      return;
    }
    try {
      final parser = command.parser ?? _standardParser;
      final response = parser.parse(responseTexts);
      final commandText = command.nextCommand(response);
      if (commandText != null) {
        // the reply to the follow-up has to be read afresh, otherwise the
        // current first line would be dispatched again
        _currentFirstResponseLine = null;
        _write(() => writeText(commandText), command);
      } else if (command.isCommandDone(response)) {
        if (response.isFailedStatus) {
          command.completer.completeError(PopException(this, response));
        } else {
          command.completer.complete(response.result);
        }
        _currentCommand = null;
      }
    } catch (e, s) {
      // a malformed server reply must fail the command, not leave it pending
      logApp('Unable to process response: $e $s');
      _failCurrentCommand(
        PopException.message(this, 'unable to process response: $e'),
        s,
      );
    }
  }

  @override
  Exception createClientError(String message) =>
      PopException.message(this, message);
}
