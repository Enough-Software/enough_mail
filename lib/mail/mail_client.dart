import 'package:pedantic/pedantic.dart';
import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/mail/tree.dart';
import 'package:event_bus/event_bus.dart';

import 'mail_account.dart';
import 'mail_events.dart';
import 'mail_response.dart';

/// Highlevel online API to access mail.
class MailClient {
  static const Duration defaultPollingDuration = Duration(minutes: 2);
  int _downloadSizeLimit;
  final MailAccount _account;
  EventBus get eventBus => _eventBus;
  final EventBus _eventBus = EventBus();
  bool _isLogEnabled;

  Mailbox _selectedMailbox;
  List<Mailbox> _mailboxes;

  _IncomingMailClient _incomingMailClient;
  _OutgoingMailClient _outgoingMailClient;

  /// Creates a new highlevel online mail client.
  /// Specify the account settings with [account].
  /// Set [isLogEnabled] to true to debug connection issues.
  /// Specify the optional [downloadSizeLimit] in bytes to only download messages automatically that are this size or lower.
  MailClient(this._account,
      {bool isLogEnabled = false, int downloadSizeLimit}) {
    _isLogEnabled = isLogEnabled;
    _downloadSizeLimit = downloadSizeLimit;
    var config = _account.incoming;
    if (config.serverConfig.type == ServerType.imap) {
      _incomingMailClient = _IncomingImapClient(
          _downloadSizeLimit, _eventBus, _isLogEnabled, config);
    } else if (config.serverConfig.type == ServerType.pop) {
      _incomingMailClient = _IncomingPopClient(
          _downloadSizeLimit, _eventBus, _isLogEnabled, config);
    } else {
      throw StateError(
          'Unsupported incoming server type [${config.serverConfig.typeName}].');
    }
    var outgoingConfig = _account.outgoing;
    if (outgoingConfig.serverConfig.type != ServerType.smtp) {
      print(
          'Warning: unknown outgoing server type ${outgoingConfig.serverConfig.typeName}.');
    }
    _outgoingMailClient = _OutgoingSmtpClient(_account.outgoingClientDomain,
        _eventBus, _isLogEnabled, outgoingConfig);
  }

  //Future<MailResponse<List<MimeMessage>>> poll(Mailbox mailbox) {}

  /// Connects and authenticates with the specified incoming mail server.
  Future<MailResponse> connect() {
    return _incomingMailClient.connect();
  }

  // Future<MailResponse> tryAuthenticate(
  //     ServerConfig serverConfig, MailAuthentication authentication) {
  //   return authentication.authenticate(this, serverConfig);
  // }

  /// Lists all mailboxes/folders of the incoming mail server.
  Future<MailResponse<List<Mailbox>>> listMailboxes() async {
    var response = await _incomingMailClient.listMailboxes();
    _mailboxes = response.result;
    return response;
  }

  /// Lists all mailboxes/folders of the incoming mail server as a tree.
  /// Optionally set [createIntermediate] to false, in case not all intermediate folders should be created, if not already present on the server.
  Future<MailResponse<Tree<Mailbox>>> listMailboxesAsTree(
      {bool createIntermediate = true}) async {
    var mailboxes = _mailboxes;
    if (mailboxes == null) {
      var flatResponse = await listMailboxes();
      if (flatResponse.isFailedStatus) {
        return MailResponseHelper.failure<Tree<Mailbox>>(flatResponse.errorId);
      }
      mailboxes = flatResponse.result;
    }
    var separator = _account.incoming.pathSeparator;
    var tree = Tree<Mailbox>(null);
    tree.populateFromList(
        mailboxes,
        (child) => child.getParent(mailboxes, separator,
            createIntermediate: createIntermediate));
    return MailResponseHelper.success<Tree<Mailbox>>(tree);
  }

  /// Shortcut to select the INBOX.
  /// Optionally specify if CONDSTORE support should be enabled with [enableCondstore] - for IMAP servers that support CONDSTORE only.
  /// Optionally specify quick resync parameters with [qresync] - for IMAP servers that support QRESYNC only.
  Future<MailResponse<Mailbox>> selectInbox(
      {bool enableCondstore = false, QResyncParameters qresync}) async {
    var mailboxes = _mailboxes;
    if (mailboxes == null) {
      var flatResponse = await listMailboxes();
      if (flatResponse.isFailedStatus) {
        return MailResponseHelper.failure<Mailbox>(flatResponse.errorId);
      }
      mailboxes = flatResponse.result;
    }
    var inbox = mailboxes.firstWhere((box) => box.isInbox, orElse: () => null);
    inbox ??= mailboxes.firstWhere((box) => box.name.toLowerCase() == 'inbox',
        orElse: () => null);
    if (inbox == null) {
      return MailResponseHelper.failure<Mailbox>('inboxNotFound');
    }
    return selectMailbox(inbox,
        enableCondstore: enableCondstore, qresync: qresync);
  }

  /// Selects the specified [mailbox]/folder.
  /// Optionally specify if CONDSTORE support should be enabled with [enableCondstore].
  /// Optionally specify quick resync parameters with [qresync].
  Future<MailResponse<Mailbox>> selectMailbox(Mailbox mailbox,
      {bool enableCondstore = false, QResyncParameters qresync}) async {
    var response = await _incomingMailClient.selectMailbox(mailbox,
        enableCondstore: enableCondstore, qresync: qresync);
    _selectedMailbox = response.result;
    return response;
  }

  /// Loads the specified segment of messages starting at the latest message and going down [count] messages.
  /// Specify segment's number with [page] - by default this is 1, so the first segment is downloaded.
  /// Optionally specify the [mailbox] in case none has been selected before or if another mailbox/folder should be queried.
  Future<MailResponse<List<MimeMessage>>> fetchMessages(
      {Mailbox mailbox, int count = 20, int page = 1}) async {
    mailbox ??= _selectedMailbox;
    if (mailbox == null) {
      throw StateError('Either specify a mailbox or select a mailbox first');
    }
    if (mailbox != _selectedMailbox) {
      var selectResponse = await selectMailbox(mailbox);
      if (selectResponse.isFailedStatus) {
        return MailResponseHelper.failure<List<MimeMessage>>('select');
      }
      mailbox = selectResponse.result;
    }
    return _incomingMailClient.fetchMessages(
        mailbox: mailbox, count: count, page: page);
  }

  /// Sends the specified message.
  /// Use [MessageBuilder] to create new messages.
  Future<MailResponse> sendMessage(MimeMessage message) {
    return _outgoingMailClient.sendMessage(message);
  }

  /// Starts listening for new incoming messages.
  /// Listen for [MailFetchEvent] on the [eventBus] to get notified about new messages.
  Future<void> startPolling([Duration duration = defaultPollingDuration]) {
    return _incomingMailClient.startPolling(duration);
  }

  /// Stops listening for new messages.
  Future<void> stopPolling() {
    return _incomingMailClient.stopPolling();
  }
}

abstract class _IncomingMailClient {
  int downloadSizeLimit;
  bool _isLogEnabled;
  EventBus _eventBus;
  final MailServerConfig _config;
  Mailbox _selectedMailbox;
  Future Function() _pollImplementation;
  Duration _pollDuration;
  Timer _pollTimer;

  _IncomingMailClient(this.downloadSizeLimit, this._config);

  Future<MailResponse> connect();

  Future<MailResponse<List<Mailbox>>> listMailboxes();

  Future<MailResponse<Mailbox>> selectMailbox(Mailbox mailbox,
      {bool enableCondstore = false, QResyncParameters qresync});

  Future<MailResponse<List<MimeMessage>>> fetchMessages(
      {Mailbox mailbox, int count = 20, int page = 1});

  Future<MailResponse<List<MimeMessage>>> fetchMessageSequence(
      MessageSequence sequence, bool isUidSequence);

  Future<MailResponse<MimeMessage>> fetchMessage(int id, bool isUid);

  Future<MailResponse<List<MimeMessage>>> poll();

  Future<void> startPolling(Duration duration,
      {Future Function() pollImplementation}) {
    _pollDuration = duration;
    _pollImplementation = pollImplementation ?? poll;
    _pollTimer = Timer.periodic(duration, _poll);
    return Future.value();
  }

  Future<void> stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    return Future.value();
  }

  void _poll(Timer timer) async {
    await _pollImplementation();
  }
}

class _IncomingImapClient extends _IncomingMailClient {
  ImapClient _imapClient;
  bool _isQResyncEnabled = false;
  bool _supportsIdle = false;
  bool _isInIdleMode = false;
  final List<MimeMessage> _fetchMessages = <MimeMessage>[];
  bool _isReconnecting = false;
  final List<ImapEvent> _imapEventsDuringReconnecting = <ImapEvent>[];
  int _reconnectCounter = 0;

  _IncomingImapClient(int downloadSizeLimit, EventBus eventBus,
      bool isLogEnabled, MailServerConfig config)
      : super(downloadSizeLimit, config) {
    _imapClient = ImapClient(bus: eventBus, isLogEnabled: isLogEnabled);
    _eventBus = eventBus;
    _isLogEnabled = isLogEnabled;
    eventBus.on<ImapEvent>().listen(_onImapEvent);
  }

  void _onImapEvent(ImapEvent event) async {
    print(
        'imap event: ${event.eventType} - is currently currently reconnecting: $_isReconnecting');
    if (_isReconnecting && event.eventType != ImapEventType.connectionLost) {
      _imapEventsDuringReconnecting.add(event);
      return;
    }
    switch (event.eventType) {
      case ImapEventType.fetch:
        var message = (event as ImapFetchEvent).message;
        MailResponse<MimeMessage> response;
        if (message.uid != null) {
          response = await fetchMessage(message.uid, true);
        } else {
          response = await fetchMessage(message.sequenceId, false);
        }
        if (response.isOkStatus) {
          message = response.result;
        }
        _eventBus.fire(MailLoadEvent(message));
        _fetchMessages.add(message);
        break;
      case ImapEventType.exists:
        var evt = event as ImapMessagesExistEvent;
        var sequence = MessageSequence();
        if (evt.newMessagesExists - evt.oldMessagesExists > 1) {
          sequence.addRange(evt.oldMessagesExists, evt.newMessagesExists);
        } else {
          sequence.add(evt.newMessagesExists);
        }
        var response = await fetchMessageSequence(sequence, false);
        if (response.isOkStatus) {
          for (var message in response.result) {
            _eventBus.fire(MailLoadEvent(message));
            _fetchMessages.add(message);
          }
        }
        break;
      case ImapEventType.vanished:
        var evt = event as ImapVanishedEvent;
        _eventBus.fire(MailVanishedEvent(evt.vanishedMessages, evt.isEarlier));
        break;
      case ImapEventType.expunge:
        //TODO handle EXPUNGE
        break;
      case ImapEventType.connectionLost:
        _isReconnecting = true;
        unawaited(reconnect());
        break;
    }
  }

  Future reconnect() async {
    print('reconnecting....');
    var restartPolling = (_pollTimer != null);
    if (restartPolling) {
      // turn off idle mode as this is an error case in which the client cannot send 'DONE' to the server anyhow.
      _isInIdleMode = false;
      await stopPolling();
      print('stoppend polling');
    }
    _reconnectCounter++;
    var counter = _reconnectCounter;
    while (counter == _reconnectCounter) {
      try {
        print('trying to connect...');
        await connect();
        print('connected.');
        var box = _selectedMailbox;
        if (box != null) {
          print('re-select mailbox "${box.path}".');
          _selectedMailbox = null;
          await selectMailbox(box);
          print('reselected mailbox.');
        }
        if (restartPolling) {
          print('restart polling...');
          await startPolling(_pollDuration,
              pollImplementation: _pollImplementation);
        }
        print('done reconnecting.');
        var events = _imapEventsDuringReconnecting.toList();
        _imapEventsDuringReconnecting.clear();
        _isReconnecting = false;
        if (events.isNotEmpty) {
          for (var event in events) {
            _onImapEvent(event);
          }
        }
        return;
      } catch (e, s) {
        print('Unable to reconnect: $e');
        print(s);
        await Future.delayed(Duration(seconds: 60));
      }
    }
  }

  @override
  Future<MailResponse> connect() async {
    _imapClient ??= ImapClient(bus: _eventBus, isLogEnabled: _isLogEnabled);
    var serverConfig = _config.serverConfig;
    var isSecure = (serverConfig.socketType == SocketType.ssl);
    await _imapClient.connectToServer(serverConfig.hostname, serverConfig.port,
        isSecure: isSecure);
    if (!isSecure) {
      //TODO check if server supports STARTTLS at all
      await _imapClient.startTls();
    }
    var response = await _config.authentication
        .authenticate(_config.serverConfig, imap: _imapClient);
    if (response.isOkStatus) {
      //TODO compare with previous capabilities and possibly fire events for new or removed server capabilities
      _config.serverCapabilities = _imapClient.serverInfo.capabilities;
      if (_config.supports('QRESYNC')) {
        var enabledResponse = await _imapClient.enable(['QRESYNC']);
        _isQResyncEnabled = enabledResponse.isOkStatus;
      }
      _supportsIdle = _config.supports('IDLE');
    }
    return response;
  }

  @override
  Future<MailResponse<List<Mailbox>>> listMailboxes() async {
    var mailboxResponse = await _imapClient.listMailboxes(recursive: true);
    if (mailboxResponse.isFailedStatus) {
      var errorId = 'list';
      return MailResponseHelper.failure<List<Mailbox>>(errorId);
    }
    var separator = _imapClient.serverInfo.pathSeparator;
    _config.pathSeparator = separator;
    return MailResponseHelper.createFromImap<List<Mailbox>>(mailboxResponse);
  }

  @override
  Future<MailResponse<Mailbox>> selectMailbox(Mailbox mailbox,
      {bool enableCondstore = false, QResyncParameters qresync}) async {
    if (_selectedMailbox != null) {
      await _imapClient.closeMailbox();
    }
    if (qresync == null &&
        _isQResyncEnabled &&
        mailbox.highestModSequence != null) {
      qresync =
          QResyncParameters(mailbox.uidValidity, mailbox.highestModSequence);
    }
    var imapResponse = await _imapClient.selectMailbox(mailbox,
        enableCondStore: enableCondstore, qresync: qresync);
    _selectedMailbox = imapResponse.result;
    return MailResponseHelper.createFromImap<Mailbox>(imapResponse);
  }

  @override
  Future<MailResponse<List<MimeMessage>>> fetchMessages(
      {Mailbox mailbox, int count = 20, int page = 1}) {
    var sequence = MessageSequence.fromAll();
    if (count != null) {
      var end = mailbox.messagesExists;
      if (page != null) {
        end -= page * count;
      }
      var start = end - count;
      if (start < 1) {
        start = 1;
      }
      sequence = MessageSequence.fromRange(start, end);
    }
    return fetchMessageSequence(sequence, false);
  }

  @override
  Future<MailResponse<List<MimeMessage>>> fetchMessageSequence(
      MessageSequence sequence, bool isUidSequence) async {
    try {
      String criteria;
      if (downloadSizeLimit != null) {
        criteria = 'UID RFC822.SIZE ENVELOPE';
      } else {
        criteria = 'BODY.PEEK[]';
      }
      if (_isInIdleMode) {
        await _imapClient.idleDone();
      }

      var response = isUidSequence
          ? await _imapClient.uidFetchMessages(sequence, criteria)
          : await _imapClient.fetchMessages(sequence, criteria);
      if (response.isFailedStatus) {
        return MailResponseHelper.failure<List<MimeMessage>>('fetch');
      }
      if (response.result.vanishedMessagesUidSequence?.isNotEmpty() ?? false) {
        _eventBus.fire(MailVanishedEvent(
            response.result.vanishedMessagesUidSequence, false));
      }
      if (downloadSizeLimit != null) {
        var smallEnoughMessages = response.result.messages
            .where((msg) => msg.size < downloadSizeLimit);
        sequence = MessageSequence();
        for (var msg in smallEnoughMessages) {
          sequence.add(msg.uid);
        }
        response = await _imapClient.fetchMessages(sequence, 'BODY.PEEK[]');
        if (response.isFailedStatus) {
          return MailResponseHelper.failure<List<MimeMessage>>('fetch');
        }
      }
      return MailResponseHelper.success<List<MimeMessage>>(
          response.result.messages);
    } catch (e, s) {
      print('error while fetching: $e');
      print(s);
    } finally {
      if (_isInIdleMode) {
        await _imapClient.idleStart();
      }
    }
  }

  @override
  Future<MailResponse<List<MimeMessage>>> poll() async {
    _fetchMessages.clear();
    await _imapClient.noop();
    if (_fetchMessages.isEmpty) {
      return MailResponseHelper.failure(null);
    }
    return MailResponseHelper.success<List<MimeMessage>>(
        _fetchMessages.toList());
  }

  @override
  Future<MailResponse<MimeMessage>> fetchMessage(int id, bool isUid) async {
    var sequence = MessageSequence.fromId(id);
    var response = await fetchMessageSequence(sequence, isUid);
    if (response.isOkStatus) {
      return MailResponseHelper.success<MimeMessage>(response.result.first);
    } else {
      return MailResponseHelper.failure<MimeMessage>(response.errorId);
    }
  }

  @override
  Future<void> startPolling(Duration duration,
      {Future Function() pollImplementation}) async {
    if (_supportsIdle) {
      // IMAP Idle timeout is 30 minutes, so official recommendation is to restart IDLE every 29 minutes.
      // Here is a shorter duration chosen, so that connection problems are detected earlier.
      if (duration == null || duration == MailClient.defaultPollingDuration) {
        duration = Duration(minutes: 5);
      }
      pollImplementation ??= _restartIdle;
      _isInIdleMode = true;
      await _imapClient.idleStart();
    }
    return super.startPolling(duration, pollImplementation: pollImplementation);
  }

  @override
  Future<void> stopPolling() async {
    if (_isInIdleMode) {
      _isInIdleMode = false;
      try {
        await _imapClient.idleDone();
      } catch (e, s) {
        print('Error while stopping IDLE mode with DONE: $e');
        print(s);
      }
    }
    return super.stopPolling();
  }

  Future _restartIdle() async {
    try {
      //print('restart IDLE...');
      await _imapClient.idleDone();
      await _imapClient.idleStart();
      //print('done restarting IDLE.');
    } catch (e, s) {
      print('Unable to restart IDLE: $e');
      print(s);
    }
    return Future.value();
  }
}

class _IncomingPopClient extends _IncomingMailClient {
  List<MessageListing> _popMessageListing;
  final Mailbox _popInbox =
      Mailbox.setup('Inbox', 'Inbox', [MailboxFlag.inbox]);

  PopClient _popClient;
  _IncomingPopClient(int downloadSizeLimit, EventBus eventBus,
      bool isLogEnabled, MailServerConfig config)
      : super(downloadSizeLimit, config) {
    config = config;
    _popClient = PopClient(bus: eventBus, isLogEnabled: isLogEnabled);
    _eventBus = eventBus;
    _isLogEnabled = isLogEnabled;
  }

  @override
  Future<MailResponse> connect() async {
    var serverConfig = _config.serverConfig;
    var isSecure = (serverConfig.socketType == SocketType.ssl);
    await _popClient.connectToServer(serverConfig.hostname, serverConfig.port,
        isSecure: isSecure);
    if (!isSecure) {
      //TODO check POP3 server capabilities first
      await _popClient.startTls();
    }
    var authResponse = await _config.authentication
        .authenticate(_config.serverConfig, pop: _popClient);

    return authResponse;
  }

  @override
  Future<MailResponse<List<Mailbox>>> listMailboxes() {
    _config.pathSeparator = '/';
    var response = MailResponseHelper.success<List<Mailbox>>([_popInbox]);
    return Future.value(response);
  }

  @override
  Future<MailResponse<Mailbox>> selectMailbox(Mailbox mailbox,
      {bool enableCondstore = false, QResyncParameters qresync}) async {
    if (mailbox != _popInbox) {
      throw StateError('Unknown mailbox $mailbox');
    }
    var statusResponse = await _popClient.status();
    if (statusResponse.isFailedStatus) {
      return MailResponseHelper.failure<Mailbox>('status');
    }
    mailbox.messagesExists = statusResponse.result.numberOfMessages;
    _selectedMailbox = mailbox;
    return MailResponseHelper.success<Mailbox>(mailbox);
  }

  @override
  Future<MailResponse<List<MimeMessage>>> fetchMessages(
      {Mailbox mailbox, int count = 20, int page = 1}) async {
    if (_popMessageListing == null) {
      var messageListResponse = await _popClient.list();
      if (messageListResponse.isFailedStatus) {
        return MailResponseHelper.failure('fetch');
      }
      _popMessageListing = messageListResponse.result;
    }
    var listings = _popMessageListing;
    if (count != null) {
      var startIndex = _popMessageListing.length - count;
      if (page != null) {
        startIndex -= page * count;
      }
      if (startIndex < 0) {
        count += startIndex;
        startIndex = 0;
      }
      listings = listings.sublist(startIndex, startIndex + count);
    }
    var messages = <MimeMessage>[];
    for (var listing in listings) {
      //TODO check listing.sizeInBytes
      var messageResponse = await _popClient.retrieve(listing.id);
      if (messageResponse.isOkStatus) {
        messages.add(messageResponse.result);
      }
    }
    return MailResponseHelper.success<List<MimeMessage>>(messages);
  }

  @override
  Future<MailResponse<MimeMessage>> fetchMessage(int id, bool isUid) async {
    var messageResponse = await _popClient.retrieve(id);
    return MailResponseHelper.createFromPop<MimeMessage>(messageResponse);
  }

  @override
  Future<MailResponse<List<MimeMessage>>> poll() async {
    var numberOfKNownMessages = _selectedMailbox?.messagesExists;
    // in POP3 a new session is required to get a new status
    var loginResponse = await connect();
    if (loginResponse.isFailedStatus) {
      return MailResponseHelper.failure<List<MimeMessage>>(
          loginResponse.errorId);
    }
    var statusResponse = await _popClient.status();
    if (statusResponse.isFailedStatus) {
      return MailResponseHelper.failure<List<MimeMessage>>('pop.status');
    }
    var messages = <MimeMessage>[];
    var numberOfMessages = statusResponse.result.numberOfMessages;
    if (numberOfMessages < numberOfKNownMessages) {
      //TODO compare list UIDs with nown message UIDs instead of just checking the number of messages
      var diff = numberOfMessages - numberOfKNownMessages;
      for (var id = numberOfMessages; id > numberOfMessages - diff; id--) {
        var messageResponse = await fetchMessage(id, false);
        if (messageResponse.isOkStatus) {
          var message = messageResponse.result;
          messages.add(message);
          _eventBus.fire(MailLoadEvent(message));
        }
      }
    }
    return MailResponseHelper.success<List<MimeMessage>>(messages);
  }

  @override
  Future<MailResponse<List<MimeMessage>>> fetchMessageSequence(
      MessageSequence sequence, bool isUidSequence) async {
    var ids = sequence.toList(_selectedMailbox?.messagesExists);
    var messages = <MimeMessage>[];
    for (var id in ids) {
      var messageResponse = await fetchMessage(id, false);
      if (messageResponse.isOkStatus) {
        var message = messageResponse.result;
        messages.add(message);
      }
    }
    return MailResponseHelper.success<List<MimeMessage>>(messages);
  }
}

abstract class _OutgoingMailClient {
  Future<MailResponse> sendMessage(MimeMessage message);
}

class _OutgoingSmtpClient extends _OutgoingMailClient {
  SmtpClient _smtpClient;
  MailServerConfig _mailConfig;

  _OutgoingSmtpClient(String outgoingClientDomain, EventBus eventBus,
      bool isLogEnabled, MailServerConfig mailConfig) {
    _smtpClient = SmtpClient(outgoingClientDomain,
        bus: eventBus, isLogEnabled: isLogEnabled);
    _mailConfig = mailConfig;
  }

  Future<MailResponse> _connectOutgoingIfRequired() async {
    if (!_smtpClient.isLoggedIn) {
      var config = _mailConfig.serverConfig;
      var isSecure = (config.socketType == SocketType.ssl);
      var response = await _smtpClient
          .connectToServer(config.hostname, config.port, isSecure: isSecure);
      if (response.isFailedStatus) {
        return MailResponseHelper.failure('smtp.connect');
      }
      response = await _smtpClient.ehlo();
      if (response.isFailedStatus) {
        return MailResponseHelper.failure('smtp.ehlo');
      }
      if (!isSecure) {
        //TODO check for STARTTSL capability first
        response = await _smtpClient.startTls();
        if (response.isFailedStatus) {
          return MailResponseHelper.failure('smtp.starttls');
        }
      }
      return _mailConfig.authentication.authenticate(config, smtp: _smtpClient);
    }
    return Future.value(MailResponseHelper.success(null));
  }

  @override
  Future<MailResponse> sendMessage(MimeMessage message) async {
    var response = await _connectOutgoingIfRequired();
    if (response.isFailedStatus) {
      return response;
    }

    var sendResponse = await _smtpClient.sendMessage(message);
    if (sendResponse.isFailedStatus) {
      return MailResponseHelper.failure('smtp.send');
    }
    return MailResponseHelper.success(sendResponse.code);
  }
}
