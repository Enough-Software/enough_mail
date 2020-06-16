import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/mail/tree.dart';
import 'package:event_bus/event_bus.dart';

import 'mail_account.dart';
import 'mail_events.dart';
import 'mail_response.dart';

/// Highlevel online API to access mail.
class MailClient {
  static const Duration defaultPollingDuration = Duration(seconds: 30);
  int _downloadSizeLimit;
  final MailAccount _account;
  EventBus get eventBus => _eventBus;
  final EventBus _eventBus = EventBus();
  bool _isLogEnabled;

  Mailbox _selectedMailbox;

  List<Mailbox> _mailboxes;

  SmtpClient _smtpClient;
  _IncomingMailClient _incomingMailClient;

  /// Creates a new highlevel online mail client.
  /// Specify the account settings with [account].
  /// Set [isLogEnabled] to true to debug connection issues.
  /// Specify the optional [downloadSizeLimit] in bytes to only download messages automatically that are this size or lower.
  MailClient(this._account,
      {bool isLogEnabled = false, int downloadSizeLimit}) {
    _isLogEnabled = isLogEnabled;
    _downloadSizeLimit = downloadSizeLimit;
  }

  //Future<MailResponse<List<MimeMessage>>> poll(Mailbox mailbox) {}

  /// Connects and authenticates with the specified incoming mail server.
  Future<MailResponse> connect() {
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

  Future<MailResponse> _connectOutgoingIfRequired() async {
    if (_smtpClient == null) {
      _smtpClient ??= SmtpClient(_account.outgoingClientDomain,
          bus: eventBus, isLogEnabled: _isLogEnabled);
      var config = _account.outgoing.serverConfig;
      var response =
          await _smtpClient.connectToServer(config.hostname, config.port);
      if (response.isFailedStatus) {
        _smtpClient = null;
        return MailResponseHelper.failure('smtp.connect');
      }
      return _account.outgoing.authentication.authenticate(config);
    }
    return Future.value(MailResponseHelper.success(null));
  }

  /// Sends the specified message.
  /// Use [MessageBuilder] to create new messages.
  Future<MailResponse> sendMessage(MimeMessage message) async {
    if (_smtpClient == null) {
      var response = await _connectOutgoingIfRequired();
      if (response.isFailedStatus) {
        _smtpClient = null;
        return response;
      }
    }
    var sendResponse = await _smtpClient.sendMessage(message);
    if (sendResponse.isFailedStatus) {
      return MailResponseHelper.failure('smtp.send');
    }
    return MailResponseHelper.success(sendResponse.code);
  }

  /// Starts listening for new incoming messages.
  /// Listen for [MailFetchEvent] on the [eventBus] to get notified about new messages.
  void startPolling([Duration duration = defaultPollingDuration]) {
    _incomingMailClient.startPolling(duration);
  }

  /// Stops listening for new messages.
  void stopPolling() {
    _incomingMailClient.stopPolling();
  }
}

abstract class _IncomingMailClient {
  int downloadSizeLimit;

  bool _isLogEnabled;
  EventBus _eventBus;
  final MailServerConfig _config;
  Mailbox _selectedMailbox;
  bool _isPollingStopRequested;

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

  void startPolling(Duration duration) {
    _isPollingStopRequested = false;
    Timer.periodic(duration, _poll);
  }

  void stopPolling() {
    _isPollingStopRequested = true;
  }

  void _poll(Timer timer) {
    if (_isPollingStopRequested) {
      timer.cancel();
    } else {
      poll();
    }
  }
}

class _IncomingImapClient extends _IncomingMailClient {
  ImapClient _imapClient;
  bool _isQResyncEnabled = false;
  bool _supportsIdle = false;
  final List<MimeMessage> _fetchMessages = <MimeMessage>[];

  _IncomingImapClient(int downloadSizeLimit, EventBus eventBus,
      bool isLogEnabled, MailServerConfig config)
      : super(downloadSizeLimit, config) {
    _imapClient = ImapClient(bus: eventBus, isLogEnabled: isLogEnabled);
    _eventBus = eventBus;
    _isLogEnabled = isLogEnabled;
    eventBus.on<ImapEvent>().listen(_onImapEvent);
  }

  void _onImapEvent(ImapEvent event) async {
    //print('imap event: ${event.eventType}');
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
        await connect();
    }
  }

  @override
  Future<MailResponse> connect() async {
    _imapClient ??= ImapClient(bus: _eventBus, isLogEnabled: _isLogEnabled);
    var serverConfig = _config.serverConfig;
    await _imapClient.connectToServer(serverConfig.hostname, serverConfig.port,
        isSecure: serverConfig.socketType == SocketType.ssl);
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
    String criteria;
    if (downloadSizeLimit != null) {
      criteria = 'UID RFC822.SIZE ENVELOPE';
    } else {
      criteria = 'BODY.PEEK[]';
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
      var smallEnoughMessages =
          response.result.messages.where((msg) => msg.size < downloadSizeLimit);
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
  void startPolling(Duration duration) {
    // if (_supportsIdle) {
    //   _imapClient.idleStart()
    //TODO support IDLE
    // } else {
    super.startPolling(duration);
    // }
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
    await _popClient.connectToServer(serverConfig.hostname, serverConfig.port,
        isSecure: serverConfig.socketType == SocketType.ssl);
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
    throw UnimplementedError();
  }

  @override
  Future<MailResponse<List<MimeMessage>>> poll() {
    // TODO: implement poll
    throw UnimplementedError();
  }

  @override
  Future<MailResponse<List<MimeMessage>>> fetchMessageSequence(
      MessageSequence sequence, bool isUidSequence) {
    // TODO: implement fetchMessageSequence
    throw UnimplementedError();
  }
}
