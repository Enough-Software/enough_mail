import 'dart:io';
import 'package:event_bus/event_bus.dart';
import 'package:enough_mail/imap/mailbox.dart';
import 'package:enough_mail/mime_message.dart';
import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/capability_parser.dart';
import 'package:enough_mail/src/imap/command.dart';
import 'package:enough_mail/src/imap/fetch_parser.dart';
import 'package:enough_mail/src/imap/imap_response.dart';
import 'package:enough_mail/src/imap/imap_response_reader.dart';
import 'package:enough_mail/src/imap/list_parser.dart';
import 'package:enough_mail/src/imap/logout_parser.dart';
import 'package:enough_mail/src/imap/noop_parser.dart';
import 'package:enough_mail/src/imap/response_parser.dart';
import 'package:enough_mail/src/imap/search_parser.dart';
import 'package:enough_mail/src/imap/select_parser.dart';
import 'package:enough_mail/src/imap/status_parser.dart';

import 'events.dart';

/// Describes a capability
class Capability {
  String name;
  Capability(this.name);

  @override
  String toString() {
    return name;
  }
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
}

enum StatusFlags { messages, recent, uidNext, uidValidity, unseen }

/// Low-level IMAP library for Dartlang
///
/// Compliant to IMAP4rev1 standard [RFC 3501].
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
  EventBus eventBus;

  bool _isSocketClosingExpected = false;
  bool get isLoggedIn => _isLoggedIn;
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
    eventBus ??= EventBus();
    ;
    _isLogEnabled = isLogEnabled ?? false;
    _imapResponseReader = ImapResponseReader(onServerResponse);
  }

  /// Connects to the specified server.
  ///
  /// Specify [isSecure] if you do not want to connect to a secure service.
  Future<Socket> connectToServer(String host, int port,
      {bool isSecure = true}) async {
    serverInfo = ImapServerInfo();
    serverInfo.host = host;
    serverInfo.port = port;
    serverInfo.isSecure = isSecure;
    _log(
        'Connecting to $host:$port ${isSecure ? '' : 'NOT'} using a secure socket...');

    var socket = isSecure
        ? await SecureSocket.connect(host, port)
        : await Socket.connect(host, port);
    connect(socket);
    return socket;
  }

  /// Starts to liste on [socket].
  ///
  /// This is mainly useful for testing purposes, ensure to set [serverInfo] manually in this  case.
  void connect(Socket socket) {
    socket.listen(_imapResponseReader.onData, onDone: () {
      _isLoggedIn = false;
      _log('Done, connection closed');
      if (!_isSocketClosingExpected) {
        eventBus.fire(ImapConnectionLostEvent());
      }
    }, onError: (error) {
      _isLoggedIn = false;
      _log('Error: $error');
      if (!_isSocketClosingExpected) {
        eventBus.fire(ImapConnectionLostEvent());
      }
    });
    _isSocketClosingExpected = false;
    _socket = socket;
  }

  Future<Response<List<Capability>>> login(String name, String password) async {
    var cmd = Command('LOGIN $name $password');
    cmd.logText = 'LOGIN $name (password scrambled)';
    var parser = CapabilityParser(serverInfo);
    var response = await sendCommand<List<Capability>>(cmd, parser);
    _isLoggedIn = response.isOkStatus;
    return response;
  }

  Future<Response<String>> logout() async {
    var cmd = Command('LOGOUT');
    var response = await sendCommand<String>(cmd, LogoutParser());
    _isLoggedIn = false;
    return response;
  }

  Future<Response<Mailbox>> noop() {
    var cmd = Command('NOOP');
    return sendCommand<Mailbox>(cmd, NoopParser(eventBus, _selectedMailbox));
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

  /// lists all mailboxes in the path [referenceName] that match the given [mailboxName] that can contain wildcards.
  ///
  /// The LIST command will set the [serverInfo.pathSeparator] as a side-effect
  Future<Response<List<Mailbox>>> listMailboxesByReferenceAndName(
      String referenceName, String mailboxName) {
    var cmd = Command('LIST $referenceName $mailboxName');
    var parser = ListParser(serverInfo);
    return sendCommand<List<Mailbox>>(cmd, parser);
  }

  Future<Response<List<Mailbox>>> listSubscribedMailboxes(
      {String path = '""', bool recursive = false}) {
    //Command cmd = Command("LIST \"INBOX/\" %");
    var cmd = Command('LSUB $path ' +
        (recursive ? '*' : '%')); // list all folders in that path
    var parser = ListParser(serverInfo, isLsubParser: true);
    return sendCommand<List<Mailbox>>(cmd, parser);
  }

  Future<Response<Mailbox>> selectMailbox(Mailbox box) {
    var cmd = Command('SELECT ' + box.path);
    var parser = SelectParser(box);
    _selectedMailbox = box;
    return sendCommand<Mailbox>(cmd, parser);
  }

  Future<Response> closeMailbox() {
    var cmd = Command('CLOSE');
    _selectedMailbox = null;
    return sendCommand(cmd, null);
  }

  Future<Response<List<int>>> searchMessages(
      [String searchCriteria = 'UNSEEN']) {
    var cmd = Command('SEARCH $searchCriteria');
    var parser = SearchParser();
    return sendCommand<List<int>>(cmd, parser);
  }

  Future<Response<List<MimeMessage>>> fetchMessages(int lowerMessageSequenceId,
      int upperMessageSequenceId, String fetchContentDefinition) {
    var cmdText = StringBuffer();
    cmdText.write('FETCH ');
    cmdText.write(lowerMessageSequenceId);
    if (upperMessageSequenceId != -1 &&
        upperMessageSequenceId != lowerMessageSequenceId) {
      cmdText.write(':');
      cmdText.write(upperMessageSequenceId);
    }
    cmdText.write(' ');
    cmdText.write(fetchContentDefinition);
    var cmd = Command(cmdText.toString());
    var parser = FetchParser();
    return sendCommand<List<MimeMessage>>(cmd, parser);
  }

  Future<Response<List<MimeMessage>>> fetchMessagesByCriteria(
      String fetchIdsAndCriteria) {
    var cmd = Command('FETCH $fetchIdsAndCriteria');
    var parser = FetchParser();
    return sendCommand<List<MimeMessage>>(cmd, parser);
  }

  /// Examines the [mailbox] without selecting it.
  ///
  /// Also compare: statusMailbox(Mailbox, StatusFlags)
  /// The EXAMINE command is identical to SELECT and returns the same
  /// output; however, the selected mailbox is identified as read-only.
  /// No changes to the permanent state of the mailbox, including
  /// per-user state, are permitted; in particular, EXAMINE MUST NOT
  /// cause messages to lose the \Recent flag.
  Future<Response<Mailbox>> examineMailbox(Mailbox box) {
    var cmd = Command('EXAMINE ${box.path}');
    var parser = SelectParser(box);
    return sendCommand<Mailbox>(cmd, parser);
  }

  /// Checks the status of the currently not selected [mailbox].
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
    var flagsStr = '(';
    var addSpace = false;
    for (var flag in flags) {
      if (addSpace) {
        flagsStr += ' ';
      }
      switch (flag) {
        case StatusFlags.messages:
          flagsStr += 'MESSAGES';
          addSpace = true;
          break;
        case StatusFlags.recent:
          flagsStr += 'RECENT';
          addSpace = true;
          break;
        case StatusFlags.uidNext:
          flagsStr += 'UIDNEXT';
          addSpace = true;
          break;
        case StatusFlags.uidValidity:
          flagsStr += 'UIDVALIDITY';
          addSpace = true;
          break;
        case StatusFlags.unseen:
          flagsStr += 'UNSEEN';
          addSpace = true;
          break;
      }
    }
    flagsStr += ')';
    var cmd = Command('STATUS ${box.path} $flagsStr');
    var parser = StatusParser(box);
    return sendCommand<Mailbox>(cmd, parser);
  }

  Future<Response<Mailbox>> createMailbox(String path) async {
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

  Future<Response<Mailbox>> deleteMailbox(Mailbox box) {
    var cmd = Command('DELETE ${box.path}');
    return sendCommand<Mailbox>(cmd, null);
  }

  Future<Response<Mailbox>> renameMailbox(Mailbox box, String newName) async {
    var cmd = Command('RENAME ${box.path} $newName');
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

  Future<Response<Mailbox>> subscribeMailbox(Mailbox box) {
    var cmd = Command('SUBSCRIBE ${box.path}');
    return sendCommand<Mailbox>(cmd, null);
  }

  Future<Response<Mailbox>> unsubscribeMailbox(Mailbox box) {
    var cmd = Command('UNSUBSCRIBE ${box.path}');
    return sendCommand<Mailbox>(cmd, null);
  }

  /// Switches to IDLE mode.
  /// Requires a mailbox to be selected.
  Future<Response<Mailbox>> idleStart() {
    if (_selectedMailbox == null) {
      print('idle: no mailbox selected');
    }
    _isInIdleMode = true;
    var cmd = Command('IDLE');
    return sendCommand<Mailbox>(cmd, NoopParser(eventBus, _selectedMailbox));
  }

  /// Stops the IDLE mode,
  /// for example after receiving information about a new .
  /// Requires a mailbox to be selected.
  void idleDone() {
    _isInIdleMode = false;
    return write('DONE');
  }

  String nextId() {
    var id = _lastUsedCommandId++;
    return 'a$id';
  }

  Future<Response<T>> sendCommand<T>(
      Command command, ResponseParser<T> parser) {
    var task = CommandTask<T>(command, nextId(), parser);
    _tasks[task.id] = task;
    writeTask(task);
    return task.completer.future;
  }

  void writeTask(CommandTask task) {
    _currentCommandTask = task;
    _log('C: $task');
    _socket?.write(task.toImapRequest() + '\r\n');
  }

  void write(String commandText) {
    _log('C: $commandText');
    _socket?.write(commandText + '\r\n');
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
      _log('untagged not handled: [$imapResponse]');
    }
  }

  void onContinuationResponse(ImapResponse imapResponse) {
    if (!_isInIdleMode) {
      _log('continuation not handled: [$imapResponse]');
    }
  }

  void writeCommand(String command) {
    var id = _lastUsedCommandId++;
    _socket?.writeln('$id $command');
  }

  Future<dynamic> close() {
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
