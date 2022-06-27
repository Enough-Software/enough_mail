import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:enough_serialization/enough_serialization.dart';
import 'package:event_bus/event_bus.dart';

import '../codecs/date_codec.dart';
import '../exception.dart';
import '../message_flags.dart';
import '../mime_message.dart';
import '../private/imap/all_parsers.dart';
import '../private/imap/capability_parser.dart';
import '../private/imap/command.dart';
import '../private/imap/imap_response.dart';
import '../private/imap/imap_response_reader.dart';
import '../private/imap/response_parser.dart';
import '../private/util/client_base.dart';
import 'id.dart';
import 'imap_events.dart';
import 'imap_exception.dart';
import 'imap_search.dart';
import 'mailbox.dart';
import 'message_sequence.dart';
import 'metadata.dart';
import 'qresync.dart';
import 'response.dart';
import 'return_option.dart';

/// Describes a capability
class Capability extends SerializableObject {
  /// Creates a new capability with the given [name]
  Capability(String name) {
    this.name = name;
  }

  /// The name of the capability
  String get name => attributes['name'];
  set name(String value) => attributes['name'] = value;

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) => other is Capability && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// Keeps information about the remote IMAP server
///
/// Persist this information to improve initialization times.
class ImapServerInfo {
  /// Creates a new server info instance
  ImapServerInfo(ConnectionInfo info)
      : host = info.host,
        port = info.port,
        isSecure = info.isSecure;

  /// [ID](https://tools.ietf.org/html/rfc2971) capability with the value `ID`
  static const String capabilityId = 'ID';

  /// [IDLE](https://tools.ietf.org/html/rfc2177) capability with the value `IDLE`
  static const String capabilityIdle = 'IDLE';

  /// [MOVE](https://tools.ietf.org/html/rfc6851) capability with the value `MOVE`
  static const String capabilityMove = 'MOVE';

  ///  capability with the value `QRESYNC`
  static const String capabilityQresync = 'QRESYNC';

  /// [UID PLUS](https://tools.ietf.org/html/rfc2359) capability with the value `UIDPLUS`
  static const String capabilityUidPlus = 'UIDPLUS';

  /// [UTF-8](https://tools.ietf.org/html/rfc6855) capability with the value `UTF8=ACCEPT`
  static const String capabilityUtf8Accept = 'UTF8=ACCEPT';

  /// [UTF-8](https://tools.ietf.org/html/rfc6855) capability with the value `UTF8=ONLY`
  static const String capabilityUtf8Only = 'UTF8=ONLY';

  /// [THREAD](https://tools.ietf.org/html/rfc5256) capability with the value `THREAD=ORDEREDSUBJECT`
  static const String capabilityThreadOrderedSubject = 'THREAD=ORDEREDSUBJECT';

  /// [THREAD](https://tools.ietf.org/html/rfc5256) capability with the value `THREAD=REFERENCES`
  static const String capabilityThreadReferences = 'THREAD=REFERENCES';

  /// [STARTTLS](https://tools.ietf.org/html/rfc2595) capability with the value `STARTTLS`
  static const String capabilityStartTls = 'STARTTLS';

  /// The used host of the service
  final String host;

  /// `true` when a secure connection is used
  final bool isSecure;

  /// The port of the server
  final int port;

  /// The separator for paths, only set after listing the mailboxes
  String? pathSeparator;

  /// The known capabilities as text
  String? capabilitiesText;

  /// The known capabilities
  List<Capability>? capabilities;

  /// The enabled capabilities
  final List<Capability> enabledCapabilities = [];

  /// Checks if the capability with the specified [capabilityName] is supported.
  bool supports(String capabilityName) =>
      capabilities?.firstWhereOrNull((c) => c.name == capabilityName) != null;

  /// Does the server support [STARTTLS](https://tools.ietf.org/html/rfc2595)?
  bool get supportsStartTls => supports(capabilityStartTls);

  /// Does the server support [UID PLUS](https://tools.ietf.org/html/rfc2359)?
  bool get supportsUidPlus => supports(capabilityUidPlus);

  /// Does the server support [IDLE](https://tools.ietf.org/html/rfc2177)?
  bool get supportsIdle => supports(capabilityIdle);

  /// Does the server support [MOVE](https://tools.ietf.org/html/rfc6851)?
  bool get supportsMove => supports(capabilityMove);

  /// Does the server support [QRESYNC](https://tools.ietf.org/html/rfc5162)?
  bool get supportsQresync => supports(capabilityQresync);

  /// Does the server support [UTF-8](https://tools.ietf.org/html/rfc6855)?
  bool get supportsUtf8 =>
      supports(capabilityUtf8Accept) || supports(capabilityUtf8Only);

  /// Does the server support [ID](https://tools.ietf.org/html/rfc2971)?
  bool get supportsId => supports(capabilityId);

  /// Does the server support [THREAD](https://tools.ietf.org/html/rfc5256)?
  bool get supportsThreading =>
      supports(capabilityThreadOrderedSubject) ||
      supports(capabilityThreadReferences);
  List<String>? _supportedThreadingMethods;

  /// Retrieves the supported threading methods, e.g. `[]`,
  /// `['ORDEREDSUBJECT']` or `['ORDEREDSUBJECT', 'REFERENCES']`
  List<String> get supportedThreadingMethods {
    var methods = _supportedThreadingMethods;
    if (methods == null) {
      methods = <String>[];
      _supportedThreadingMethods = methods;
      final caps = capabilities;
      if (caps != null) {
        for (final cap in caps) {
          if (cap.name.startsWith('THREAD=')) {
            methods.add(cap.name.substring('THREAD='.length));
          }
        }
      }
    }
    return methods;
  }

  /// Checks if the capability with the specified [capabilityName]
  /// has been enabled.
  bool isEnabled(String capabilityName) =>
      enabledCapabilities.firstWhereOrNull((c) => c.name == capabilityName) !=
      null;
}

/// Possible flag store actions
enum StoreAction {
  /// Add the specified flag(s)
  add,

  /// Remove the specified flag(s)
  remove,

  /// Replace the flags of the message with the specified ones.
  replace
}

/// Options for querying status updates
enum StatusFlags {
  /// The number of messages in the mailbox.
  messages,

  /// The number of messages with the \Recent flag set.
  recent,

  /// The next unique identifier value of the mailbox.
  uidNext,

  /// The unique identifier validity value of the mailbox.
  uidValidity,

  /// The number of messages which do not have the \Seen flag set.
  unseen,

  /// The highest mod-sequence value of all messages in the mailbox.
  ///
  /// Only available when the CONDSTORE or QRESYNC capability is supported.
  highestModSequence
}

/// Low-level IMAP library.
///
/// Compliant to IMAP4rev1 standard [RFC 3501](https://tools.ietf.org/html/rfc3501).
/// Also compare recommendations at [RFC 2683](https://tools.ietf.org/html/rfc2683)
class ImapClient extends ClientBase {
  /// Creates a new ImapClient instance.
  ///
  /// Set the [eventBus] to add your specific `EventBus` to listen to
  /// IMAP events.
  /// Set [isLogEnabled] to `true` for getting log outputs on the standard
  /// output.
  /// Optionally specify a [logName] that is given out at logs to differentiate
  /// between different imap clients.
  /// Set the [defaultWriteTimeout] in case the connection connection should
  /// timeout automatically after the given time.
  /// [onBadCertificate] is an optional handler for unverifiable certificates.
  /// The handler receives the [X509Certificate], and can inspect it and decide
  /// (or let the user decide) whether to accept the connection or not.
  /// The handler should return true to continue the [SecureSocket] connection.
  ImapClient({
    EventBus? bus,
    bool isLogEnabled = false,
    String? logName,
    this.defaultWriteTimeout,
    this.defaultResponseTimeout,
    bool Function(X509Certificate)? onBadCertificate,
  })  : _eventBus = bus ?? EventBus(),
        super(
          isLogEnabled: isLogEnabled,
          logName: logName,
          onBadCertificate: onBadCertificate,
        ) {
    _imapResponseReader = ImapResponseReader(onServerResponse);
  }

  late ImapServerInfo _serverInfo;

  /// Information about the IMAP service
  ImapServerInfo get serverInfo => _serverInfo;

  /// Allows to listens for events
  ///
  /// If no event bus is specified in the constructor,
  /// an asynchronous bus is used.
  /// Usage:
  /// ```
  /// eventBus.on<ImapExpungeEvent>().listen((event) {
  ///   // All events are of type ImapExpungeEvent (or subtypes of it).
  ///   log(event.messageSequenceId);
  /// });
  ///
  /// eventBus.on<ImapEvent>().listen((event) {
  ///   // All events are of type ImapEvent (or subtypes of it).
  ///   log(event.eventType);
  /// });
  /// ```
  EventBus get eventBus => _eventBus;
  final EventBus _eventBus;

  int _lastUsedCommandId = 0;
  CommandTask? _currentCommandTask;
  final Map<String, CommandTask> _tasks = <String, CommandTask>{};
  Mailbox? _selectedMailbox;
  late ImapResponseReader _imapResponseReader;

  bool _isInIdleMode = false;
  CommandTask? _idleCommandTask;
  final _queue = <CommandTask>[];
  List<CommandTask>? _stashedQueue;

  /// The default timeout for getting a response
  final Duration? defaultResponseTimeout;

  /// The default timeout for sending a command
  final Duration? defaultWriteTimeout;

  @override
  void onDataReceived(Uint8List data) {
    _imapResponseReader.onData(data);
  }

  @override
  FutureOr<void> onConnectionEstablished(
    ConnectionInfo connectionInfo,
    String serverGreeting,
  ) async {
    _isInIdleMode = false;
    _serverInfo = ImapServerInfo(connectionInfo);
    final startIndex = serverGreeting.indexOf('[CAPABILITY ');
    if (startIndex != -1) {
      CapabilityParser.parseCapabilities(
          serverGreeting, startIndex + '[CAPABILITY '.length, _serverInfo);
    }
    if (_queue.isNotEmpty) {
      // this can happen when a connection was re-established,
      // e.g. when trying to complete an IDLE connection
      for (final task in _queue) {
        try {
          task.completer.completeError('reconnect');
        } catch (e, s) {
          print('unable to completeError for task $task $e $s');
        }
      }
      _queue.clear();
    }
  }

  @override
  void onConnectionError(dynamic error) {
    logApp('onConnectionError: $error');
    _isInIdleMode = false;
    _selectedMailbox = null;
    eventBus.fire(ImapConnectionLostEvent(this));
  }

  /// Logs in the user with the given [name] and [password].
  ///
  /// Requires the IMAP service to support `AUTH=PLAIN` capability.
  Future<List<Capability>> login(String name, String password) async {
    final cmd = Command(
      'LOGIN "$name" "$password"',
      logText: 'LOGIN "$name" "(password scrambled)"',
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    final parser = CapabilityParser(serverInfo);
    final response = await sendCommand<List<Capability>>(cmd, parser);
    isLoggedIn = true;
    return response;
  }

  /// Logs in the user with the given [user] and [accessToken] via Oauth 2.0.
  ///
  /// Note that the capability 'AUTH=XOAUTH2' needs to be present.
  Future<List<Capability>> authenticateWithOAuth2(
      String user, String accessToken) async {
    final authText =
        'user=$user\u{0001}auth=Bearer $accessToken\u{0001}\u{0001}';
    final authBase64Text = base64.encode(utf8.encode(authText));
    final cmd = Command(
      'AUTHENTICATE XOAUTH2 $authBase64Text',
      logText: 'AUTHENTICATE XOAUTH2 (base64 code scrambled)',
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    final response =
        await sendCommand<List<Capability>>(cmd, CapabilityParser(serverInfo));
    isLoggedIn = true;
    return response;
  }

  /// Logs in the user with the given [user] and [accessToken]
  /// via Oauth Bearer mechanism.
  ///
  /// Optionally specify the [host] and [port] of the service, per default the
  /// current connection is used.
  /// Note that the capability 'AUTH=OAUTHBEARER' needs to be present.
  /// Compare https://tools.ietf.org/html/rfc7628 for details
  Future<List<Capability>> authenticateWithOAuthBearer(
      String user, String accessToken,
      {String? host, int? port}) async {
    host ??= serverInfo.host;
    port ??= serverInfo.port;
    final authText = 'n,u=$user,\u{0001}'
        'host=$host\u{0001}'
        'port=$port\u{0001}'
        'auth=Bearer $accessToken\u{0001}\u{0001}';
    final authBase64Text = base64.encode(utf8.encode(authText));
    final cmd = Command(
      'AUTHENTICATE OAUTHBEARER $authBase64Text',
      logText: 'AUTHENTICATE OAUTHBEARER (base64 code scrambled)',
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    final response =
        await sendCommand<List<Capability>>(cmd, CapabilityParser(serverInfo));
    isLoggedIn = true;
    return response;
  }

  /// Logs the current user out.
  Future<dynamic> logout() async {
    final cmd = Command(
      'LOGOUT',
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    final response = await sendCommand<String>(cmd, LogoutParser());
    isLoggedIn = false;
    _isInIdleMode = false;
    return response;
  }

  /// Upgrades the current insure connection to SSL.
  ///
  /// Opportunistic TLS (Transport Layer Security) refers to extensions
  /// in plain text communication protocols, which offer a way to upgrade a
  /// plain text connection
  /// to an encrypted (TLS or SSL) connection instead of using a separate port
  /// for encrypted communication.
  Future<GenericImapResult> startTls() async {
    final cmd = Command(
      'STARTTLS',
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    final response = await sendCommand<GenericImapResult>(
        cmd, GenericParser(this, _selectedMailbox));
    log('STARTTLS: upgrading socket to secure one...', initial: 'A');
    await upgradeToSslSocket();
    return response;
  }

  /// Reports the optional [clientId] to the server and returns the server ID.
  ///
  /// This requires the server to the support the
  /// [IMAP4 ID extension](https://datatracker.ietf.org/doc/html/rfc2971).
  /// Check [ImapServerInfo.supportsId] to see if the ID extension is supported.
  Future<Id?> id({Id? clientId}) {
    final cmd = Command(
      'ID ${clientId ?? 'NIL'}',
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    return sendCommand(cmd, IdParser());
  }

  /// Checks the capabilities of this server directly
  Future<List<Capability>> capability() {
    final cmd = Command(
      'CAPABILITY',
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    final parser = CapabilityParser(serverInfo);
    return sendCommand<List<Capability>>(cmd, parser);
  }

  /// Copies the specified message(s) from the specified [sequence]
  /// from the currently selected mailbox to the target mailbox.
  ///
  /// You can either specify the [targetMailbox] or the [targetMailboxPath],
  /// if none is given, the messages will be copied to the currently
  /// selected mailbox.
  /// Compare [selectMailbox], [selectMailboxByPath] or [selectInbox] for
  /// selecting a mailbox first.
  /// Compare [uidCopy] for the copying files based on their sequence IDs
  Future<GenericImapResult> copy(MessageSequence sequence,
          {Mailbox? targetMailbox, String? targetMailboxPath}) =>
      _copyOrMove('COPY', sequence,
          targetMailbox: targetMailbox, targetMailboxPath: targetMailboxPath);

  /// Copies the specified message(s) from the specified [sequence]
  /// from the currently selected mailbox to the target mailbox.
  ///
  /// You can either specify the [targetMailbox] or the [targetMailboxPath],
  /// if none is given, the messages will be copied to the currently
  /// selected mailbox.
  /// Compare [selectMailbox], [selectMailboxByPath] or [selectInbox] for
  /// selecting a mailbox first.
  /// Compare [copy] for the version with message sequence IDs
  Future<GenericImapResult> uidCopy(MessageSequence sequence,
          {Mailbox? targetMailbox, String? targetMailboxPath}) =>
      _copyOrMove('UID COPY', sequence,
          targetMailbox: targetMailbox, targetMailboxPath: targetMailboxPath);

  /// Moves the specified message(s) from the specified [sequence]
  /// from the currently selected mailbox to the target mailbox.
  ///
  /// You must either specify the [targetMailbox] or the [targetMailboxPath],
  /// if none is given, move will fail.
  /// Compare [selectMailbox], [selectMailboxByPath] or [selectInbox] for
  /// selecting a mailbox first.
  /// Compare [uidMove] for moving messages based on their UID
  /// The move command is only available for servers that advertise the
  /// `MOVE` capability.
  Future<GenericImapResult> move(MessageSequence sequence,
      {Mailbox? targetMailbox, String? targetMailboxPath}) {
    if (targetMailbox == null && targetMailboxPath == null) {
      throw InvalidArgumentException(
          'move() error: Neither targetMailbox nor targetMailboxPath defined.');
    }
    return _copyOrMove('MOVE', sequence,
        targetMailbox: targetMailbox, targetMailboxPath: targetMailboxPath);
  }

  /// Copies the specified message(s) from the specified [sequence]
  /// from the currently selected mailbox to the target mailbox.
  ///
  /// You must either specify the [targetMailbox] or the [targetMailboxPath],
  /// if none is given, move will fail.
  /// Compare [selectMailbox], [selectMailboxByPath] or [selectInbox] for
  /// selecting a mailbox first.
  /// Compare [copy] for the version with message sequence IDs
  Future<GenericImapResult> uidMove(MessageSequence sequence,
      {Mailbox? targetMailbox, String? targetMailboxPath}) {
    if (targetMailbox == null && targetMailboxPath == null) {
      throw InvalidArgumentException('uidMove() error: Neither targetMailbox '
          'nor targetMailboxPath defined.');
    }
    return _copyOrMove('UID MOVE', sequence,
        targetMailbox: targetMailbox, targetMailboxPath: targetMailboxPath);
  }

  /// Implementation for both COPY or MOVE
  Future<GenericImapResult> _copyOrMove(
      String command, MessageSequence sequence,
      {Mailbox? targetMailbox, String? targetMailboxPath}) {
    final selectedMailbox = _selectedMailbox;
    if (selectedMailbox == null) {
      throw InvalidArgumentException('No mailbox selected.');
    }
    final buffer = StringBuffer()
      ..write(command)
      ..write(' ');
    sequence.render(buffer);
    final path = _encodeFirstMailboxPath(
        targetMailbox, targetMailboxPath, selectedMailbox);
    buffer
      ..write(' ')
      ..write(path);
    final cmd = Command(
      buffer.toString(), writeTimeout: defaultWriteTimeout,
      // Use response timeout here? This could be a long running operation...
    );
    return sendCommand<GenericImapResult>(
        cmd, GenericParser(this, selectedMailbox));
  }

  /// Updates the [flags] of the message(s) from the specified [sequence]
  /// in the currently selected mailbox.
  ///
  /// Set [silent] to true, if the updated flags should not be returned.
  /// Specify if flags should be replaced, added or removed with the [action]
  /// parameter, this defaults to adding flags.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the `CONDSTORE` or
  /// `QRESYNC` capability
  /// When there are modified elements that have not passed the
  /// [unchangedSinceModSequence] test, then the `modifiedMessageSequence`
  /// field  of the  contains the sequence of messages that have NOT been
  /// updated by this store command.
  /// Compare [selectMailbox], [selectMailboxByPath] or [selectInbox] for
  /// selecting a mailbox first.
  /// Compare the methods [markSeen], [markFlagged], etc for typical store
  /// operations.
  Future<StoreImapResult> store(MessageSequence sequence, List<String> flags,
          {StoreAction? action,
          bool? silent,
          int? unchangedSinceModSequence}) =>
      _store(false, 'STORE', sequence, flags,
          action: action,
          silent: silent,
          unchangedSinceModSequence: unchangedSinceModSequence);

  /// Updates the [flags] of the message(s) from the specified [sequence]
  /// in the currently selected mailbox.
  ///
  /// Set [silent] to true, if the updated flags should not be returned.
  /// Specify if flags should be replaced, added or removed with the [action]
  /// parameter, this defaults to adding flags.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the `CONDSTORE` or
  /// `QRESYNC` capability
  /// When there are modified elements that have not passed the
  /// [unchangedSinceModSequence] test, then the `modifiedMessageSequence`
  /// field  of the  contains the sequence of messages that have NOT been
  /// updated by this store command.
  /// Compare [selectMailbox], [selectMailboxByPath] or [selectInbox] for
  /// selecting a mailbox first.
  /// Compare the methods [uidMarkSeen], [uidMarkFlagged], etc for typical
  /// store operations.
  Future<StoreImapResult> uidStore(MessageSequence sequence, List<String> flags,
          {StoreAction? action,
          bool? silent,
          int? unchangedSinceModSequence}) =>
      _store(true, 'UID STORE', sequence, flags,
          action: action,
          silent: silent,
          unchangedSinceModSequence: unchangedSinceModSequence);

  /// STORE and UID STORE implementation
  Future<StoreImapResult> _store(bool isUidStore, String command,
      MessageSequence sequence, List<String> flags,
      {StoreAction? action,
      bool? silent,
      int? unchangedSinceModSequence}) async {
    if (_selectedMailbox == null) {
      throw InvalidArgumentException('No mailbox selected.');
    }
    action ??= StoreAction.add;
    silent ??= false;
    final buffer = StringBuffer()
      ..write(command)
      ..write(' ');
    if (unchangedSinceModSequence != null) {
      buffer
        ..write('(UNCHANGEDSINCE ')
        ..write(unchangedSinceModSequence)
        ..write(') ');
    }
    sequence.render(buffer);
    switch (action) {
      case StoreAction.add:
        buffer.write(' +FLAGS');
        break;
      case StoreAction.remove:
        buffer.write(' -FLAGS');
        break;
      default:
        buffer.write(' FLAGS');
    }
    if (silent) {
      buffer.write('.SILENT');
    }
    buffer.write(' (');
    var addSpace = false;
    for (final flag in flags) {
      if (addSpace) {
        buffer.write(' ');
      }
      buffer.write(flag);
      addSpace = true;
    }
    buffer.write(')');
    final cmd = Command(
      buffer.toString(),
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    final parser = FetchParser(isUidFetch: isUidStore);
    final messagesResponse = await sendCommand<FetchImapResult>(cmd, parser);
    final result = StoreImapResult()
      ..changedMessages = messagesResponse.messages
      ..modifiedMessageSequence = messagesResponse.modifiedSequence;
    return result;
  }

  /// Mark the messages from the specified [sequence] as seen/read.
  ///
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the `CONDSTORE` or
  /// `QRESYNC` capability
  /// Compare the [store] method in case you need more control or want to
  /// change several flags.
  Future<StoreImapResult> markSeen(MessageSequence sequence,
          {bool? silent, int? unchangedSinceModSequence}) =>
      store(sequence, [MessageFlags.seen],
          silent: silent, unchangedSinceModSequence: unchangedSinceModSequence);

  /// Mark the messages from the specified [sequence] as unseen/unread.
  ///
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the `CONDSTORE` or
  /// `QRESYNC` capability
  /// Compare the [store] method in case you need more control or want to
  /// change several flags.
  Future<StoreImapResult> markUnseen(MessageSequence sequence,
          {bool? silent, int? unchangedSinceModSequence}) =>
      store(sequence, [MessageFlags.seen],
          action: StoreAction.remove,
          silent: silent,
          unchangedSinceModSequence: unchangedSinceModSequence);

  /// Mark the messages from the specified [sequence] as flagged.
  ///
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the `CONDSTORE` or
  /// `QRESYNC` capability
  /// Compare the [store] method in case you need more control or want to
  /// change several flags.
  Future<StoreImapResult> markFlagged(MessageSequence sequence,
          {bool? silent, int? unchangedSinceModSequence}) =>
      store(sequence, [MessageFlags.flagged],
          silent: silent, unchangedSinceModSequence: unchangedSinceModSequence);

  /// Mark the messages from the specified [sequence] as unflagged.
  ///
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the
  /// `CONDSTORE` or `QRESYNC` capability
  /// Compare the [store] method in case you need more control or want to
  /// change several flags.
  Future<StoreImapResult> markUnflagged(MessageSequence sequence,
          {bool? silent, int? unchangedSinceModSequence}) =>
      store(sequence, [MessageFlags.flagged],
          action: StoreAction.remove,
          silent: silent,
          unchangedSinceModSequence: unchangedSinceModSequence);

  /// Mark the messages from the specified [sequence] as deleted.
  ///
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the
  /// `CONDSTORE` or `QRESYNC` capability
  /// Compare the [store] method in case you need more control or want to
  /// change several flags.
  Future<StoreImapResult> markDeleted(MessageSequence sequence,
          {bool? silent, int? unchangedSinceModSequence}) =>
      store(sequence, [MessageFlags.deleted],
          silent: silent, unchangedSinceModSequence: unchangedSinceModSequence);

  /// Mark the messages from the specified [sequence] as not deleted.
  ///
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the
  /// `CONDSTORE` or `QRESYNC` capability
  /// Compare the [store] method in case you need more control or want to
  /// change several flags.
  Future<StoreImapResult> markUndeleted(MessageSequence sequence,
          {bool? silent, int? unchangedSinceModSequence}) =>
      store(sequence, [MessageFlags.deleted],
          action: StoreAction.remove,
          silent: silent,
          unchangedSinceModSequence: unchangedSinceModSequence);

  /// Mark the messages from the specified [sequence] as answered.
  ///
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the
  /// `CONDSTORE` or `QRESYNC` capability
  /// Compare the [store] method in case you need more control or want to
  /// change several flags.
  Future<StoreImapResult> markAnswered(MessageSequence sequence,
          {bool? silent, int? unchangedSinceModSequence}) =>
      store(sequence, [MessageFlags.answered],
          silent: silent, unchangedSinceModSequence: unchangedSinceModSequence);

  /// Mark the messages from the specified [sequence] as not answered.
  ///
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the
  /// `CONDSTORE` or `QRESYNC` capability
  /// Compare the [store] method in case you need more control or want to
  /// change several flags.
  Future<StoreImapResult> markUnanswered(MessageSequence sequence,
          {bool? silent, int? unchangedSinceModSequence}) =>
      store(sequence, [MessageFlags.answered],
          action: StoreAction.remove,
          silent: silent,
          unchangedSinceModSequence: unchangedSinceModSequence);

  /// Mark the messages from the specified [sequence] as forwarded.
  ///
  /// Note this uses the common but not-standardized `$Forwarded` keyword flag.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the
  /// `CONDSTORE` or `QRESYNC` capability
  /// Compare the [store] method in case you need more control or want to
  /// change several flags.
  Future<StoreImapResult> markForwarded(MessageSequence sequence,
          {bool? silent, int? unchangedSinceModSequence}) =>
      store(sequence, [MessageFlags.keywordForwarded],
          silent: silent, unchangedSinceModSequence: unchangedSinceModSequence);

  /// Mark the messages from the specified [sequence] as not forwarded.
  ///
  /// Note this uses the common but not-standardized `$Forwarded` keyword flag.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the
  /// `CONDSTORE` or `QRESYNC` capability
  /// Compare the [store] method in case you need more control or want to
  /// change several flags.
  Future<StoreImapResult> markUnforwarded(MessageSequence sequence,
          {bool? silent, int? unchangedSinceModSequence}) =>
      store(sequence, [MessageFlags.keywordForwarded],
          action: StoreAction.remove,
          silent: silent,
          unchangedSinceModSequence: unchangedSinceModSequence);

  /// Mark the messages from the specified [sequence] as seen/read.
  ///
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the
  /// `CONDSTORE` or `QRESYNC` capability
  /// Compare the [uidStore] method in case you need more control or want to
  /// change several flags.
  Future<StoreImapResult> uidMarkSeen(MessageSequence sequence,
          {bool? silent, int? unchangedSinceModSequence}) =>
      uidStore(sequence, [MessageFlags.seen],
          silent: silent, unchangedSinceModSequence: unchangedSinceModSequence);

  /// Mark the messages from the specified [sequence] as unseen/unread.
  ///
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the
  /// `CONDSTORE` or `QRESYNC` capability
  /// Compare the [uidStore] method in case you need more control or want to
  /// change several flags.
  Future<StoreImapResult> uidMarkUnseen(MessageSequence sequence,
          {bool? silent, int? unchangedSinceModSequence}) =>
      uidStore(sequence, [MessageFlags.seen],
          action: StoreAction.remove,
          silent: silent,
          unchangedSinceModSequence: unchangedSinceModSequence);

  /// Mark the messages from the specified [sequence] as flagged.
  ///
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the
  /// `CONDSTORE` or `QRESYNC` capability
  /// Compare the [uidStore] method in case you need more control or want to
  /// change several flags.
  Future<StoreImapResult> uidMarkFlagged(MessageSequence sequence,
          {bool? silent, int? unchangedSinceModSequence}) =>
      uidStore(sequence, [MessageFlags.flagged],
          silent: silent, unchangedSinceModSequence: unchangedSinceModSequence);

  /// Mark the messages from the specified [sequence] as unflagged.
  ///
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the
  /// `CONDSTORE` or `QRESYNC` capability
  /// Compare the [uidStore] method in case you need more control or want to
  /// change several flags.
  Future<StoreImapResult> uidMarkUnflagged(MessageSequence sequence,
          {bool? silent, int? unchangedSinceModSequence}) =>
      uidStore(sequence, [MessageFlags.flagged],
          action: StoreAction.remove,
          silent: silent,
          unchangedSinceModSequence: unchangedSinceModSequence);

  /// Mark the messages from the specified [sequence] as deleted.
  ///
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the
  /// `CONDSTORE` or `QRESYNC` capability
  /// Compare the [uidStore] method in case you need more control or want to
  /// change several flags.
  Future<StoreImapResult> uidMarkDeleted(MessageSequence sequence,
          {bool? silent, int? unchangedSinceModSequence}) =>
      uidStore(sequence, [MessageFlags.deleted],
          silent: silent, unchangedSinceModSequence: unchangedSinceModSequence);

  /// Mark the messages from the specified [sequence] as not deleted.
  ///
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the
  /// `CONDSTORE` or `QRESYNC` capability
  /// Compare the [uidStore] method in case you need more control or want to
  /// change several flags.
  Future<StoreImapResult> uidMarkUndeleted(MessageSequence sequence,
          {bool? silent, int? unchangedSinceModSequence}) =>
      uidStore(sequence, [MessageFlags.deleted],
          action: StoreAction.remove,
          silent: silent,
          unchangedSinceModSequence: unchangedSinceModSequence);

  /// Mark the messages from the specified [sequence] as answered.
  ///
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the
  /// `CONDSTORE` or `QRESYNC` capability
  /// Compare the [uidStore] method in case you need more control or want to
  /// change several flags.
  Future<StoreImapResult> uidMarkAnswered(MessageSequence sequence,
          {bool? silent, int? unchangedSinceModSequence}) =>
      uidStore(sequence, [MessageFlags.answered],
          silent: silent, unchangedSinceModSequence: unchangedSinceModSequence);

  /// Mark the messages from the specified [sequence] as not answered.
  ///
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the
  /// `CONDSTORE` or `QRESYNC` capability
  /// Compare the [uidStore] method in case you need more control or want to
  /// change several flags.
  Future<StoreImapResult> uidMarkUnanswered(MessageSequence sequence,
          {bool? silent, int? unchangedSinceModSequence}) =>
      uidStore(sequence, [MessageFlags.answered],
          action: StoreAction.remove,
          silent: silent,
          unchangedSinceModSequence: unchangedSinceModSequence);

  /// Mark the messages from the specified [sequence] as forwarded.
  ///
  /// Note this uses the common but not-standardized `$Forwarded` keyword flag.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the
  /// `CONDSTORE` or `QRESYNC` capability
  /// Compare the [uidStore] method in case you need more control or want to
  /// change several flags.
  Future<StoreImapResult> uidMarkForwarded(MessageSequence sequence,
          {bool? silent, int? unchangedSinceModSequence}) =>
      uidStore(sequence, [MessageFlags.keywordForwarded],
          silent: silent, unchangedSinceModSequence: unchangedSinceModSequence);

  /// Mark the messages from the specified [sequence] as not forwarded.
  ///
  /// Note this uses the common but not-standardized `$Forwarded` keyword flag.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to
  /// elements that have not changed since the specified modification sequence.
  /// This is only supported when the server supports the
  /// `CONDSTORE` or `QRESYNC` capability
  /// Compare the [uidStore] method in case you need more control or want to
  /// change several flags.
  Future<StoreImapResult> uidMarkUnforwarded(MessageSequence sequence,
          {bool? silent, int? unchangedSinceModSequence}) =>
      uidStore(sequence, [MessageFlags.keywordForwarded],
          action: StoreAction.remove,
          silent: silent,
          unchangedSinceModSequence: unchangedSinceModSequence);

  /// Trigger a noop (no operation).
  ///
  /// A noop can update the info about the currently selected mailbox
  /// and can be used as a keep alive.
  /// Also compare [idleStart] for starting the IMAP IDLE mode on
  /// compatible servers.
  Future<Mailbox?> noop() {
    final cmd = Command(
      'NOOP',
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    return sendCommand<Mailbox?>(cmd, NoopParser(this, _selectedMailbox));
  }

  /// Trigger a check operation for the server's housekeeping.
  ///
  /// The CHECK command requests a checkpoint of the currently selected
  /// mailbox.  A checkpoint refers to any implementation-dependent
  /// housekeeping associated with the mailbox (e.g., resolving the
  /// server's in-memory state of the mailbox with the state on its
  /// disk) that is not normally executed as part of each command.  A
  /// checkpoint MAY take a non-instantaneous amount of real time to
  /// complete.  If a server implementation has no such housekeeping
  /// considerations, CHECK is equivalent to NOOP.
  ///
  /// There is no guarantee that an EXISTS untagged response will happen
  /// as a result of CHECK.  NOOP, not CHECK, SHOULD be used for new
  /// message polling.
  /// Compare [noop], [idleStart]
  Future<Mailbox?> check() {
    final cmd = Command(
      'CHECK',
      writeTimeout: defaultWriteTimeout,
    );
    return sendCommand<Mailbox?>(cmd, NoopParser(this, _selectedMailbox));
  }

  /// Expunges (deletes) any messages that are marked as deleted.
  ///
  /// The EXPUNGE command permanently removes all messages that have the
  ///  `\Deleted` flag set from the currently selected mailbox.  Before
  /// returning an OK to the client, an untagged EXPUNGE response is
  /// sent for each message that is removed.
  Future<Mailbox?> expunge() {
    final cmd = Command(
      'EXPUNGE',
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    return sendCommand<Mailbox?>(cmd, NoopParser(this, _selectedMailbox));
  }

  /// Expunges (deletes) any messages that are in the specified [sequence]
  /// AND marked as deleted.
  ///
  /// The UID EXPUNGE command permanently removes all messages that have the
  ///  `\Deleted` flag set AND that in the the defined UID-range from the
  /// currently selected mailbox.  Before
  /// returning an OK to the client, an untagged EXPUNGE response is
  /// sent for each message that is removed.
  ///
  /// The `UID EXPUNGE` command is only available for servers that expose the
  /// `UIDPLUS` capability.
  Future<Mailbox?> uidExpunge(MessageSequence sequence) {
    final buffer = StringBuffer()..write('UID EXPUNGE ');
    sequence.render(buffer);
    final cmd = Command(
      buffer.toString(),
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    return sendCommand<Mailbox?>(cmd, NoopParser(this, _selectedMailbox));
  }

  /// Lists all mailboxes in the given [path].
  ///
  /// The [path] default to "", meaning the currently selected mailbox,
  /// if there is none selected, then the root is used.
  ///
  /// When [recursive] is true, then all sub-mailboxes are also listed.
  ///
  /// When specified, [mailboxPatterns] overrides the [recursive] options
  /// and provides a list of mailbox patterns to include.
  ///
  /// The [selectionOptions] allows extended options to be supplied
  /// to the command.
  ///
  /// The [returnOptions] lists the extra results that should be returned
  /// by the extended list enabled servers.
  ///
  /// The LIST command will set the [serverInfo]`.pathSeparator`
  /// as a side-effect.
  Future<List<Mailbox>> listMailboxes(
          {String path = '""',
          bool recursive = false,
          List<String>? mailboxPatterns,
          List<String>? selectionOptions,
          List<ReturnOption>? returnOptions}) =>
      listMailboxesByReferenceAndName(path, recursive ? '*' : '%',
          mailboxPatterns, selectionOptions, returnOptions);

  String _encodeFirstMailboxPath(
      Mailbox? preferred, String? path, Mailbox? third) {
    if (preferred == null && path == null && third == null) {
      throw ImapException(this, 'Invalid mailbox null');
    }
    return _encodeMailboxPath(
        preferred?.encodedPath ?? path ?? third!.encodedPath);
  }

  String _encodeMailboxPath(String path, [bool alwaysQuote = false]) {
    if (_serverInfo.supportsUtf8) {
      if (path.startsWith('\"')) {
        return path;
      }
      return '"$path"';
    }
    final pathSeparator = serverInfo.pathSeparator ?? '/';
    var encodedPath = Mailbox.encode(path, pathSeparator);
    if (encodedPath.contains(' ') ||
        (alwaysQuote && !encodedPath.startsWith('"'))) {
      encodedPath = '"$encodedPath"';
    }
    return encodedPath;
  }

  /// Lists all mailboxes in the path [referenceName] that match
  /// the given [mailboxName] that can contain wildcards.
  ///
  /// If the server exposes the LIST-STATUS capability, a list of attributes
  /// can be provided with [returnOptions].
  /// The LIST command will set the `serverInfo.pathSeparator` as a side-effect
  Future<List<Mailbox>> listMailboxesByReferenceAndName(
      String referenceName, String mailboxName,
      [List<String>? mailboxPatterns,
      List<String>? selectionOptions,
      List<ReturnOption>? returnOptions]) {
    final buffer = StringBuffer('LIST');
    final bool hasSelectionOptions;
    if (selectionOptions != null && selectionOptions.isNotEmpty) {
      hasSelectionOptions = true;
      buffer
        ..write(' (')
        ..write(selectionOptions.join(' '))
        ..write(')');
    } else {
      hasSelectionOptions = false;
    }
    buffer
      ..write(' ')
      ..write(_encodeMailboxPath(referenceName, true));
    final bool hasMailboxPatterns;
    if (mailboxPatterns != null && mailboxPatterns.isNotEmpty) {
      hasMailboxPatterns = true;
      buffer
        ..write(' (')
        ..write(
            mailboxPatterns.map((e) => _encodeMailboxPath(e, true)).join(' '))
        ..write(')');
    } else {
      hasMailboxPatterns = false;
      buffer
        ..write(' ')
        ..write(_encodeMailboxPath(mailboxName, true));
    }
    final bool hasReturnOptions;
    if (returnOptions != null && returnOptions.isNotEmpty) {
      hasReturnOptions = true;
      buffer
        ..write(' RETURN (')
        ..write(returnOptions.join(' '))
        ..write(')');
    } else {
      hasReturnOptions = false;
    }
    final cmd = Command(
      buffer.toString(),
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    final parser = ListParser(serverInfo,
        isExtended:
            hasSelectionOptions || hasMailboxPatterns || hasReturnOptions,
        hasReturnOptions: hasReturnOptions);
    return sendCommand<List<Mailbox>>(cmd, parser);
  }

  /// Lists all subscribed mailboxes
  ///
  /// The [path] default to "", meaning the currently selected mailbox,
  /// if there is none selected, then the root is used.
  /// When [recursive] is true, then all sub-mailboxes are also listed.
  /// The LIST command will set the `serverInfo.pathSeparator` as a side-effect
  Future<List<Mailbox>> listSubscribedMailboxes(
      {String path = '""', bool recursive = false}) {
    // list all folders in that path
    final cmd = Command(
      'LSUB ${_encodeMailboxPath(path)} ${recursive ? '*' : '%'}',
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    final parser = ListParser(serverInfo, isLsubParser: true);
    return sendCommand<List<Mailbox>>(cmd, parser);
  }

  /// Enables the specified [capabilities].
  ///
  /// Example: `await imapClient.enable(['QRESYNC']);`
  ///
  /// The ENABLE command is only valid in the authenticated state,
  /// before any mailbox is selected.
  ///
  /// The server must support the `ENABLE` capability before this call
  /// can be used.
  ///
  /// Compare https://tools.ietf.org/html/rfc5161 for details.
  Future<List<Capability>> enable(List<String> capabilities) {
    final cmd = Command(
      'ENABLE ${capabilities.join(' ')}',
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    final parser = EnableParser(serverInfo);
    return sendCommand<List<Capability>>(cmd, parser);
  }

  /// Selects the specified mailbox.
  ///
  /// This allows future search and fetch calls.
  /// [path] the path or name of the mailbox that should be selected.
  /// Set [enableCondStore] to true if you want to force-enable `CONDSTORE`.
  /// This is only possible when the `CONDSTORE` or `QRESYNC` capability
  /// is supported.
  /// Specify [qresync] parameter in case the server supports the `QRESYNC`
  /// capability and you have known values from the last session.
  /// Note that you need to `ENABLE QRESYNC` first.
  /// Compare [enable]
  Future<Mailbox> selectMailboxByPath(String path,
      {bool enableCondStore = false, QResyncParameters? qresync}) async {
    if (serverInfo.pathSeparator == null) {
      await listMailboxes();
    }
    final pathSeparator = serverInfo.pathSeparator ?? '/';
    final nameSplitIndex = path.lastIndexOf(pathSeparator);
    final name =
        nameSplitIndex == -1 ? path : path.substring(nameSplitIndex + 1);
    final box = Mailbox(
      encodedName: name,
      encodedPath: path,
      pathSeparator: pathSeparator,
      flags: [],
    );
    return selectMailbox(box,
        enableCondStore: enableCondStore, qresync: qresync);
  }

  /// Selects the inbox.
  ///
  /// This allows future search and fetch calls.
  /// Set [enableCondStore] to true if you want to force-enable `CONDSTORE`.
  /// This is only possible when the `CONDSTORE` or
  /// `QRESYNC` capability is supported.
  /// Specify [qresync] parameter in case the server supports the `QRESYNC`
  /// capability and you have known values from the last session.
  /// Note that you need to `ENABLE QRESYNC` first.
  /// Compare [enable]
  Future<Mailbox> selectInbox(
          {bool enableCondStore = false, QResyncParameters? qresync}) =>
      selectMailboxByPath('INBOX',
          enableCondStore: enableCondStore, qresync: qresync);

  /// Selects the specified mailbox.
  ///
  /// This allows future search and fetch calls.
  /// [box] the mailbox that should be selected.
  /// Set [enableCondStore] to true if you want to force-enable `CONDSTORE`.
  /// This is only possible when the `CONDSTORE` or `QRESYNC` capability
  /// is supported.
  /// Specify [qresync] parameter in case the server supports the `QRESYNC`
  /// capability and you have known values from the last session.
  /// Note that you need to `ENABLE QRESYNC` first.
  /// Compare [enable]
  Future<Mailbox> selectMailbox(Mailbox box,
          {bool enableCondStore = false, QResyncParameters? qresync}) =>
      _selectOrExamine('SELECT', box,
          enableCondStore: enableCondStore, qresync: qresync);

  /// Examines the [box] without selecting it.
  ///
  /// Set [enableCondStore] to true if you want to force-enable `CONDSTORE`.
  /// This is only possible when the `CONDSTORE` or `QRESYNC` capability
  /// is supported.
  /// Specify [qresync] parameter in case the server supports the `QRESYNC`
  /// capability and you have known values from the last session.
  /// Note that you need to `ENABLE QRESYNC` first.
  /// Also compare: statusMailbox(Mailbox, StatusFlags)
  /// The EXAMINE command is identical to SELECT and returns the same
  /// output; however, the selected mailbox is identified as read-only.
  /// No changes to the permanent state of the mailbox, including
  /// per-user state, are permitted; in particular, EXAMINE MUST NOT
  /// cause messages to lose the `\Recent` flag.
  /// Compare [enable]
  Future<Mailbox> examineMailbox(Mailbox box,
          {bool enableCondStore = false, QResyncParameters? qresync}) =>
      _selectOrExamine('EXAMINE', box,
          enableCondStore: enableCondStore, qresync: qresync);

  /// implementation for both SELECT as well as EXAMINE
  Future<Mailbox> _selectOrExamine(String command, Mailbox box,
      {bool enableCondStore = false, QResyncParameters? qresync}) {
    final path = '"${box.encodedPath}"';
    final buffer = StringBuffer()
      ..write(command)
      ..write(' ')
      ..write(path);
    if (enableCondStore || qresync != null) {
      buffer.write(' (');
      if (enableCondStore) {
        buffer.write('CONDSTORE');
      }
      if (qresync != null) {
        if (enableCondStore) {
          buffer.write(' ');
        }
        qresync.render(buffer);
      }
      buffer.write(')');
    }
    final parser = SelectParser(box, this);
    _selectedMailbox = box;
    final cmd = Command(
      buffer.toString(),
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    return sendCommand<Mailbox>(cmd, parser);
  }

  /// Closes the currently selected mailbox and triggers an implicit EXPUNGE.
  ///
  /// Compare [selectMailbox]
  /// Compare [unselectMailbox]
  /// Compare [expunge]
  Future<Mailbox?> closeMailbox() {
    if (_selectedMailbox == null) {
      return Future.value();
    }
    final cmd = Command(
      'CLOSE',
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    final parser = NoResponseParser(_selectedMailbox);
    _selectedMailbox = null;
    return sendCommand(cmd, parser);
  }

  /// Closes the currently selected mailbox
  /// without triggering the expunge events.
  ///
  /// Compare [selectMailbox]
  Future<void> unselectMailbox() {
    if (_selectedMailbox == null) {
      return Future.value();
    }
    final cmd = Command(
      'UNSELECT',
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    final parser = NoResponseParser(_selectedMailbox);
    _selectedMailbox = null;
    return sendCommand(cmd, parser);
  }

  /// Searches messages by the given [searchCriteria]
  /// like `'UNSEEN'` or `'RECENT'` or `'FROM sender@domain.com'`.
  ///
  /// When augmented with zero or more [returnOptions], requests an
  /// extended search. Note that the IMAP server needs to support
  /// [ESEARCH](https://tools.ietf.org/html/rfc4731) capability for this.
  /// This request times out after the specified [responseTimeout]
  Future<SearchImapResult> searchMessages(
      {String searchCriteria = 'UNSEEN',
      List<ReturnOption>? returnOptions,
      Duration? responseTimeout}) {
    final parser =
        SearchParser(isUidSearch: false, isExtended: returnOptions != null);
    final buffer = StringBuffer('SEARCH ');
    if (returnOptions != null) {
      buffer
        ..write('RETURN (')
        ..write(returnOptions.join(' '))
        ..write(') ');
    }
    buffer.write(searchCriteria);
    final cmdText = buffer.toString();
    buffer.clear();
    final searchLines = cmdText.split('\n');
    Command cmd;
    if (searchLines.length == 1) {
      cmd = Command(
        cmdText,
        writeTimeout: defaultWriteTimeout,
        responseTimeout: responseTimeout,
      );
    } else {
      cmd = Command.withContinuation(
        searchLines,
        writeTimeout: defaultWriteTimeout,
        responseTimeout: responseTimeout,
      );
    }
    return sendCommand<SearchImapResult>(cmd, parser);
  }

  /// Searches messages with the given [query].
  ///
  /// Specify a [responseTimeout] when a response is expected
  /// within the given time.
  Future<SearchImapResult> searchMessagesWithQuery(SearchQueryBuilder query,
          {Duration? responseTimeout}) =>
      searchMessages(
          searchCriteria: query.toString(), responseTimeout: responseTimeout);

  /// Searches messages by the given [searchCriteria]
  /// like `'UNSEEN'` or `'RECENT'` or `'FROM sender@domain.com'`.
  ///
  /// Is only supported by servers that expose the `UID` capability.
  /// When augmented with zero or more [returnOptions], requests an
  /// extended search.
  /// This request times out after the specified [responseTimeout]
  Future<SearchImapResult> uidSearchMessages(
      {String searchCriteria = 'UNSEEN',
      List<ReturnOption>? returnOptions,
      Duration? responseTimeout}) {
    final parser =
        SearchParser(isUidSearch: true, isExtended: returnOptions != null);
    final buffer = StringBuffer('UID SEARCH ');
    if (returnOptions != null) {
      buffer
        ..write('RETURN (')
        ..write(returnOptions.join(' '))
        ..write(') ');
    }
    buffer.write(searchCriteria);
    final cmdText = buffer.toString();
    buffer.clear();
    final searchLines = cmdText.split('\n');
    Command cmd;
    if (searchLines.length == 1) {
      cmd = Command(
        cmdText,
        writeTimeout: defaultWriteTimeout,
        responseTimeout: responseTimeout,
      );
    } else {
      cmd = Command.withContinuation(
        searchLines,
        writeTimeout: defaultWriteTimeout,
        responseTimeout: responseTimeout,
      );
    }
    return sendCommand<SearchImapResult>(cmd, parser);
  }

  /// Searches messages with the given [query].
  ///
  /// Is only supported by servers that expose the `UID` capability.
  /// Specify a [responseTimeout] when a response is expected within
  /// the given time.
  Future<SearchImapResult> uidSearchMessagesWithQuery(SearchQueryBuilder query,
          {List<ReturnOption>? returnOptions, Duration? responseTimeout}) =>
      uidSearchMessages(
          searchCriteria: query.toString(),
          returnOptions: returnOptions,
          responseTimeout: responseTimeout);

  /// Fetches a single message by the given definition.
  ///
  /// [messageSequenceId] the message sequence ID of the desired message
  /// [fetchContentDefinition] the definition of what should be fetched from
  /// the message, for example `(UID ENVELOPE HEADER[])`, `BODY[]` or
  /// `ENVELOPE`, etc
  /// Specify a [responseTimeout] when a response is expected within the
  /// given time.
  Future<FetchImapResult> fetchMessage(
          int messageSequenceId, String fetchContentDefinition,
          {Duration? responseTimeout}) =>
      fetchMessages(
          MessageSequence.fromId(messageSequenceId), fetchContentDefinition,
          responseTimeout: responseTimeout);

  /// Fetches messages by the given definition.
  ///
  /// [sequence] the sequence IDs of the messages that should be fetched
  /// [fetchContentDefinition] the definition of what should be fetched from
  /// the message, e.g. `(UID ENVELOPE HEADER[])`, `BODY[]` or `ENVELOPE`, etc
  /// Specify the [changedSinceModSequence] in case only messages that have
  /// been changed since the specified modification sequence should be fetched.
  /// Note that this requires the CONDSTORE or QRESYNC server capability.
  /// Specify a [responseTimeout] when a response is expected within the
  /// given time.
  Future<FetchImapResult> fetchMessages(
          MessageSequence sequence, String? fetchContentDefinition,
          {int? changedSinceModSequence, Duration? responseTimeout}) =>
      _fetchMessages(false, 'FETCH', sequence, fetchContentDefinition,
          changedSinceModSequence: changedSinceModSequence,
          responseTimeout: responseTimeout);

  /// FETCH and UID FETCH implementation
  Future<FetchImapResult> _fetchMessages(bool isUidFetch, String command,
      MessageSequence sequence, String? fetchContentDefinition,
      {int? changedSinceModSequence, Duration? responseTimeout}) {
    final cmdText = StringBuffer()
      ..write(command)
      ..write(' ');
    sequence.render(cmdText);
    cmdText
      ..write(' ')
      ..write(fetchContentDefinition);
    if (changedSinceModSequence != null) {
      cmdText
        ..write(' (CHANGEDSINCE ')
        ..write(changedSinceModSequence)
        ..write(')');
    }
    final cmd = Command(
      cmdText.toString(),
      writeTimeout: defaultWriteTimeout,
      responseTimeout: responseTimeout,
    );
    final parser = FetchParser(isUidFetch: isUidFetch);
    return sendCommand<FetchImapResult>(cmd, parser);
  }

  /// Fetches messages by the specified criteria.
  ///
  /// This call is more flexible than [fetchMessages].
  /// [fetchIdsAndCriteria] the requested message IDs and specification of the
  /// requested elements, e.g. '1:* (ENVELOPE)' or
  /// '1:* (FLAGS ENVELOPE) (CHANGEDSINCE 1232232)'.
  /// Specify a [responseTimeout] when a response is expected within
  /// the given time.
  Future<FetchImapResult> fetchMessagesByCriteria(String fetchIdsAndCriteria,
      {Duration? responseTimeout}) {
    final cmd = Command(
      'FETCH $fetchIdsAndCriteria',
      writeTimeout: defaultWriteTimeout,
      responseTimeout: responseTimeout,
    );
    final parser = FetchParser(isUidFetch: false);
    return sendCommand<FetchImapResult>(cmd, parser);
  }

  /// Fetches the specified number of recent messages by the specified criteria.
  ///
  /// [messageCount] optional number of messages that should be fetched,
  /// defaults to 30.
  ///
  /// [criteria] optional fetch criteria of the requested elements, e.g.
  /// '(ENVELOPE BODY.PEEK[])'. Defaults to '(FLAGS BODY[])'.
  ///
  /// Specify a [responseTimeout] when a response is expected within the
  /// given time.
  Future<FetchImapResult> fetchRecentMessages(
      {int messageCount = 30,
      String criteria = '(FLAGS BODY[])',
      Duration? responseTimeout}) {
    final box = _selectedMailbox;
    if (box == null) {
      throw InvalidArgumentException(
          'No mailbox selected - call select() first.');
    }
    final upperMessageSequenceId = box.messagesExists;
    var lowerMessageSequenceId = upperMessageSequenceId - messageCount;
    if (lowerMessageSequenceId < 1) {
      lowerMessageSequenceId = 1;
    }
    return fetchMessages(
        MessageSequence.fromRange(
            lowerMessageSequenceId, upperMessageSequenceId),
        criteria,
        responseTimeout: responseTimeout);
  }

  /// Fetches a single messages identified by the [messageUid]
  ///
  /// [fetchContentDefinition] the definition of what should be fetched from
  /// the message, e.g. 'BODY[]' or 'ENVELOPE', etc.
  ///
  /// Also compare [uidFetchMessagesByCriteria].
  ///
  /// Specify a [responseTimeout] when a response is expected within the
  /// given time.
  Future<FetchImapResult> uidFetchMessage(
          int messageUid, String fetchContentDefinition,
          {Duration? responseTimeout}) =>
      _fetchMessages(true, 'UID FETCH', MessageSequence.fromId(messageUid),
          fetchContentDefinition,
          responseTimeout: responseTimeout);

  /// Fetches messages by the given definition.
  ///
  /// [sequence] the sequence of message UIDs for which messages should
  /// be fetched
  /// [fetchContentDefinition] the definition of what should be fetched from
  /// the message, e.g. 'BODY[]' or 'ENVELOPE', etc
  /// Specify the [changedSinceModSequence] in case only messages that have
  /// been changed since the specified modification sequence should be fetched.
  /// Note that this requires the `CONDSTORE` or `QRESYNC` server capability.
  /// Specify a [responseTimeout] when you expect a response within a the
  /// specified duration.
  /// Also compare [uidFetchMessagesByCriteria].
  Future<FetchImapResult> uidFetchMessages(
          MessageSequence sequence, String? fetchContentDefinition,
          {int? changedSinceModSequence, Duration? responseTimeout}) =>
      _fetchMessages(
        true,
        'UID FETCH',
        sequence,
        fetchContentDefinition,
        changedSinceModSequence: changedSinceModSequence,
        responseTimeout: responseTimeout,
      );

  /// Fetches messages by the specified criteria.
  ///
  /// This call is more flexible than [uidFetchMessages].
  /// [fetchIdsAndCriteria] the requested message UIDs and specification of
  /// the requested elements, e.g. '1232:1234 (ENVELOPE)'.
  /// Specify a [responseTimeout] when a response is expected within the
  /// given time.
  Future<FetchImapResult> uidFetchMessagesByCriteria(String fetchIdsAndCriteria,
      {Duration? responseTimeout}) {
    final cmd = Command(
      'UID FETCH $fetchIdsAndCriteria',
      writeTimeout: defaultWriteTimeout,
      responseTimeout: responseTimeout,
    );
    final parser = FetchParser(isUidFetch: true);
    return sendCommand<FetchImapResult>(cmd, parser);
  }

  /// Appends the specified MIME [message].
  ///
  /// When no [targetMailbox] or [targetMailboxPath] is specified, then the
  /// message will be appended to the currently selected mailbox.
  /// You can specify flags such as `\Seen` or `\Draft` in the [flags] parameter.
  /// Specify a [responseTimeout] when a response is expected within the
  /// given time.
  /// Compare also the [appendMessageText] method.
  Future<GenericImapResult> appendMessage(
    MimeMessage message, {
    List<String>? flags,
    Mailbox? targetMailbox,
    String? targetMailboxPath,
    Duration? responseTimeout,
  }) =>
      appendMessageText(
        message.renderMessage(),
        flags: flags,
        targetMailbox: targetMailbox,
        targetMailboxPath: targetMailboxPath,
        responseTimeout: responseTimeout,
      );

  /// Appends the specified MIME [messageText].
  ///
  /// When no [targetMailbox] or [targetMailboxPath] is specified, then the
  /// message will be appended to the currently selected mailbox.
  /// You can specify flags such as `\Seen` or `\Draft` in the [flags] parameter.
  /// Specify a [responseTimeout] when a response is expected within the
  /// given time.
  /// Compare also the [appendMessage] method.
  Future<GenericImapResult> appendMessageText(
    String messageText, {
    List<String>? flags,
    Mailbox? targetMailbox,
    String? targetMailboxPath,
    Duration? responseTimeout,
  }) {
    final path = _encodeFirstMailboxPath(
        targetMailbox, targetMailboxPath, _selectedMailbox);
    final buffer = StringBuffer()
      ..write('APPEND ')
      ..write(path);
    if (flags != null && flags.isNotEmpty) {
      buffer
        ..write(' (')
        ..write(flags.join(' '))
        ..write(')');
    }
    final numberOfBytes = utf8.encode(messageText).length;
    buffer
      ..write(' {')
      ..write(numberOfBytes)
      ..write('}');
    final cmdText = buffer.toString();
    final cmd = Command.withContinuation([cmdText, messageText],
        responseTimeout: responseTimeout);
    return sendCommand<GenericImapResult>(
        cmd, GenericParser(this, _selectedMailbox));
  }

  /// Retrieves the specified meta data entry.
  ///
  /// [entry] defines the path of the meta data
  /// Optionally specify [mailboxName], the [maxSize] in bytes or the [depth].
  ///
  /// Compare https://tools.ietf.org/html/rfc5464 for details.
  /// Note that errata of the RFC exist.
  Future<List<MetaDataEntry>> getMetaData(String entry,
      {String? mailboxName, int? maxSize, MetaDataDepth? depth}) {
    var cmd = 'GETMETADATA ';
    if (maxSize != null || depth != null) {
      cmd += '(';
    }
    if (maxSize != null) {
      cmd += 'MAXSIZE $maxSize';
    }
    if (depth != null) {
      if (maxSize != null) {
        cmd += ' ';
      }
      cmd += 'DEPTH ';
      switch (depth) {
        case MetaDataDepth.none:
          cmd += '0';
          break;
        case MetaDataDepth.directChildren:
          cmd += '1';
          break;
        case MetaDataDepth.allChildren:
          cmd += 'infinity';
          break;
      }
    }
    if (maxSize != null || depth != null) {
      cmd += ') ';
    }
    cmd += '"${mailboxName ?? ''}" ($entry)';
    final parser = MetaDataParser();
    return sendCommand<List<MetaDataEntry>>(Command(cmd), parser);
  }

  /// Checks if the specified value can be safely send to the IMAP server
  /// just in double-quotes.
  bool _isSafeForQuotedTransmission(String value) =>
      value.length < 80 && !value.contains('"') && !value.contains('\n');

  /// Saves the specified meta data [entry].
  ///
  /// Set [MetaDataEntry.value] to null to delete the specified meta data entry
  /// Compare https://tools.ietf.org/html/rfc5464 for details.
  Future<Mailbox?> setMetaData(MetaDataEntry entry) {
    final valueText = entry.valueText;
    Command cmd;
    final value = entry.value;
    if (value == null || _isSafeForQuotedTransmission(valueText ?? '')) {
      final cmdText = 'SETMETADATA "${entry.mailboxName}" '
          '(${entry.name} '
          '${value == null ? 'NIL' : '"$valueText"'})';
      cmd = Command(cmdText);
    } else {
      // this is a complex command that requires continuation responses
      final setPart = 'SETMETADATA "${entry.mailboxName}" '
          '(${entry.name} {${value.length}}';
      final parts = <String>[setPart, '$valueText)'];
      cmd = Command.withContinuation(parts);
    }
    final parser = NoResponseParser(_selectedMailbox);
    return sendCommand(cmd, parser);
  }

  /// Saves the  given meta data [entries].
  ///
  /// Note that each [MetaDataEntry.mailboxName] is expected to be the same.
  /// Set [MetaDataEntry.value] to null to delete the specified meta data entry
  /// Compare https://tools.ietf.org/html/rfc5464 for details.
  Future<Mailbox?> setMetaDataEntries(List<MetaDataEntry> entries) {
    final parts = <String>[];
    var cmd = StringBuffer()..write('SETMETADATA ');
    var entry = entries.first;
    cmd.write('"${entry.mailboxName}" (');
    for (entry in entries) {
      cmd
        ..write(' ')
        ..write(entry.name)
        ..write(' ');
      final value = entry.value;
      if (value == null) {
        cmd.write('NIL');
      } else if (_isSafeForQuotedTransmission(entry.valueText ?? '')) {
        cmd.write('"${entry.valueText}"');
      } else {
        cmd.write('{${value.length}}');
        parts.add(cmd.toString());
        cmd = StringBuffer()..write(entry.valueText);
      }
    }
    cmd.write(')');
    parts.add(cmd.toString());
    final parser = NoopParser(this, _selectedMailbox);
    Command command;
    if (parts.length == 1) {
      command = Command(parts.first);
    } else {
      command = Command.withContinuation(parts);
    }
    return sendCommand<Mailbox?>(command, parser);
  }

  /// Checks the status of the currently not selected [box].
  ///
  ///  The STATUS command requests the status of the indicated mailbox.
  ///  It does not change the currently selected mailbox, nor does it
  ///  affect the state of any messages in the queried mailbox (in
  ///  particular, STATUS MUST NOT cause messages to lose the \Recent
  ///  flag).
  ///
  ///  The STATUS command provides an alternative to opening a second
  ///  IMAP4rev1 connection and doing an EXAMINE command on a mailbox to
  ///  query that mailbox's status without deselecting the current
  ///  mailbox in the first IMAP4rev1 connection.
  Future<Mailbox> statusMailbox(Mailbox box, List<StatusFlags> flags) {
    final path = '"${box.encodedPath}"';
    final buffer = StringBuffer()
      ..write('STATUS ')
      ..write(path)
      ..write(' (');
    var addSpace = false;
    for (final flag in flags) {
      if (addSpace) {
        buffer.write(' ');
      }
      switch (flag) {
        case StatusFlags.messages:
          buffer.write('MESSAGES');
          break;
        case StatusFlags.recent:
          buffer.write('RECENT');
          break;
        case StatusFlags.uidNext:
          buffer.write('UIDNEXT');
          break;
        case StatusFlags.uidValidity:
          buffer.write('UIDVALIDITY');
          break;
        case StatusFlags.unseen:
          buffer.write('UNSEEN');
          break;
        case StatusFlags.highestModSequence:
          buffer.write('HIGHESTMODSEQ');
          break;
      }
      addSpace = true;
    }
    buffer.write(')');
    final cmd = Command(
      buffer.toString(),
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    final parser = StatusParser(box);
    return sendCommand<Mailbox>(cmd, parser);
  }

  /// Creates a new mailbox with the specified [path]
  Future<Mailbox> createMailbox(String path) async {
    final encodedPath = _encodeMailboxPath(path);
    final cmd = Command(
      'CREATE $encodedPath',
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    final parser = NoopParser(
      this,
      _selectedMailbox ??
          Mailbox(
            encodedName: path,
            encodedPath: path,
            flags: [MailboxFlag.noSelect],
            pathSeparator: serverInfo.pathSeparator ?? '/',
          ),
    );
    await sendCommand<Mailbox?>(cmd, parser);
    final matchingBoxes = await listMailboxes(path: path);
    if (matchingBoxes.isNotEmpty) {
      return matchingBoxes.first;
    }
    throw ImapException(
        this,
        'Unable to find just created mailbox with the path [$path]. '
        'Please report this problem.');
  }

  /// Removes the specified mailbox
  ///
  /// [box] the mailbox to be deleted
  Future<Mailbox> deleteMailbox(Mailbox box) =>
      _sendMailboxCommand('DELETE', box);

  /// Renames the specified mailbox
  ///
  /// [box] the mailbox that should be renamed
  /// [newName] the desired future name of the mailbox
  Future<Mailbox> renameMailbox(Mailbox box, String newName) async {
    final path = '"${box.encodedPath}"';

    final cmd = Command(
      'RENAME $path ${_encodeMailboxPath(newName)}',
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    final response = await sendCommand<Mailbox?>(
      cmd,
      NoopParser(this, _selectedMailbox ?? box),
    );
    if (box.name.toUpperCase() == 'INBOX') {
      /* Renaming INBOX is permitted, and has special behavior.  It moves
        all messages in INBOX to a new mailbox with the given name,
        leaving INBOX empty.  If the server implementation supports
        inferior hierarchical names of INBOX, these are unaffected by a
        rename of INBOX.
        */
      // question: do we need to create a new mailbox
      // and return that one instead?
    }
    return response!;
  }

  /// Subscribes the specified mailbox.
  ///
  /// The mailbox is listed in future LSUB commands,
  /// compare [listSubscribedMailboxes].
  /// [box] the mailbox that is subscribed
  Future<Mailbox> subscribeMailbox(Mailbox box) =>
      _sendMailboxCommand('SUBSCRIBE', box);

  /// Unsubscribes the specified mailbox.
  ///
  /// [box] the mailbox that is unsubscribed
  Future<Mailbox> unsubscribeMailbox(Mailbox box) =>
      _sendMailboxCommand('UNSUBSCRIBE', box);

  Future<Mailbox> _sendMailboxCommand(String command, Mailbox box) async {
    final path = '"${box.encodedPath}"';
    final cmd = Command(
      '$command $path',
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    final result = await sendCommand<Mailbox?>(cmd, NoopParser(this, box));
    return result ?? box;
  }

  /// Switches to IDLE mode.
  ///
  /// Requires a mailbox to be selected and the mail service to support IDLE.
  ///
  /// Compare [idleDone]
  Future<void> idleStart() {
    if (!isConnected) {
      throw ImapException(this, 'idleStart failed: client is not connected');
    }
    if (!isLoggedIn) {
      throw ImapException(this, 'idleStart failed: user not logged in');
    }
    if (_selectedMailbox == null) {
      print('$logName: idleStart(): ERROR: no mailbox selected');
      return Future.value();
    }
    if (_isInIdleMode) {
      logApp('Warning: idleStart() called but client is already in IDLE mode.');
      return Future.value();
    }
    final cmd = Command(
      'IDLE',
      writeTimeout: defaultWriteTimeout,
    );
    final task = CommandTask(cmd, nextId(), NoopParser(this, _selectedMailbox));
    _tasks[task.id] = task;
    _idleCommandTask = task;
    final result = sendCommandTask(task, returnCompleter: false);
    _isInIdleMode = true;
    return result;
  }

  /// Stops the IDLE mode.
  ///
  /// For example after receiving information about a new message to download
  /// the message.
  /// Requires a mailbox to be selected and the mail service to support IDLE.
  ///
  /// Compare [idleStart]
  Future idleDone() async {
    if (!isConnected || !isLoggedIn) {
      throw ImapException(this, 'idleDone(): not connected or logged in!');
    }
    if (!_isInIdleMode) {
      print('$logName: warning: ignore idleDone(): not in IDLE mode');
      return;
    }
    _isInIdleMode = false;
    // as this  is a potential breaking point, give it a timeout:
    await writeText('DONE');
    final completer = _idleCommandTask?.completer;
    if (isLogEnabled && completer == null) {
      logApp(
        'There is no current idleCommandTask or '
        'completer future $_idleCommandTask',
      );
    }
    if (completer != null) {
      completer.timeout(
          defaultResponseTimeout ?? const Duration(seconds: 4), this);
      await completer.future;
    } else {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    _idleCommandTask = null;
  }

  /// Sets the quota [resourceLimits] for the the user / [quotaRoot].
  ///
  /// Optionally define the [quotaRoot] which defaults to `""`.
  /// Note that the server needs to support the [QUOTA](https://tools.ietf.org/html/rfc2087) capability.
  Future<QuotaResult> setQuota(
      {required Map<String, int> resourceLimits, String quotaRoot = '""'}) {
    final quotaRootParameter =
        quotaRoot.contains(' ') ? '"$quotaRoot"' : quotaRoot;
    final buffer = StringBuffer()
      ..write('SETQUOTA ')
      ..write(quotaRootParameter)
      ..write(' (')
      ..write(resourceLimits.entries
          .map((entry) => '${entry.key} ${entry.value}')
          .join(' '))
      ..write(')');
    final cmd = Command(
      buffer.toString(),
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    final parser = QuotaParser();
    return sendCommand<QuotaResult>(cmd, parser);
  }

  /// Retrieves the quota for the user/[quotaRoot].
  ///
  /// Optionally define the [quotaRoot] which defaults to `""`.
  /// Note that the server needs to support the
  /// [QUOTA](https://tools.ietf.org/html/rfc2087) capability.
  Future<QuotaResult> getQuota({String quotaRoot = '""'}) {
    final quotaRootParameter =
        quotaRoot.contains(' ') ? '"$quotaRoot"' : quotaRoot;
    final cmd = Command(
      'GETQUOTA $quotaRootParameter',
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    final parser = QuotaParser();
    return sendCommand<QuotaResult>(cmd, parser);
  }

  /// Retrieves the quota root for the specified [mailboxName]
  /// which defaults to the root `""`.
  ///
  /// Note that the server needs to support the
  /// [QUOTA](https://tools.ietf.org/html/rfc2087) capability.
  Future<QuotaRootResult> getQuotaRoot({String mailboxName = '""'}) {
    final cmd = Command(
      'GETQUOTAROOT ${_encodeMailboxPath(mailboxName)}',
      writeTimeout: defaultWriteTimeout,
      responseTimeout: defaultResponseTimeout,
    );
    final parser = QuotaRootParser();
    return sendCommand<QuotaRootResult>(cmd, parser);
  }

  /// Sorts messages by the given criteria.
  ///
  /// [sortCriteria] the criteria used for sorting the results
  /// like 'ARRIVAL' or 'SUBJECT'.
  ///
  /// [searchCriteria] the criteria like 'UNSEEN' or 'RECENT'.
  ///
  /// [charset] the charset used for the searching criteria.
  ///
  /// When augmented with zero or more [returnOptions], requests an extended
  /// search, in this case the server must support the
  /// [ESORT](https://tools.ietf.org/html/rfc5267) capability.
  /// The server needs to expose the
  /// [SORT](https://tools.ietf.org/html/rfc5256) capability for this
  /// command to work.
  Future<SortImapResult> sortMessages(String sortCriteria,
      [String searchCriteria = 'ALL',
      String charset = 'UTF-8',
      List<ReturnOption>? returnOptions]) {
    final parser =
        SortParser(isUidSort: false, isExtended: returnOptions != null);
    final buffer = StringBuffer('SORT ');
    if (returnOptions != null) {
      buffer
        ..write('RETURN (')
        ..write(returnOptions.join(' '))
        ..write(') ');
    }
    buffer
      ..write('(')
      ..write(sortCriteria)
      ..write(') ')
      ..write(charset)
      ..write(' ')
      ..write(searchCriteria);
    final cmdText = buffer.toString();
    buffer.clear();
    final sortLines = cmdText.split('\n');
    Command cmd;
    if (sortLines.length == 1) {
      cmd = Command(
        cmdText,
        writeTimeout: defaultWriteTimeout,
      );
    } else {
      cmd = Command.withContinuation(
        sortLines,
        writeTimeout: defaultWriteTimeout,
      );
    }
    return sendCommand<SortImapResult>(cmd, parser);
  }

  /// Sorts messages by the given criteria
  ///
  /// [sortCriteria] the criteria used for sorting the results
  /// like 'ARRIVAL' or 'SUBJECT'
  /// [searchCriteria] the criteria like 'UNSEEN' or 'RECENT'
  /// [charset] the charset used for the searching criteria
  /// When augmented with zero or more [returnOptions], requests
  /// an extended search.
  /// The server needs to expose the
  /// [SORT](https://tools.ietf.org/html/rfc5256) capability for this
  /// command to work.
  Future<SortImapResult> uidSortMessages(String sortCriteria,
      [String searchCriteria = 'ALL',
      String charset = 'UTF-8',
      List<ReturnOption>? returnOptions]) {
    final parser =
        SortParser(isUidSort: true, isExtended: returnOptions != null);
    final buffer = StringBuffer('UID SORT ');
    if (returnOptions != null) {
      buffer
        ..write('RETURN (')
        ..write(returnOptions.join(' '))
        ..write(') ');
    }
    buffer
      ..write('(')
      ..write(sortCriteria)
      ..write(') ')
      ..write(charset)
      ..write(' ')
      ..write(searchCriteria);
    final cmdText = buffer.toString();
    buffer.clear();
    final sortLines = cmdText.split('\n');
    Command cmd;
    if (sortLines.length == 1) {
      cmd = Command(
        cmdText,
        writeTimeout: defaultWriteTimeout,
      );
    } else {
      cmd = Command.withContinuation(
        sortLines,
        writeTimeout: defaultWriteTimeout,
      );
    }
    return sendCommand<SortImapResult>(cmd, parser);
  }

  /// Requests the IDs of message threads starting on [since]
  /// using the given [method] (defaults to `ORDEREDSUBJECT`)
  /// and [charset] (defaults to `UTF-8`).
  ///
  /// Optionally set [threadUids] to `true` when you want to receive UIDs
  /// rather than sequence IDs.
  /// You can use this method when the server announces the `THREAD`
  /// capability, in which it also announces the supported methods, e.g.
  /// `THREAD=ORDEREDSUBJECT THREAD=REFERENCES`.
  /// Specify a [responseTimeout] when a response is expected within
  /// the given time.
  /// Compare `ServerInfo.supportsThreading` and
  /// `ServerInfo.supportedThreadingMethods`.
  Future<SequenceNode> threadMessages({
    required DateTime since,
    String method = 'ORDEREDSUBJECT',
    String charset = 'UTF-8',
    bool threadUids = false,
    Duration? responseTimeout,
  }) {
    final buffer = StringBuffer();
    if (threadUids) {
      buffer.write('UID ');
    }
    buffer
      ..write('THREAD ')
      ..write(method)
      ..write(' ')
      ..write(charset)
      ..write(' SINCE ')
      ..write(DateCodec.encodeSearchDate(since));
    return sendCommand(
        Command(
          buffer.toString(),
          writeTimeout: defaultWriteTimeout,
          responseTimeout: responseTimeout,
        ),
        ThreadParser(isUidSequence: threadUids));
  }

  /// Requests the UIDs of message threads starting on [since]
  /// using the given [method] (defaults to `ORDEREDSUBJECT`)
  /// and [charset] (defaults to `UTF-8`).
  ///
  /// You can use this method when the server announces the `THREAD`
  /// capability, in which it also announces the supported methods, e.g.
  /// `THREAD=ORDEREDSUBJECT THREAD=REFERENCES`.
  /// Specify a [responseTimeout] when a response is expected
  /// within the given time.
  /// Compare `ServerInfo.supportsThreading` and
  /// `ServerInfo.supportedThreadingMethods`.
  Future<SequenceNode> uidThreadMessages({
    required DateTime since,
    String method = 'ORDEREDSUBJECT',
    String charset = 'UTF-8',
    Duration? responseTimeout,
  }) =>
      threadMessages(
          method: method,
          charset: charset,
          since: since,
          threadUids: true,
          responseTimeout: responseTimeout);

  /// Retrieves the next session-unique command ID
  String nextId() {
    final id = _lastUsedCommandId++;
    return 'a$id';
  }

  /// Queues the specified [command] for sending to the server.
  ///
  /// The response is parsed using [parser], by default the
  /// completer's future is returned unless you set
  /// [returnCompleter] to `false`.
  Future<T> sendCommand<T>(
    Command command,
    ResponseParser<T> parser, {
    bool returnCompleter = true,
  }) {
    final task = CommandTask<T>(command, nextId(), parser);
    _tasks[task.id] = task;
    queueTask(task);
    if (returnCompleter) {
      return task.completer.future;
    } else {
      return Future<T>.value();
    }
  }

  /// Queues the given [task] for sending to the server.
  ///
  /// By default the
  /// completer's future is returned unless you set
  /// [returnCompleter] to `false`.
  Future<T> sendCommandTask<T>(
    CommandTask<T> task, {
    bool returnCompleter = true,
  }) {
    queueTask(task);
    if (returnCompleter) {
      return task.completer.future;
    } else {
      return Future<T>.value();
    }
  }

  /// Queues the given [task].
  ///
  /// Starts processing the queue automatically when necessary.
  void queueTask(CommandTask task) {
    if (_isInIdleMode && task.command.commandText == 'IDLE') {
      logApp('Ignore duplicate IDLE: $task');
      task.completer.complete();
      return;
    }
    final stashedQueue = _stashedQueue;
    if (!isConnected && stashedQueue != null) {
      logApp('Stashing task $task');
      stashedQueue.add(task);
      return;
    }
    _queue.add(task);
    if (_queue.length == 1) {
      _processQueue();
    }
  }

  Future _processQueue() async {
    // print('$logName: process queue');
    while (_queue.isNotEmpty) {
      final task = _queue[0];
      // print('enough: $logName: process queue task $task');
      await _processTask(task);
      if (_queue.isNotEmpty) {
        _queue.removeAt(0);
      }
    }
  }

  Future _processTask(CommandTask task) async {
    _currentCommandTask = task;
    try {
      await writeText(task.imapRequest, task, task.command.writeTimeout);
    } catch (e, s) {
      log('unable to process task $task: $e $s');
      if (!task.completer.isCompleted) {
        task.completer.completeError(e, s);
      }
      return;
    }
    try {
      final timeout = task.command.responseTimeout;
      task.completer.timeout(timeout, this);
      await task.completer.future;
    } catch (e, s) {
      if (!task.completer.isCompleted) {
        // caller needs to handle any errors:
        logApp('ImapClient._processTask: forward error to completer: $e');
        task.completer.completeError(e, s);
      }
    }
  }

  /// Handles the specified [imapResponse] from the server.
  ///
  /// The response is parsed and processed.
  void onServerResponse(ImapResponse imapResponse) {
    if (isLogEnabled) {
      log(imapResponse, isClient: false);
    }
    final line = imapResponse.parseText;
    //final log = imapResponse.toString().replaceAll("\r\n", "<RT><LF>\n");
    //log("S: $log");

    //log("sub-line: " + line);
    if (line.startsWith('* ')) {
      // this is an untagged response and can be anything
      imapResponse.parseText = line.substring('* '.length);
      onUntaggedResponse(imapResponse);
    } else if (line.startsWith('+ ')) {
      imapResponse.parseText = line.substring('+ '.length);
      onContinuationResponse(imapResponse);
    } else {
      onCommandResult(imapResponse);
    }
  }

  /// Processes the command result response from the server.
  void onCommandResult(ImapResponse imapResponse) {
    final line = imapResponse.parseText;
    final spaceIndex = line.indexOf(' ');
    if (spaceIndex != -1) {
      final commandId = line.substring(0, spaceIndex);
      final task = _tasks[commandId];
      if (task != null) {
        if (task == _currentCommandTask) {
          _currentCommandTask = null;
        }
        imapResponse.parseText = line.substring(spaceIndex + 1);
        final response = task.parse(imapResponse);
        try {
          if (!task.completer.isCompleted) {
            if (response.isOkStatus) {
              task.completer.complete(response.result);
            } else {
              task.completer
                  .completeError(ImapException(this, response.details));
            }
          }
        } catch (e, s) {
          print('Unable to complete task ${task.command.logText}: $e $s');
          print('response: ${imapResponse.parseText}');
          print('result: ${response.result}');
          try {
            task.completer.completeError(ImapException(this, response.details));
          } on Exception {
            // ignore
          }
        }
      } else {
        log('ERROR: no task found for command [$commandId]');
      }
    } else {
      log('unexpected SERVER response: [$imapResponse]');
    }
  }

  /// Handles an untagged response from the server
  void onUntaggedResponse(ImapResponse imapResponse) {
    final task = _currentCommandTask;
    if (task == null || !task.parseUntaggedResponse(imapResponse)) {
      log('untagged not handled: [$imapResponse] by task $task');
    }
  }

  /// Handles an continuation response from the server
  Future onContinuationResponse(ImapResponse imapResponse) async {
    final cmd = _currentCommandTask?.command;
    if (cmd != null) {
      final response = cmd.getContinuationResponse(imapResponse);
      if (response != null) {
        await writeText(response);
        return;
      }
    }
    if (!_isInIdleMode) {
      logApp('continuation not handled: [$imapResponse]');
    }
  }

  /// Closes the connection. Deprecated: use `disconnect()` instead.
  @Deprecated('Use disconnect() instead.')
  Future<dynamic> closeConnection() {
    logApp('Closing socket for host ${serverInfo.host}');
    return disconnect();
  }

  /// Remembers the queued tasks until [applyStashedTasks] is called.
  ///
  /// Compare [applyStashedTasks]
  void stashQueuedTasks() {
    _stashedQueue = [..._queue];
    _queue.clear();
  }

  /// Applies the stashed tasks
  ///
  /// Compare [stashQueuedTasks]
  Future<void> applyStashedTasks() async {
    final stash = _stashedQueue;
    _stashedQueue = null;
    if (stash != null) {
      for (final task in stash) {
        final text = task.command.commandText;
        try {
          if (text == 'IDLE') {
            if (!task.completer.isCompleted) {
              task.completer.complete();
            }
          } else if (text == 'DONE') {
            final completer = _idleCommandTask?.completer;
            if (completer != null && !completer.isCompleted) {
              completer.complete();
            }
            if (!task.completer.isCompleted) {
              task.completer.complete();
            }
          } else if (text == 'NOOP') {
            if (!task.completer.isCompleted) {
              task.completer.complete(_selectedMailbox);
            }
          } else {
            await _processTask(task);
          }
        } catch (e, s) {
          print('Unable to apply stashed command $text: $e $s');
        }
      }
    }
  }

  @override
  Object createClientError(String message) => ImapException(this, message);
}
