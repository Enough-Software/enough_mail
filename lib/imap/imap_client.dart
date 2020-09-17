import 'dart:convert';
import 'dart:io';
import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/imap/message_sequence.dart';
import 'package:enough_mail/imap/metadata.dart';
import 'package:enough_mail/src/imap/quota_parser.dart';
import 'package:enough_mail/src/imap/response_parser.dart';
import 'package:event_bus/event_bus.dart';
import 'package:enough_mail/imap/mailbox.dart';
import 'package:enough_mail/mime_message.dart';
import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/capability_parser.dart';
import 'package:enough_mail/src/imap/command.dart';
import 'package:enough_mail/src/imap/all_parsers.dart';
import 'package:enough_mail/src/imap/imap_response.dart';
import 'package:enough_mail/src/imap/imap_response_reader.dart';

import 'imap_events.dart';

/// Describes a capability
class Capability {
  String name;
  Capability(this.name);

  @override
  String toString() {
    return name;
  }

  @override
  bool operator ==(o) => o is Capability && o.name == name;
}

/// Keeps information about the remote IMAP server
///
/// Persist this information to improve initialization times.
class ImapServerInfo {
  String host;
  bool isSecure;
  int port;
  String pathSeparator;
  String capabilitiesText;
  List<Capability> capabilities;
  List<Capability> enabledCapabilities = <Capability>[];

  /// Checks if the capability with the specified [capabilityName] is supported.
  bool supports(String capabilityName) {
    return (capabilities?.firstWhere((c) => c.name == capabilityName,
            orElse: () => null) !=
        null);
  }

  /// Checks if the capability with the specified [capabilityName] has been enabled.
  bool isEnabled(String capabilityName) {
    return (enabledCapabilities?.firstWhere((c) => c.name == capabilityName,
            orElse: () => null) !=
        null);
  }
}

enum StoreAction { add, remove, replace }

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

  /// The highest mod-sequence value of all messages in the mailbox. Only available when the CONDSTORE or QRESYNC capability is supported.
  highestModSequence
}

/// Low-level IMAP library.
///
/// Compliant to IMAP4rev1 standard [RFC 3501](https://tools.ietf.org/html/rfc3501).
/// Also compare recommendations at [RFC 2683](https://tools.ietf.org/html/rfc2683)
class ImapClient {
  /// Information about the IMAP service
  ImapServerInfo serverInfo;

  /// Allows to listens for events
  ///
  /// If no event bus is specified in the constructor, an aysnchronous bus is used.
  /// Usage:
  /// ```
  /// eventBus.on<ImapExpungeEvent>().listen((event) {
  ///   // All events are of type ImapExpungeEvent (or subtypes of it).
  ///   _log(event.messageSequenceId);
  /// });
  ///
  /// eventBus.on<ImapEvent>().listen((event) {
  ///   // All events are of type ImapEvent (or subtypes of it).
  ///   _log(event.eventType);
  /// });
  /// ```
  EventBus get eventBus => _eventBus;
  EventBus _eventBus;

  bool _isSocketClosingExpected = false;

  /// Checks if a user is currently signed in.
  bool get isLoggedIn => _isLoggedIn;

  /// Checks if a user is currently not signed in.
  bool get isNotLoggedIn => !_isLoggedIn;

  bool _isLoggedIn = false;
  Socket _socket;
  int _lastUsedCommandId = 0;
  CommandTask _currentCommandTask;
  final Map<String, CommandTask> _tasks = <String, CommandTask>{};
  Mailbox _selectedMailbox;
  bool _isLogEnabled;
  ImapResponseReader _imapResponseReader;

  bool _isInIdleMode = false;

  /// Creates a new instance with the optional [bus] event bus.
  ///
  /// Compare [eventBus] for more information.
  ImapClient({EventBus bus, bool isLogEnabled = false}) {
    bus ??= EventBus();
    _eventBus = bus;
    _isLogEnabled = isLogEnabled ?? false;
    _imapResponseReader = ImapResponseReader(onServerResponse);
  }

  /// Connects to the specified server.
  ///
  /// Specify [isSecure] if you do not want to connect to a secure service.
  Future<Socket> connectToServer(String host, int port,
      {bool isSecure = true}) async {
    serverInfo = ImapServerInfo()
      ..host = host
      ..port = port
      ..isSecure = isSecure;
    _log(
        'Connecting to $host:$port ${isSecure ? '' : 'NOT'} using a secure socket...');

    var socket = isSecure
        ? await SecureSocket.connect(host, port)
        : await Socket.connect(host, port);
    _log('Socket connected.');
    connect(socket);
    return socket;
  }

  /// Starts to listen on [socket].
  ///
  /// This is mainly useful for testing purposes, ensure to set [serverInfo] manually in this  case.
  void connect(Socket socket) {
    socket.listen(_imapResponseReader.onData, onDone: () {
      _isLoggedIn = false;
      _log('Done, connection closed');
      if (!_isSocketClosingExpected) {
        eventBus.fire(ImapConnectionLostEvent(this));
      }
    }, onError: (e, s) {
      _isLoggedIn = false;
      _log('Socket error: $e');
      print(s);
      if (!_isSocketClosingExpected) {
        _isSocketClosingExpected = true;
        eventBus.fire(ImapConnectionLostEvent(this));
      }
    });
    _isSocketClosingExpected = false;
    _socket = socket;
  }

  /// Logs the specified user in with the given [name] and [password].
  Future<Response<List<Capability>>> login(String name, String password) async {
    var quote = name.contains(' ') || password.contains(' ');
    var cmd =
        Command(quote ? 'LOGIN "$name" "$password"' : 'LOGIN $name $password');
    cmd.logText = 'LOGIN $name (password scrambled)';
    var parser = CapabilityParser(serverInfo);
    var response = await sendCommand<List<Capability>>(cmd, parser);
    _isLoggedIn = response.isOkStatus;
    return response;
  }

  /// Logs in the user with the given [user] and [accessToken] via Oauth 2.0.
  /// Note that the capability 'AUTH=XOAUTH2' needs to be present.
  Future<Response<GenericImapResult>> authenticateWithOAuth2(
      String user, String accessToken) async {
    var authText = 'user=$user\u{0001}auth=Bearer $accessToken\u{0001}\u{0001}';
    var authBase64Text = base64.encode(utf8.encode(authText));
    var cmd = Command('AUTHENTICATE XOAUTH2 $authBase64Text');
    cmd.logText = 'AUTHENTICATE XOAUTH (base64 code scrambled)';
    var response = await sendCommand<GenericImapResult>(cmd, GenericParser());
    _isLoggedIn = response.isOkStatus;
    return response;
  }

  /// Logs in the user with the given [user] and [accessToken] via Oauth Bearer mechanism.
  /// Optionally specify the [host] and [port] of the service, per default the current connection is used.
  /// Note that the capability 'AUTH=OAUTHBEARER' needs to be present.
  /// Compare https://tools.ietf.org/html/rfc7628 for details
  Future<Response<GenericImapResult>> authenticateWithOAuthBearer(
      String user, String accessToken,
      {String host, int port}) async {
    host ??= serverInfo.host;
    port ??= serverInfo.port;
    var authText =
        'n,u=$user,\u{0001}host=$host\u{0001}port=$port\u{0001}auth=Bearer $accessToken\u{0001}\u{0001}';
    var authBase64Text = base64.encode(utf8.encode(authText));
    var cmd = Command('AUTHENTICATE OAUTHBEARER $authBase64Text');
    cmd.logText = 'AUTHENTICATE OAUTHBEARER (base64 code scrambled)';
    var response = await sendCommand<GenericImapResult>(cmd, GenericParser());
    _isLoggedIn = response.isOkStatus;
    return response;
  }

  /// Logs the current user out.
  Future<Response<String>> logout() async {
    var cmd = Command('LOGOUT');
    var response = await sendCommand<String>(cmd, LogoutParser());
    _isLoggedIn = false;
    return response;
  }

  /// Upgrades the current insure connection to SSL.
  ///
  /// Opportunistic TLS (Transport Layer Security) refers to extensions
  /// in plain text communication protocols, which offer a way to upgrade a plain text connection
  /// to an encrypted (TLS or SSL) connection instead of using a separate port for encrypted communication.
  Future<Response<GenericImapResult>> startTls() async {
    var cmd = Command('STARTTLS');
    var response = await sendCommand<GenericImapResult>(cmd, GenericParser());
    if (response.isOkStatus) {
      _log('STARTTL: upgrading socket to secure one...');
      var secureSocket = await SecureSocket.secure(_socket);
      if (secureSocket != null) {
        _log('STARTTL: now using secure connection.');
        _isSocketClosingExpected = true;
        await _socket.close();
        await _socket.destroy();
        _isSocketClosingExpected = false;
        connect(secureSocket);
      }
    }
    return response;
  }

  /// Checks the capabilities of this server directly
  Future<Response<List<Capability>>> capability() {
    var cmd = Command('CAPABILITY');
    var parser = CapabilityParser(serverInfo);
    return sendCommand<List<Capability>>(cmd, parser);
  }

  /// Copies the specified message(s) from the specified [sequence] from the currently selected mailbox to the target mailbox.
  /// You can either specify the [targetMailbox] or the [targetMailboxPath], if none is given, the messages will be copied to the currently selected mailbox.
  /// Compare [selectMailbox()], [selectMailboxByPath()] or [selectInbox()] for selecting a mailbox first.
  /// Compare [uidCopy()] for the copying files based on their sequence IDs
  Future<Response<GenericImapResult>> copy(MessageSequence sequence,
      {Mailbox targetMailbox, String targetMailboxPath}) {
    return _copyOrMove('COPY', sequence,
        targetMailbox: targetMailbox, targetMailboxPath: targetMailboxPath);
  }

  /// Copies the specified message(s) from the specified [sequence] from the currently selected mailbox to the target mailbox.
  /// You can either specify the [targetMailbox] or the [targetMailboxPath], if none is given, the messages will be copied to the currently selected mailbox.
  /// Compare [selectMailbox()], [selectMailboxByPath()] or [selectInbox()] for selecting a mailbox first.
  /// Compare [copy()] for the version with message sequence IDs
  Future<Response<GenericImapResult>> uidCopy(MessageSequence sequence,
      {Mailbox targetMailbox, String targetMailboxPath}) {
    return _copyOrMove('UID COPY', sequence,
        targetMailbox: targetMailbox, targetMailboxPath: targetMailboxPath);
  }

  /// Moves the specified message(s) from the specified [sequence] from the currently selected mailbox to the target mailbox.
  /// You must either specify the [targetMailbox] or the [targetMailboxPath], if none is given, move will fail.
  /// Compare [selectMailbox()], [selectMailboxByPath()] or [selectInbox()] for selecting a mailbox first.
  /// Compare [uidMove()] for moving messages based on their UID
  /// The move command is only available for servers that advertise the MOVE capability.
  Future<Response<GenericImapResult>> move(MessageSequence sequence,
      {Mailbox targetMailbox, String targetMailboxPath}) {
    if (targetMailbox == null && targetMailboxPath == null) {
      throw StateError(
          'move() error: Neither targetMailbox nor targetMailboxPath defined.');
    }
    return _copyOrMove('MOVE', sequence,
        targetMailbox: targetMailbox, targetMailboxPath: targetMailboxPath);
  }

  /// Copies the specified message(s) from the specified [sequence] from the currently selected mailbox to the target mailbox.
  /// You must either specify the [targetMailbox] or the [targetMailboxPath], if none is given, move will fail.
  /// Compare [selectMailbox()], [selectMailboxByPath()] or [selectInbox()] for selecting a mailbox first.
  /// Compare [copy()] for the version with message sequence IDs
  Future<Response<GenericImapResult>> uidMove(MessageSequence sequence,
      {Mailbox targetMailbox, String targetMailboxPath}) {
    if (targetMailbox == null && targetMailboxPath == null) {
      throw StateError(
          'uidMove() error: Neither targetMailbox nor targetMailboxPath defined.');
    }
    return _copyOrMove('UID MOVE', sequence,
        targetMailbox: targetMailbox, targetMailboxPath: targetMailboxPath);
  }

  /// Implementation for both COPY or MOVE
  Future<Response<GenericImapResult>> _copyOrMove(
      String command, MessageSequence sequence,
      {Mailbox targetMailbox, String targetMailboxPath}) {
    if (_selectedMailbox == null) {
      throw StateError('No mailbox selected.');
    }
    var buffer = StringBuffer()..write(command)..write(' ');
    sequence.render(buffer);
    var path = _encodeMailboxPath(
        targetMailbox?.path ?? targetMailboxPath ?? _selectedMailbox.path);
    buffer..write(' ')..write(path);
    var cmd = Command(buffer.toString());
    return sendCommand<GenericImapResult>(cmd, GenericParser());
  }

  /// Updates the [flags] of the message(s) from the specified [sequence] in the currently selected mailbox.
  /// Set [silent] to true, if the updated flags should not be returned.
  /// Specify if flags should be replaced, added or removed with the [action] parameter, this defaults to adding flags.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// When there are modified elements that have not passed the [unchangedSinceModSequence] test, then the 'modified' attribute  of the response contains the List<int> with the IDs of messages that have not been updated.
  /// Compare [selectMailbox()], [selectMailboxByPath()] or [selectInbox()] for selecting a mailbox first.
  /// Compare the methods [markSeen()], [markFlagged()], etc for typical store operations.
  Future<Response<StoreImapResult>> store(
      MessageSequence sequence, List<String> flags,
      {StoreAction action, bool silent, int unchangedSinceModSequence}) {
    return _store('STORE', sequence, flags,
        action: action,
        silent: silent,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Updates the [flags] of the message(s) from the specified [sequence] in the currently selected mailbox.
  /// Set [silent] to true, if the updated flags should not be returned.
  /// Specify if flags should be replaced, added or removed with the [action] parameter, this defaults to adding flags.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare [selectMailbox()], [selectMailboxByPath()] or [selectInbox()] for selecting a mailbox first.
  /// Compare the methods [uidMarkSeen()], [uidMarkFlagged()], etc for typical store operations.
  Future<Response<StoreImapResult>> uidStore(
      MessageSequence sequence, List<String> flags,
      {StoreAction action, bool silent, int unchangedSinceModSequence}) {
    return _store('UID STORE', sequence, flags,
        action: action,
        silent: silent,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// STORE and UID STORE implementation
  Future<Response<StoreImapResult>> _store(
      String command, MessageSequence sequence, List<String> flags,
      {StoreAction action, bool silent, int unchangedSinceModSequence}) async {
    if (_selectedMailbox == null) {
      throw StateError('No mailbox selected.');
    }
    action ??= StoreAction.add;
    silent ??= false;
    var buffer = StringBuffer()..write(command)..write(' ');
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
    for (var flag in flags) {
      if (addSpace) {
        buffer.write(' ');
      }
      buffer.write(flag);
      addSpace = true;
    }
    buffer.write(')');
    var cmd = Command(buffer.toString());
    var parser = FetchParser();
    var messagesResponse = await sendCommand<FetchImapResult>(cmd, parser);
    var response = Response<StoreImapResult>()
      ..status = messagesResponse.status
      ..details = messagesResponse.details;
    var result = StoreImapResult()
      ..changedMessages = messagesResponse.result?.messages
      ..modifiedMessageIds = messagesResponse.attributes != null
          ? messagesResponse.attributes['modified']
          : null;
    response.result = result;
    return response;
  }

  /// Convenience method for marking the messages from the specified [sequence] as seen/read.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store()] method in case you need more control or want to change several flags.
  Future<Response<StoreImapResult>> markSeen(MessageSequence sequence,
      {bool silent, int unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.seen],
        silent: silent, unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as unseen/unread.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store()] method in case you need more control or want to change several flags.
  Future<Response<StoreImapResult>> markUnseen(MessageSequence sequence,
      {bool silent, int unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.seen],
        action: StoreAction.remove,
        silent: silent,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as flagged.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store()] method in case you need more control or want to change several flags.
  Future<Response<StoreImapResult>> markFlagged(MessageSequence sequence,
      {bool silent, int unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.flagged],
        silent: silent, unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as unflagged.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store()] method in case you need more control or want to change several flags.
  Future<Response<StoreImapResult>> markUnflagged(MessageSequence sequence,
      {bool silent, int unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.flagged],
        action: StoreAction.remove,
        silent: silent,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as deleted.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store()] method in case you need more control or want to change several flags.
  Future<Response<StoreImapResult>> markDeleted(MessageSequence sequence,
      {bool silent, int unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.deleted],
        silent: silent, unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as not deleted.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store()] method in case you need more control or want to change several flags.
  Future<Response<StoreImapResult>> markUndeleted(MessageSequence sequence,
      {bool silent, int unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.deleted],
        action: StoreAction.remove,
        silent: silent,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as answered.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [uidStore()] method in case you need more control or want to change several flags.
  Future<Response<StoreImapResult>> markAnswered(MessageSequence sequence,
      {bool silent, int unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.answered],
        silent: silent, unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as not answered.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [uidStore()] method in case you need more control or want to change several flags.
  Future<Response<StoreImapResult>> markUnanswered(MessageSequence sequence,
      {bool silent, int unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.answered],
        action: StoreAction.remove,
        silent: silent,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as forwarded.
  /// Note this uses the common but not-standarized `$Forwarded` keyword flag.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store()] method in case you need more control or want to change several flags.
  Future<Response<StoreImapResult>> markForwarded(MessageSequence sequence,
      {bool silent, int unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.keywordForwarded],
        silent: silent, unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as not forwarded.
  /// Note this uses the common but not-standarized `$Forwarded` keyword flag.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store()] method in case you need more control or want to change several flags.
  Future<Response<StoreImapResult>> markUnforwarded(MessageSequence sequence,
      {bool silent, int unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.keywordForwarded],
        action: StoreAction.remove,
        silent: silent,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as seen/read.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [uidStore()] method in case you need more control or want to change several flags.
  Future<Response<StoreImapResult>> uidMarkSeen(MessageSequence sequence,
      {bool silent, int unchangedSinceModSequence}) {
    return uidStore(sequence, [MessageFlags.seen],
        silent: silent, unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as unseen/unread.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [uidStore()] method in case you need more control or want to change several flags.
  Future<Response<StoreImapResult>> uidMarkUnseen(MessageSequence sequence,
      {bool silent, int unchangedSinceModSequence}) {
    return uidStore(sequence, [MessageFlags.seen],
        action: StoreAction.remove,
        silent: silent,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as flagged.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [uidStore()] method in case you need more control or want to change several flags.
  Future<Response<StoreImapResult>> uidMarkFlagged(MessageSequence sequence,
      {bool silent, int unchangedSinceModSequence}) {
    return uidStore(sequence, [MessageFlags.flagged],
        silent: silent, unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as unflagged.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [uidStore()] method in case you need more control or want to change several flags.
  Future<Response<StoreImapResult>> uidMarkUnflagged(MessageSequence sequence,
      {bool silent, int unchangedSinceModSequence}) {
    return uidStore(sequence, [MessageFlags.flagged],
        action: StoreAction.remove,
        silent: silent,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as deleted.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [uidStore()] method in case you need more control or want to change several flags.
  Future<Response<StoreImapResult>> uidMarkDeleted(MessageSequence sequence,
      {bool silent, int unchangedSinceModSequence}) {
    return uidStore(sequence, [MessageFlags.deleted],
        silent: silent, unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as not deleted.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [uidStore()] method in case you need more control or want to change several flags.
  Future<Response<StoreImapResult>> uidMarkUndeleted(MessageSequence sequence,
      {bool silent, int unchangedSinceModSequence}) {
    return uidStore(sequence, [MessageFlags.deleted],
        action: StoreAction.remove,
        silent: silent,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as answered.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [uidStore()] method in case you need more control or want to change several flags.
  Future<Response<StoreImapResult>> uidMarkAnswered(MessageSequence sequence,
      {bool silent, int unchangedSinceModSequence}) {
    return uidStore(sequence, [MessageFlags.answered],
        silent: silent, unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as not answered.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [uidStore()] method in case you need more control or want to change several flags.
  Future<Response<StoreImapResult>> uidMarkUnanswered(MessageSequence sequence,
      {bool silent, int unchangedSinceModSequence}) {
    return uidStore(sequence, [MessageFlags.answered],
        action: StoreAction.remove,
        silent: silent,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as forwarded.
  /// Note this uses the common but not-standarized `$Forwarded` keyword flag.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [uidStore()] method in case you need more control or want to change several flags.
  Future<Response<StoreImapResult>> uidMarkForwarded(MessageSequence sequence,
      {bool silent, int unchangedSinceModSequence}) {
    return uidStore(sequence, [MessageFlags.keywordForwarded],
        silent: silent, unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as not forwarded.
  /// Note this uses the common but not-standarized `$Forwarded` keyword flag.
  /// Set [silent] to true in case the updated flags are of no interest.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [uidStore()] method in case you need more control or want to change several flags.
  Future<Response<StoreImapResult>> uidMarkUnforwarded(MessageSequence sequence,
      {bool silent, int unchangedSinceModSequence}) {
    return uidStore(sequence, [MessageFlags.keywordForwarded],
        action: StoreAction.remove,
        silent: silent,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Trigger a noop (no operation).
  ///
  /// A noop can update the info about the currently selected mailbox and can be used as a keep alive.
  /// Also compare [idleStart] for starting the IMAP IDLE mode on compatible servers.
  Future<Response<Mailbox>> noop() {
    var cmd = Command('NOOP');
    return sendCommand<Mailbox>(cmd, NoopParser(this, _selectedMailbox));
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
  /// Compare [noop()], [idleStart()]
  Future<Response<Mailbox>> check() {
    var cmd = Command('CHECK');
    return sendCommand<Mailbox>(cmd, NoopParser(this, _selectedMailbox));
  }

  /// Expunges (deletes) any messages that are marked as deleted.
  ///
  /// The EXPUNGE command permanently removes all messages that have the
  ///  \Deleted flag set from the currently selected mailbox.  Before
  /// returning an OK to the client, an untagged EXPUNGE response is
  /// sent for each message that is removed.
  Future<Response<Mailbox>> expunge() {
    var cmd = Command('EXPUNGE');
    return sendCommand<Mailbox>(cmd, NoopParser(this, _selectedMailbox));
  }

  /// Expunges (deletes) any messages that are in the specified [sequence] AND marked as deleted.
  ///
  /// The UID EXPUNGE command permanently removes all messages that have the
  ///  \Deleted flag set AND that in the the defined UID-range from the currently selected mailbox.  Before
  /// returning an OK to the client, an untagged EXPUNGE response is
  /// sent for each message that is removed.
  ///
  /// The UID EXPUNGE command is only available for servers that expose the UIDPLUS capability.
  Future<Response<Mailbox>> uidExpunge(MessageSequence sequence) {
    var buffer = StringBuffer()..write('UID EXPUNGE ');
    sequence.render(buffer);
    var cmd = Command(buffer.toString());
    return sendCommand<Mailbox>(cmd, NoopParser(this, _selectedMailbox));
  }

  /// lists all mailboxes in the given [path].
  ///
  /// The [path] default to "", meaning the currently selected mailbox, if there is none selected, then the root is used.
  /// When [recursive] is true, then all submailboxes are also listed.
  /// The LIST command will set the [serverInfo.pathSeparator] as a side-effect
  Future<Response<List<Mailbox>>> listMailboxes(
      {String path = '""', bool recursive = false}) {
    return listMailboxesByReferenceAndName(
        path, (recursive ? '*' : '%')); // list all folders in that path
  }

  String _encodeMailboxPath(String path) {
    var encodedPath =
        (serverInfo.isEnabled('UTF8=ACCEPT')) ? path : Mailbox.encode(path);
    if (encodedPath.contains(' ')) {
      encodedPath = '"$encodedPath"';
    }
    return encodedPath;
  }

  /// lists all mailboxes in the path [referenceName] that match the given [mailboxName] that can contain wildcards.
  ///
  /// The LIST command will set the [serverInfo.pathSeparator] as a side-effect
  Future<Response<List<Mailbox>>> listMailboxesByReferenceAndName(
      String referenceName, String mailboxName) {
    referenceName = _encodeMailboxPath(referenceName);
    mailboxName = _encodeMailboxPath(mailboxName);
    var cmd = Command('LIST $referenceName $mailboxName');
    var parser = ListParser(serverInfo);
    return sendCommand<List<Mailbox>>(cmd, parser);
  }

  /// Lists all subscribed mailboxes
  ///
  /// The [path] default to "", meaning the currently selected mailbox, if there is none selected, then the root is used.
  /// When [recursive] is true, then all submailboxes are also listed.
  /// The LIST command will set the [serverInfo.pathSeparator] as a side-effect
  Future<Response<List<Mailbox>>> listSubscribedMailboxes(
      {String path = '""', bool recursive = false}) {
    path = _encodeMailboxPath(path);
    var cmd = Command('LSUB $path ' +
        (recursive ? '*' : '%')); // list all folders in that path
    var parser = ListParser(serverInfo, isLsubParser: true);
    return sendCommand<List<Mailbox>>(cmd, parser);
  }

  /// Enables the specified capabilities.
  /// Example: `await imapClient.enable(['QRESYNC']);`
  /// The ENABLE command is only valid in the authenticated state, before any mailbox is selected.
  /// The server must sipport the `ENABLE` capability before this call can be used.
  /// Compare https://tools.ietf.org/html/rfc5161 for details.
  Future<Response<List<Capability>>> enable(List<String> capabilities) {
    var cmd = Command('ENABLE ' + capabilities.join(' '));
    var parser = EnableParser(serverInfo);
    return sendCommand<List<Capability>>(cmd, parser);
  }

  /// Selects the specified mailbox.
  ///
  /// This allows future search and fetch calls.
  /// [path] the path or name of the mailbox that should be selected.
  /// Set [enableCondStore] to true if you want to force-enable CONDSTORE. This is only possible when the CONDSTORE or QRESYNC capability is supported.
  /// Specify [qresync] parameter in case the server supports the QRESYNC capability and you have known values from the last session. Note that you need to ENABLE QRESYNC first.
  Future<Response<Mailbox>> selectMailboxByPath(String path,
      {bool enableCondStore = false, QResyncParameters qresync}) async {
    if (serverInfo?.pathSeparator == null) {
      await listMailboxes();
    }
    var nameSplitIndex = path.lastIndexOf(serverInfo.pathSeparator);
    var name = nameSplitIndex == -1 ? path : path.substring(nameSplitIndex + 1);
    var box = Mailbox()
      ..path = path
      ..name = name;
    return selectMailbox(box,
        enableCondStore: enableCondStore, qresync: qresync);
  }

  /// Selects the inbox.
  ///
  /// This allows future search and fetch calls.
  /// Set [enableCondStore] to true if you want to force-enable CONDSTORE. This is only possible when the CONDSTORE or QRESYNC capability is supported.
  /// Specify [qresync] parameter in case the server supports the QRESYNC capability and you have known values from the last session. Note that you need to ENABLE QRESYNC first.
  Future<Response<Mailbox>> selectInbox(
      {bool enableCondStore = false, QResyncParameters qresync}) {
    return selectMailboxByPath('INBOX',
        enableCondStore: enableCondStore, qresync: qresync);
  }

  /// Selects the specified mailbox.
  ///
  /// This allows future search and fetch calls.
  /// [box] the mailbox that should be selected.
  /// Set [enableCondStore] to true if you want to force-enable CONDSTORE. This is only possible when the CONDSTORE or QRESYNC capability is supported.
  /// Specify [qresync] parameter in case the server supports the QRESYNC capability and you have known values from the last session. Note that you need to ENABLE QRESYNC first.
  Future<Response<Mailbox>> selectMailbox(Mailbox box,
      {bool enableCondStore = false, QResyncParameters qresync}) {
    return _selectOrExamine('SELECT', box,
        enableCondStore: enableCondStore, qresync: qresync);
  }

  /// Examines the [box] without selecting it.
  /// Set [enableCondStore] to true if you want to force-enable CONDSTORE. This is only possible when the CONDSTORE or QRESYNC capability is supported.
  /// Specify [qresync] parameter in case the server supports the QRESYNC capability and you have known values from the last session. Note that you need to ENABLE QRESYNC first.
  /// Also compare: statusMailbox(Mailbox, StatusFlags)
  /// The EXAMINE command is identical to SELECT and returns the same
  /// output; however, the selected mailbox is identified as read-only.
  /// No changes to the permanent state of the mailbox, including
  /// per-user state, are permitted; in particular, EXAMINE MUST NOT
  /// cause messages to lose the \Recent flag.
  Future<Response<Mailbox>> examineMailbox(Mailbox box,
      {bool enableCondStore = false, QResyncParameters qresync}) {
    return _selectOrExamine('EXAMINE', box,
        enableCondStore: enableCondStore, qresync: qresync);
  }

  /// implementation for both SELECT as well as EXAMINE
  Future<Response<Mailbox>> _selectOrExamine(String command, Mailbox box,
      {bool enableCondStore = false, QResyncParameters qresync}) {
    var path = _encodeMailboxPath(box.path);
    var buffer = StringBuffer()..write(command)..write(' ')..write(path);
    if (enableCondStore || qresync != null) {
      buffer.write(' (');
      if (enableCondStore) {
        buffer.write('CONDSTORE');
      }
      if (qresync != null) {
        if (buffer.length > 1) {
          buffer.write(' ');
        }
        qresync.render(buffer);
      }
      buffer.write(')');
    }
    var parser = SelectParser(box, this);
    _selectedMailbox = box;
    var cmd = Command(buffer.toString());
    return sendCommand<Mailbox>(cmd, parser);
  }

  /// Closes the currently selected mailbox.
  ///
  /// Compare [selectMailbox]
  Future<Response> closeMailbox() {
    var cmd = Command('CLOSE');
    _selectedMailbox = null;
    return sendCommand(cmd, null);
  }

  /// Searches messages by the given criteria
  ///
  /// [searchCriteria] the criteria like 'UNSEEN' or 'RECENT'
  Future<Response<SearchImapResult>> searchMessages(
      [String searchCriteria = 'UNSEEN']) {
    var cmd = Command('SEARCH $searchCriteria');
    var parser = SearchParser();
    return sendCommand<SearchImapResult>(cmd, parser);
  }

  /// Searches messages by the given criteria
  ///
  /// [searchCriteria] the criteria like 'UNSEEN' or 'RECENT'
  Future<Response<SearchImapResult>> uidSearchMessages(
      [String searchCriteria = 'UNSEEN']) {
    var cmd = Command('UID SEARCH $searchCriteria');
    var parser = SearchParser();
    return sendCommand<SearchImapResult>(cmd, parser);
  }

  /// Fetches a single message by the given definition.
  ///
  /// [messageSequenceId] the message sequence ID of the desired message
  /// [fetchContentDefinition] the definition of what should be fetched from the message, for example `(UID ENVELOPE HEADER[])`, `BODY[]` or `ENVELOPE`, etc
  Future<Response<FetchImapResult>> fetchMessage(
      int messageSequenceId, String fetchContentDefinition) {
    return fetchMessages(
        MessageSequence.fromId(messageSequenceId), fetchContentDefinition);
  }

  /// Fetches messages by the given definition.
  ///
  /// [sequence] the sequence IDs of the messages that should be fetched
  /// [fetchContentDefinition] the definition of what should be fetched from the message, e.g. `(UID ENVELOPE HEADER[])`, `BODY[]` or `ENVELOPE`, etc
  /// Specify the [changedSinceModSequence] in case only messages that have been changed since the specified modification sequence should be fetched. Note that this requires the CONDSTORE or QRESYNC server capability.
  Future<Response<FetchImapResult>> fetchMessages(
      MessageSequence sequence, String fetchContentDefinition,
      {int changedSinceModSequence}) {
    return _fetchMessages('FETCH', sequence, fetchContentDefinition,
        changedSinceModSequence: changedSinceModSequence);
  }

  /// FETCH and UID FETCH implementation
  Future<Response<FetchImapResult>> _fetchMessages(
      String command, MessageSequence sequence, String fetchContentDefinition,
      {int changedSinceModSequence}) {
    var cmdText = StringBuffer()..write(command)..write(' ');
    sequence.render(cmdText);
    cmdText..write(' ')..write(fetchContentDefinition);
    if (changedSinceModSequence != null) {
      cmdText
        ..write(' (CHANGEDSINCE ')
        ..write(changedSinceModSequence)
        ..write(')');
    }
    var cmd = Command(cmdText.toString());
    var parser = FetchParser();
    return sendCommand<FetchImapResult>(cmd, parser);
  }

  /// Fetches messages by the specified criteria.
  ///
  /// This call is more flexible than [fetchMessages].
  /// [fetchIdsAndCriteria] the requested message IDs and specification of the requested elements, e.g. '1:* (ENVELOPE)' or '1:* (FLAGS ENVELOPE) (CHANGEDSINCE 1232232)'.
  Future<Response<FetchImapResult>> fetchMessagesByCriteria(
      String fetchIdsAndCriteria) {
    var cmd = Command('FETCH $fetchIdsAndCriteria');
    var parser = FetchParser();
    return sendCommand<FetchImapResult>(cmd, parser);
  }

  /// Fetches the specified number of recent messages by the specified criteria.
  ///
  /// [messageCount] optional number of messages that should be fetched, defaults to 30
  /// [criteria] optional fetch criterria of the requested elements, e.g. '(ENVELOPE BODY.PEEK[])'. Defaults to '(FLAGS BODY[])'.
  Future<Response<FetchImapResult>> fetchRecentMessages(
      {int messageCount = 30, String criteria = '(FLAGS BODY[])'}) {
    var box = _selectedMailbox;
    if (box == null) {
      throw StateError('No mailbox selected - call select() first.');
    }
    var upperMessageSequenceId = box.messagesExists;
    var lowerMessageSequenceId = upperMessageSequenceId - messageCount;
    if (lowerMessageSequenceId < 1) {
      lowerMessageSequenceId = 1;
    }
    return fetchMessages(
        MessageSequence.fromRange(
            lowerMessageSequenceId, upperMessageSequenceId),
        criteria);
  }

  /// Fetche a single messages identified by the [messageUid]
  ///
  /// [fetchContentDefinition] the definition of what should be fetched from the message, e.g. 'BODY[]' or 'ENVELOPE', etc
  /// Also compare [uidFetchMessagesByCriteria()].
  Future<Response<FetchImapResult>> uidFetchMessage(
      int messageUid, String fetchContentDefinition) {
    return _fetchMessages('UID FETCH', MessageSequence.fromId(messageUid),
        fetchContentDefinition);
  }

  /// Fetches messages by the given definition.
  ///
  /// [sequence] the sequence of message UIDs for which messages should be fetched
  /// [fetchContentDefinition] the definition of what should be fetched from the message, e.g. 'BODY[]' or 'ENVELOPE', etc
  /// Specify the [changedSinceModSequence] in case only messages that have been changed since the specified modification sequence should be fetched. Note that this requires the CONDSTORE or QRESYNC server capability.
  /// Also compare [uidFetchMessagesByCriteria()].
  Future<Response<FetchImapResult>> uidFetchMessages(
      MessageSequence sequence, String fetchContentDefinition,
      {int changedSinceModSequence}) {
    return _fetchMessages('UID FETCH', sequence, fetchContentDefinition,
        changedSinceModSequence: changedSinceModSequence);
  }

  /// Fetches messages by the specified criteria.
  ///
  /// This call is more flexible than [uidFetchMessages].
  /// [fetchIdsAndCriteria] the requested message UIDs and specification of the requested elements, e.g. '1232:1234 (ENVELOPE)'.
  Future<Response<FetchImapResult>> uidFetchMessagesByCriteria(
      String fetchIdsAndCriteria) {
    var cmd = Command('UID FETCH $fetchIdsAndCriteria');
    var parser = FetchParser();
    return sendCommand<FetchImapResult>(cmd, parser);
  }

  /// Appends the specified MIME [message].
  /// When no [targetMailbox] or [targetMailboxPath] is specified, then the message will be appended to the currently selected mailbox.
  /// You can specify flags such as '\Seen' or '\Draft' in the [flags] parameter.
  /// Compare also the [appendMessageText()] method.
  Future<Response<GenericImapResult>> appendMessage(MimeMessage message,
      {List<String> flags, Mailbox targetMailbox, String targetMailboxPath}) {
    return appendMessageText(message.renderMessage(),
        flags: flags,
        targetMailbox: targetMailbox,
        targetMailboxPath: targetMailboxPath);
  }

  /// Appends the specified MIME [messageText].
  /// When no [targetMailbox] or [targetMailboxPath] is specified, then the message will be appended to the currently selected mailbox.
  /// You can specify flags such as '\Seen' or '\Draft' in the [flags] parameter.
  /// Compare also the [appendMessageText()] method.
  Future<Response<GenericImapResult>> appendMessageText(String messageText,
      {List<String> flags, Mailbox targetMailbox, String targetMailboxPath}) {
    var path =
        targetMailbox?.path ?? targetMailboxPath ?? _selectedMailbox?.path;
    if (path == null) {
      throw StateError(
          'no target mailbox specified and no mailbox is currently selected.');
    }
    path = _encodeMailboxPath(path);
    var buffer = StringBuffer()..write('APPEND ')..write(path);
    if (flags != null && flags.isNotEmpty) {
      buffer..write(' (')..write(flags.join(' '))..write(')');
    }
    var numberOfBytes = utf8.encode(messageText).length;
    buffer..write(' {')..write(numberOfBytes)..write('}');
    var cmdText = buffer.toString();
    var cmd = Command.withContinuation([cmdText, messageText]);
    return sendCommand<GenericImapResult>(cmd, GenericParser());
  }

  /// Retrieves the specified meta data entry.
  ///
  /// [entry] defines the path of the meta data
  /// Optionally specify [mailboxName], the [maxSize] in bytes or the [depth].
  ///
  /// Compare https://tools.ietf.org/html/rfc5464 for details.
  /// Note that errata of the RFC exist.
  Future<Response<List<MetaDataEntry>>> getMetaData(String entry,
      {String mailboxName, int maxSize, MetaDataDepth depth}) {
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
    var parser = MetaDataParser();
    return sendCommand<List<MetaDataEntry>>(Command(cmd), parser);
  }

  /// Checks if the specified value can be safely send to the IMAP server just in double-quotes.
  bool _isSafeForQuotedTransmission(String value) {
    return value.length < 80 && !value.contains('"') && !value.contains('\n');
  }

  /// Saves the specified meta data entry.
  ///
  /// Set [MetaDataEntry.value] to null to delete the specified meta data entry
  /// Compare https://tools.ietf.org/html/rfc5464 for details.
  Future<Response<Mailbox>> setMetaData(MetaDataEntry entry) {
    var valueText = entry.valueText;
    Command cmd;
    if (entry.value == null || _isSafeForQuotedTransmission(valueText)) {
      var cmdText =
          'SETMETADATA "${entry.mailboxName ?? ''}" (${entry.entry} ${entry.value == null ? 'NIL' : '"' + valueText + '"'})';
      cmd = Command(cmdText);
    } else {
      // this is a complex command that requires continuation responses
      var parts = <String>[
        'SETMETADATA "${entry.mailboxName ?? ''}" (${entry.entry} {${entry.value.length}}',
        entry.valueText + ')'
      ];
      cmd = Command.withContinuation(parts);
    }
    var parser = NoopParser(this, _selectedMailbox);
    return sendCommand<Mailbox>(cmd, parser);
  }

  /// Saves the all given meta data entries.
  /// Note that each [MetaDataEntry.mailboxName] is expected to be the same.
  ///
  /// Set [MetaDataEntry.value] to null to delete the specified meta data entry
  /// Compare https://tools.ietf.org/html/rfc5464 for details.
  Future<Response<Mailbox>> setMetaDataEntries(List<MetaDataEntry> entries) {
    var parts = <String>[];
    var cmd = StringBuffer();
    cmd.write('SETMETADATA ');
    var entry = entries.first;
    cmd.write('"${entry.mailboxName ?? ''}" (');
    for (entry in entries) {
      cmd.write(' ');
      cmd.write(entry.entry);
      cmd.write(' ');
      if (entry.value == null) {
        cmd.write('NIL');
      } else if (_isSafeForQuotedTransmission(entry.valueText)) {
        cmd.write('"${entry.valueText}"');
      } else {
        cmd.write('{${entry.value.length}}');
        parts.add(cmd.toString());
        cmd = StringBuffer();
        cmd.write(entry.valueText);
      }
    }
    cmd.write(')');
    parts.add(cmd.toString());
    var parser = NoopParser(this, _selectedMailbox);
    Command command;
    if (parts.length == 1) {
      command = Command(parts.first);
    } else {
      command = Command.withContinuation(parts);
    }
    return sendCommand<Mailbox>(command, parser);
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
  Future<Response<Mailbox>> statusMailbox(
      Mailbox box, List<StatusFlags> flags) {
    var path = _encodeMailboxPath(box.path);
    var buffer = StringBuffer()..write('STATUS ')..write(path)..write(' (');
    var addSpace = false;
    for (var flag in flags) {
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
    var cmd = Command(buffer.toString());
    var parser = StatusParser(box);
    return sendCommand<Mailbox>(cmd, parser);
  }

  /// Creates the specified mailbox
  ///
  /// Spefify the name with [path]
  Future<Response<Mailbox>> createMailbox(String path) async {
    path = _encodeMailboxPath(path);
    var cmd = Command('CREATE $path');
    var response = await sendCommand<Mailbox>(cmd, null);
    if (response.isOkStatus) {
      var mailboxesResponse = await listMailboxes(path: path);
      if (mailboxesResponse.isOkStatus &&
          mailboxesResponse.result != null &&
          mailboxesResponse.result.isNotEmpty) {
        response.result = mailboxesResponse.result[0];
        return response;
      }
    }
    return response;
  }

  /// Removes the specified mailbox
  ///
  /// [box] the mailbox to be deleted
  Future<Response<Mailbox>> deleteMailbox(Mailbox box) {
    return _sendMailboxCommand('DELETE', box);
  }

  /// Renames the specified mailbox
  ///
  /// [box] the mailbox that should be renamed
  /// [newName] the desired future name of the mailbox
  Future<Response<Mailbox>> renameMailbox(Mailbox box, String newName) async {
    var path = _encodeMailboxPath(box.path);
    newName = _encodeMailboxPath(newName);

    var cmd = Command('RENAME ${path} $newName');
    var response = await sendCommand<Mailbox>(cmd, null);
    if (response.isOkStatus) {
      if (box.name == 'INBOX') {
        /* Renaming INBOX is permitted, and has special behavior.  It moves
        all messages in INBOX to a new mailbox with the given name,
        leaving INBOX empty.  If the server implementation supports
        inferior hierarchical names of INBOX, these are unaffected by a
        rename of INBOX.
        */
        // question: do we need to create a new mailbox and return that one instead?
      }
      box.name = newName;
    }
    return response;
  }

  /// Subscribes the specified mailbox.
  ///
  /// The mailbox is listed in future LSUB commands, compare [listSubscribedMailboxes].
  /// [box] the mailbox that is subscribed
  Future<Response<Mailbox>> subscribeMailbox(Mailbox box) {
    return _sendMailboxCommand('SUBSCRIBE', box);
  }

  /// Unsubscribes the specified mailbox.
  ///
  /// [box] the mailbox that is unsubscribed
  Future<Response<Mailbox>> unsubscribeMailbox(Mailbox box) {
    return _sendMailboxCommand('UNSUBSCRIBE', box);
  }

  Future<Response<Mailbox>> _sendMailboxCommand(String command, Mailbox box) {
    var path = _encodeMailboxPath(box.path);
    var cmd = Command('$command $path');
    return sendCommand<Mailbox>(cmd, null);
  }

  /// Switches to IDLE mode.
  /// Requires a mailbox to be selected.
  Future idleStart() {
    if (_selectedMailbox == null) {
      print('idle: no mailbox selected');
    }
    _isInIdleMode = true;
    var cmd = Command('IDLE');
    return sendCommand<Mailbox>(cmd, NoopParser(this, _selectedMailbox),
        returnCompleter: false);
  }

  /// Stops the IDLE mode,
  /// for example after receiving information about a new message.
  /// Requires a mailbox to be selected.
  Future idleDone() {
    if (_isInIdleMode) {
      _isInIdleMode = false;
      return write('DONE');
    }
    return Future.value();
  }

  Future<Response<QuotaResult>> setQuota(
      [String quotaRoot = '""', Map<String, int> resourceLimits]) {
    quotaRoot ??= '""';
    quotaRoot = quotaRoot.contains(' ') ? '"$quotaRoot"' : quotaRoot;
    var buffer = StringBuffer()
      ..write('SETQUOTA ')
      ..write(quotaRoot)
      ..write(' (')
      ..write(resourceLimits.entries
          .map((entry) => entry.key + ' ' + entry.value.toString())
          .join(' '))
      ..write(')');
    var cmd = Command(buffer.toString());
    var parser = QuotaParser();
    return sendCommand<QuotaResult>(cmd, parser);
  }

  Future<Response<QuotaResult>> getQuota([String quotaRoot = '""']) {
    quotaRoot ??= '""';
    quotaRoot = quotaRoot.contains(' ') ? '"$quotaRoot"' : quotaRoot;
    var cmd = Command('GETQUOTA $quotaRoot');
    var parser = QuotaParser();
    return sendCommand<QuotaResult>(cmd, parser);
  }

  Future<Response<QuotaRootResult>> getQuotaRoot([String mailboxName = '""']) {
    mailboxName = mailboxName.contains(' ') ? '"$mailboxName"' : mailboxName;
    var cmd = Command('GETQUOTAROOT $mailboxName');
    var parser = QuotaRootParser();
    return sendCommand<QuotaRootResult>(cmd, parser);
  }

  String nextId() {
    var id = _lastUsedCommandId++;
    return 'a$id';
  }

  Future<Response<T>> sendCommand<T>(Command command, ResponseParser<T> parser,
      {bool returnCompleter = true}) async {
    var task = CommandTask<T>(command, nextId(), parser);
    _tasks[task.id] = task;
    await writeTask(task);
    if (returnCompleter) {
      return task.completer.future;
    } else {
      return Future<Response<T>>.value();
    }
  }

  Future writeTask(CommandTask task) {
    _currentCommandTask = task;
    return write(task.toImapRequest(), 'C: $task');
  }

  Future write(String commandText, [String log]) {
    log ??= 'C: $commandText';
    _log(log);
    _socket?.write(commandText + '\r\n');
    return _socket?.flush();
  }

  void onServerResponse(ImapResponse imapResponse) {
    _log('S: $imapResponse');
    var line = imapResponse.parseText;
    //var log = imapResponse.toString().replaceAll("\r\n", "<RT><LF>\n");
    //_log("S: $log");

    //_log("subline: " + line);
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

  void onCommandResult(ImapResponse imapResponse) {
    var line = imapResponse.parseText;
    var spaceIndex = line.indexOf(' ');
    if (spaceIndex != -1) {
      var commandId = line.substring(0, spaceIndex);
      var task = _tasks[commandId];
      if (task != null) {
        if (task == _currentCommandTask) {
          _currentCommandTask = null;
        }
        imapResponse.parseText = line.substring(spaceIndex + 1);
        var response = task.parse(imapResponse);
        task.completer.complete(response);
      } else {
        _log('ERROR: no task found for command [$commandId]');
      }
    } else {
      _log('unexpected SERVER response: [$imapResponse]');
    }
  }

  void onUntaggedResponse(ImapResponse imapResponse) {
    var task = _currentCommandTask;
    if (task == null || !task.parseUntaggedResponse(imapResponse)) {
      _log('untagged not handled: [$imapResponse] by task $task');
    }
  }

  void onContinuationResponse(ImapResponse imapResponse) {
    var cmd = _currentCommandTask?.command;
    if (cmd != null) {
      var response = cmd.getContinuationResponse(imapResponse);
      if (response != null) {
        write(response);
        return;
      }
    }
    if (!_isInIdleMode) {
      _log('continuation not handled: [$imapResponse]');
    }
  }

  void writeCommand(String command) {
    var id = _lastUsedCommandId++;
    _socket?.writeln('$id $command');
  }

  Future<dynamic> closeConnection() {
    _log('Closing socket for host ${serverInfo.host}');
    _isSocketClosingExpected = true;
    return _socket?.close();
  }

  void _log(String text) {
    if (_isLogEnabled) {
      print(text);
    }
  }
}
