import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/mail/delete_result.dart';
import 'package:enough_mail/mail/tree.dart';
import 'package:event_bus/event_bus.dart';
import 'package:pedantic/pedantic.dart';

/// Definition for optional event filters, compare [MailClient.addEventFilter()].
typedef MailEventFilter = bool Function(MailEvent event);

/// The client's preference when fetching messages
enum FetchPreference {
  /// Only envelope data is preferred - this is the fasted option
  envelope,

  /// Only the structural information is preferred
  bodystructure,

  /// The full message details are preferred
  full
}

/// Highlevel online API to access mail.
class MailClient {
  static const Duration defaultPollingDuration = Duration(minutes: 2);
  static const List<MailboxFlag> defaultMailboxOrder = [
    MailboxFlag.inbox,
    MailboxFlag.drafts,
    MailboxFlag.sent,
    MailboxFlag.trash,
    MailboxFlag.archive,
    MailboxFlag.junk
  ];
  int _downloadSizeLimit;
  final MailAccount _account;
  MailAccount get account => _account;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  /// event bus for firing and listening to events
  EventBus eventBus;

  /// Filter for mail events, allows to subpress events being forwarded to the [eventBus].
  List<MailEventFilter> _eventFilters;

  bool _isLogEnabled;

  Mailbox _selectedMailbox;

  /// Retrieves the currently selected mailbox, if any.
  /// Compare [selectMailbox(...)].
  Mailbox get selectedMailbox => _selectedMailbox;

  List<Mailbox> _mailboxes;

  /// Retrieves the previously caches mailboxes
  List<Mailbox> get mailboxes => _mailboxes;

  /// Retrieves the low level mail client for reading mails
  /// Example:
  /// ```
  /// if (mailClient.lowLevelIncomingMailClientType == ServerType.imap) {
  ///   var imapClient = mailClient.lowLevelIncomingMailClient as ImapClient;
  ///   var response = await imapClient.uidFetchMessage(1232, '(ENVELOPE HEADER[])');
  /// }
  /// ```
  Object get lowLevelIncomingMailClient => _incomingMailClient.client;

  /// Retrieves the type pof the low level mail client, currently either ServerType.imap or ServerType.pop
  ServerType get lowLevelIncomingMailClientType =>
      _incomingMailClient.clientType;

  /// Retrieves the low level mail client for sending mails
  /// Example:
  /// ```
  /// var smtpClient = mailClient.lowLevelOutgoingMailClient as SmtpClient;
  /// var response = await smtpClient.ehlo();
  /// ```
  Object get lowLevelOutgoingMailClient => _outgoingMailClient.client;

  /// Retrieves the type pof the low level mail client, currently always ServerType.smtp
  ServerType get lowLevelOutgoingMailClientType =>
      _outgoingMailClient.clientType;

  _IncomingMailClient _incomingMailClient;
  _OutgoingMailClient _outgoingMailClient;

  /// Creates a new highlevel online mail client.
  /// Specify the account settings with [account].
  /// Set [isLogEnabled] to true to debug connection issues.
  /// Specify the optional [downloadSizeLimit] in bytes to only download messages automatically that are this size or lower.
  MailClient(this._account,
      {bool isLogEnabled = false,
      int downloadSizeLimit,
      this.eventBus,
      String logName}) {
    eventBus ??= EventBus();
    _isLogEnabled = isLogEnabled;
    _downloadSizeLimit = downloadSizeLimit;
    var config = _account.incoming;
    if (config.serverConfig.type == ServerType.imap) {
      _incomingMailClient = _IncomingImapClient(
          _downloadSizeLimit, eventBus, _isLogEnabled, config, logName, this);
    } else if (config.serverConfig.type == ServerType.pop) {
      _incomingMailClient = _IncomingPopClient(
          _downloadSizeLimit, eventBus, _isLogEnabled, config, this);
    } else {
      throw StateError(
          'Unsupported incoming server type [${config.serverConfig.typeName}].');
    }
    var outgoingConfig = _account.outgoing;
    if (outgoingConfig.serverConfig.type != ServerType.smtp) {
      print(
          'Warning: unknown outgoing server type ${outgoingConfig.serverConfig.typeName}.');
    }
    _outgoingMailClient = _OutgoingSmtpClient(
        _account.outgoingClientDomain, eventBus, _isLogEnabled, outgoingConfig);
  }

  /// Adds the specified mail event [filter].
  /// You can use a filter to surpress any [MailEvent].
  /// Compare [eventBus].
  void addEventFilter(MailEventFilter filter) {
    _eventFilters ??= <MailEventFilter>[];
    _eventFilters.add(filter);
  }

  /// Removes the specified mail event [filter].
  /// Compare [addEventFilter()].
  void removeEventFilter(MailEventFilter filter) {
    if (_eventFilters != null) {
      _eventFilters.remove(filter);
      if (_eventFilters.isEmpty) {
        _eventFilters = null;
      }
    }
  }

  void _fireEvent(MailEvent event) {
    if (_eventFilters != null) {
      for (final filter in _eventFilters) {
        if (filter(event)) {
          return;
        }
      }
    }
    eventBus.fire(event);
  }

  //Future<MailResponse<List<MimeMessage>>> poll(Mailbox mailbox) {}

  /// Connects and authenticates with the specified incoming mail server.
  /// Also compare [disconnect()].
  Future<MailResponse> connect() async {
    final response = await _incomingMailClient.connect();
    _isConnected = response?.isOkStatus ?? false;
    return response;
  }

  /// Disconnects from the mail service.
  /// Also compare [connect()].
  Future disconnect() async {
    if (_incomingMailClient != null) {
      await _incomingMailClient.disconnect();
    }
    if (_outgoingMailClient != null) {
      await _outgoingMailClient.disconnect();
    }
    _isConnected = false;
  }

  // Future<MailResponse> tryAuthenticate(
  //     ServerConfig serverConfig, MailAuthentication authentication) {
  //   return authentication.authenticate(this, serverConfig);
  // }

  /// Lists all mailboxes/folders of the incoming mail server.
  Future<MailResponse<List<Mailbox>>> listMailboxes(
      {List<MailboxFlag> order}) async {
    var response = await _incomingMailClient.listMailboxes();
    _mailboxes = response.result;
    if (response.isOkStatus && order != null) {
      response.result = sortMailboxes(order, response.result);
    }
    return response;
  }

  /// Lists all mailboxes/folders of the incoming mail server as a tree.
  /// Optionally set [createIntermediate] to false, in case not all intermediate folders should be created, if not already present on the server.
  Future<MailResponse<Tree<Mailbox>>> listMailboxesAsTree(
      {bool createIntermediate = true,
      List<MailboxFlag> order = defaultMailboxOrder}) async {
    var mailboxes = _mailboxes;
    if (mailboxes == null) {
      var flatResponse = await listMailboxes();
      if (flatResponse.isFailedStatus) {
        return MailResponseHelper.failure<Tree<Mailbox>>(flatResponse.errorId);
      }
      mailboxes = flatResponse.result;
    }
    List<Mailbox> firstBoxes;
    if (order != null) {
      firstBoxes = sortMailboxes(order, mailboxes, keepRemaining: false);
      mailboxes = [...mailboxes];
      mailboxes.sort((b1, b2) => b1.path.compareTo(b2.path));
    }
    var separator = _account.incoming.pathSeparator;
    var tree = Tree<Mailbox>(null);
    tree.populateFromList(
        mailboxes,
        (child) => child.getParent(mailboxes, separator,
            createIntermediate: createIntermediate));
    if (firstBoxes != null) {
      final parent = tree.root;
      final children = parent.children;
      for (var i = firstBoxes.length; --i >= 0;) {
        final box = firstBoxes[i];
        var element = _extractTreeElementWithoutChildren(parent, box);
        if (element.children?.isEmpty ?? true) {
          // this elemement has been removed:
          element.parent = parent;
        } else {
          element = TreeElement<Mailbox>(box, parent);
        }
        children.insert(0, element);
      }
    }
    return MailResponseHelper.success<Tree<Mailbox>>(tree);
  }

  TreeElement<Mailbox> _extractTreeElementWithoutChildren(
      TreeElement root, Mailbox mailbox) {
    if (root.value == mailbox) {
      if ((root.children?.isEmpty ?? true) && (root.parent != null)) {
        root.parent.children.remove(root);
      }
      return root;
    }
    if (root.children != null) {
      for (var child in root.children) {
        var element = _extractTreeElementWithoutChildren(child, mailbox);
        if (element != null) {
          return element;
        }
      }
    }
    return null;
  }

  /// Retrieves the mailbox with the specified [flag] from the provided [boxes]. When no boxes are given, then the `MailClient.mailboxes` are used.
  Mailbox getMailbox(MailboxFlag flag, [List<Mailbox> boxes]) {
    boxes ??= mailboxes;
    return boxes?.firstWhere((box) => box.hasFlag(flag), orElse: () => null);
  }

  /// Retrieves the mailbox with the specified [flag] from the provided [mailboxes].
  List<Mailbox> sortMailboxes(List<MailboxFlag> order, List<Mailbox> mailboxes,
      {bool keepRemaining = true, bool sortRemainingAlphabetically = true}) {
    var inputMailboxes = <Mailbox>[...mailboxes];
    var outputMailboxes = <Mailbox>[];
    for (final flag in order) {
      var box = getMailbox(flag, inputMailboxes);
      if (box != null) {
        outputMailboxes.add(box);
        inputMailboxes.remove(box);
      }
    }
    if (keepRemaining) {
      if (sortRemainingAlphabetically) {
        inputMailboxes.sort((b1, b2) => b1.path.compareTo(b2.path));
      }
      outputMailboxes.addAll(inputMailboxes);
    }
    return outputMailboxes;
  }

  /// Selects the mailbox/folder with the specified [path].
  /// Optionally specify if CONDSTORE support should be enabled with [enableCondstore].
  /// Optionally specify quick resync parameters with [qresync].
  Future<MailResponse<Mailbox>> selectMailboxByPath(String path,
      {bool enableCondstore = false, QResyncParameters qresync}) async {
    var mailboxes = _mailboxes;
    if (mailboxes == null) {
      var flatResponse = await listMailboxes();
      if (flatResponse.isFailedStatus) {
        return MailResponseHelper.failure<Mailbox>(flatResponse.errorId);
      }
      mailboxes = flatResponse.result;
    }
    final mailbox =
        mailboxes.firstWhere((box) => box.path == path, orElse: () => null);
    if (mailbox == null) {
      return MailResponseHelper.failure<Mailbox>('select.mailbox.not.found');
    }
    var response = await _incomingMailClient.selectMailbox(mailbox,
        enableCondstore: enableCondstore, qresync: qresync);
    _selectedMailbox = response.result;
    return response;
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

  /// Loads the specified page of messages starting at the latest message and going down [count] messages.
  /// Specify segment's number with [page] - by default this is 1, so the first segment is downloaded.
  /// Optionally specify the [mailbox] in case none has been selected before or if another mailbox/folder should be queried.
  /// Optionally specify the [fetchPreference] to define the preferred downloaded scope.
  /// By default  messages that are within the size bounds as defined in the `downloadSizeLimit`
  /// in the `MailClient`s constructor are donwloaded fully.
  /// Note that the preference cannot be realized on some backends such as POP3 mail servers.
  Future<MailResponse<List<MimeMessage>>> fetchMessages(
      {Mailbox mailbox,
      int count = 20,
      int page = 1,
      FetchPreference fetchPreference}) async {
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
        mailbox: mailbox,
        count: count,
        page: page,
        fetchPreference: fetchPreference);
  }

  /// Loads the specified sequence of messages.
  /// Optionally specify the [mailbox] in case none has been selected before or if another mailbox/folder should be queried.
  /// Optionally specify the [fetchPreference] to define the preferred downloaded scope.
  /// By default  messages that are within the size bounds as defined in the `downloadSizeLimit`
  /// in the `MailClient`s constructor are donwloaded fully.
  /// Set [markAsSeen] to `true` to automatically add the `\Seen` flag in case it is not there yet when downloading the `fetchPreference.full`.
  /// Note that the preference cannot be realized on some backends such as POP3 mail servers.
  Future<MailResponse<List<MimeMessage>>> fetchMessageSequence(
      MessageSequence sequence,
      {Mailbox mailbox,
      FetchPreference fetchPreference,
      bool markAsSeen}) async {
    mailbox ??= _selectedMailbox;
    if (mailbox == null) {
      throw StateError('Either specify a mailbox or select a mailbox first');
    }
    if (mailbox != _selectedMailbox) {
      var selectResponse = await selectMailbox(mailbox);
      if (selectResponse.isFailedStatus) {
        return MailResponseHelper.failure<List<MimeMessage>>('select');
      }
    }
    return _incomingMailClient.fetchMessageSequence(sequence,
        fetchPreference: fetchPreference, markAsSeen: markAsSeen);
  }

  /// Fetches the contents of the specified [message].
  /// This can be useful when you have specified an automatic download
  /// limit with `downloadSizeLimit` in the MailClient's constructor or when you have specified a `fetchPreference` in `fetchMessages`.
  /// Optionally specify the [maxSize] in bytes to not download attachments of the message. The `maxSize` is ignored over POP.
  /// Optionally set [markAsSeen] to `true` in case the message should be flagged as `\Seen` if not already done.
  Future<MailResponse<MimeMessage>> fetchMessageContents(MimeMessage message,
      {int maxSize, bool markAsSeen}) {
    return _incomingMailClient.fetchMessageContents(message,
        maxSize: maxSize, markAsSeen: markAsSeen);
  }

  /// Fetches the part with the specified [fetchId] of the specified [message].
  /// This can be useful when you have specified an automatic download
  /// limit with [downloadSizeLimit] in the MailClient's constructor and want to download an individual attachment, for example.
  /// Note that this is only possible when the user is connected via IMAP and not via POP.
  /// Compare [lowLevelIncomingMailClientType].
  Future<MailResponse<MimePart>> fetchMessagePart(
      MimeMessage message, String fetchId) {
    return _incomingMailClient.fetchMessagePart(message, fetchId);
  }

  /// Sends the specified [message].
  /// Use [MessageBuilder] to create new messages.
  /// Specify [from] as the originator in case it differs from the `From` header of the message.
  Future<MailResponse> sendMessage(MimeMessage message,
      {MailAddress from}) async {
    var response = await _outgoingMailClient.sendMessage(message, from: from);
    await _outgoingMailClient.disconnect();
    return response;
  }

  /// Starts listening for new incoming messages.
  /// Listen for [MailLoadEvent] on the [eventBus] to get notified about new messages.
  Future<void> startPolling([Duration duration = defaultPollingDuration]) {
    return _incomingMailClient.startPolling(duration);
  }

  /// Stops listening for new messages.
  Future<void> stopPolling() {
    return _incomingMailClient.stopPolling();
  }

  /// Stops listening for new messages if this client is currently polling.
  Future<void> stopPollingIfNeeded() {
    if (_incomingMailClient.isPolling()) {
      return _incomingMailClient.stopPolling();
    }
    return Future.value();
  }

  /// Checks if this mail client is currently polling.
  bool isPolling() {
    return _incomingMailClient.isPolling();
  }

  /// Resumes the mail client after a some inactivity.
  /// Reconnects the mail client in the background, if necessary.
  Future<void> resume() async {
    if (isPolling()) {
      await stopPolling();
      await startPolling();
    }
  }

  /// Determines if message flags such as `\Seen` can be stored.
  /// POP3 servers do not support message flagging, for example.
  /// Note that even on POP3 servers the \Deleted "flag" can be set. However, messages are really deleted
  /// and cannot be retrieved after marking them as deleted after the current POP3 session is closed.
  bool supportsFlagging() {
    return _incomingMailClient.supportsFlagging();
  }

  /// Convenience method for marking the messages from the specified [sequence] as seen/read.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store()] method in case you need more control or want to change several flags.
  Future<MailResponse> markSeen(MessageSequence sequence,
      {int unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.seen],
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as unseen/unread.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store()] method in case you need more control or want to change several flags.
  Future<MailResponse> markUnseen(MessageSequence sequence,
      {int unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.seen],
        action: StoreAction.remove,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as flagged.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store()] method in case you need more control or want to change several flags.
  Future<MailResponse> markFlagged(MessageSequence sequence,
      {int unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.flagged],
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as unflagged.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store()] method in case you need more control or want to change several flags.
  Future<MailResponse> markUnflagged(MessageSequence sequence,
      {int unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.flagged],
        action: StoreAction.remove,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as deleted.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store()] method in case you need more control or want to change several flags.
  Future<MailResponse> markDeleted(MessageSequence sequence,
      {int unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.deleted],
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as not deleted.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store()] method in case you need more control or want to change several flags.
  Future<MailResponse> markUndeleted(MessageSequence sequence,
      {int unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.deleted],
        action: StoreAction.remove,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as answered.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [uidStore()] method in case you need more control or want to change several flags.
  Future<MailResponse> markAnswered(MessageSequence sequence,
      {int unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.answered],
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as not answered.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [uidStore()] method in case you need more control or want to change several flags.
  Future<MailResponse> markUnanswered(MessageSequence sequence,
      {int unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.answered],
        action: StoreAction.remove,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as forwarded.
  /// Note this uses the common but not-standarized `$Forwarded` keyword flag.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store()] method in case you need more control or want to change several flags.
  Future<MailResponse> markForwarded(MessageSequence sequence,
      {bool silent, int unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.keywordForwarded],
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as not forwarded.
  /// Note this uses the common but not-standarized `$Forwarded` keyword flag.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store()] method in case you need more control or want to change several flags.
  Future<MailResponse> markUnforwarded(MessageSequence sequence,
      {int unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.keywordForwarded],
        action: StoreAction.remove,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Flags the [message] with the specified flags.
  /// Set any bool parameter to either `true` or `false` if you want to change the corresponding flag.
  /// Keep a parameter `null` to not change the corresponding flag.
  Future<MailResponse> flagMessage(MimeMessage message,
      {bool isSeen,
      bool isFlagged,
      bool isAnswered,
      bool isForwarded,
      bool isDeleted,
      bool isMdnSent}) {
    if (isSeen != null) {
      message.isSeen = isSeen;
    }
    if (isFlagged != null) {
      message.isFlagged = isFlagged;
    }
    if (isAnswered != null) {
      message.isAnswered = isAnswered;
    }
    if (isForwarded != null) {
      message.isForwarded = isForwarded;
    }
    if (isDeleted != null) {
      message.isDeleted = isDeleted;
    }
    if (isMdnSent != null) {
      message.isMdnSent = isMdnSent;
    }
    if (message.flags != null) {
      final sequence = MessageSequence.fromMessage(message);
      var flags = [...message.flags];
      flags.remove(MessageFlags.recent);
      return store(sequence, flags, action: StoreAction.replace);
    } else {
      return Future.value(MailResponseHelper.failure('flags.not.defined'));
    }
  }

  /// Stores the specified message [flags] for the given message [sequence].
  /// By default the flags are added, but you can specify a different store [action].
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability.
  /// Call [supportsFlagging()] first to determine if the mail server supports flagging at all.
  Future<MailResponse> store(MessageSequence sequence, List<String> flags,
      {StoreAction action = StoreAction.add, int unchangedSinceModSequence}) {
    return _incomingMailClient.store(
        sequence, flags, action, unchangedSinceModSequence);
  }

  /// Deletes the given [message].
  /// Depending on the service capabalities either the message is moved to the trash, copied to the trash or just flagged as deleted.
  /// Returns a `DeleteResult` that can be used for an undo operation,
  /// compare [undoDeleteMessages()].
  Future<MailResponse<DeleteResult>> deleteMessage(MimeMessage message) {
    return deleteMessages(MessageSequence.fromMessage(message));
  }

  /// Deletes the given message [sequence].
  /// Depending on the service capabalities either the sequence is moved to the trash, copied to the trash or just flagged as deleted.
  /// Returns a `DeleteResult` that can be used for an undo operation,
  /// compare [undoDeleteMessages()].
  Future<MailResponse<DeleteResult>> deleteMessages(MessageSequence sequence) {
    final trashMailbox = getMailbox(MailboxFlag.trash);
    return _incomingMailClient.deleteMessages(sequence, trashMailbox);
  }

  /// Reverts the previous [deleteResult], note that is only possible when
  /// `deleteResult.isUndoable` is `true`.
  Future<MailResponse<DeleteResult>> undoDeleteMessages(
      DeleteResult deleteResult) {
    return _incomingMailClient.undoDeleteMessages(deleteResult);
  }

  /// Deletes all messages from the specified [mailbox].
  /// Optionally set [expunge] to `true` to clear the messages directly from disk on IMAP servers. In that case, the delete operation cannot be undone.
  Future<MailResponse<DeleteResult>> deleteAllMessages(Mailbox mailbox,
      {bool expunge}) async {
    final response =
        await _incomingMailClient.deleteAllMessages(mailbox, expunge: expunge);
    if (response.isOkStatus) {
      mailbox.messagesExists = 0;
      mailbox.messagesRecent = 0;
      mailbox.messagesUnseen = 0;
    }
    return response;
  }
}

abstract class _IncomingMailClient {
  final MailClient mailClient;
  Object get client;
  ServerType get clientType;
  int downloadSizeLimit;
  bool _isLogEnabled;
  EventBus _eventBus;
  final MailServerConfig _config;
  Mailbox _selectedMailbox;
  Future Function() _pollImplementation;
  Duration _pollDuration;
  Timer _pollTimer;

  _IncomingMailClient(this.downloadSizeLimit, this._config, this.mailClient);

  Future<MailResponse> connect();

  Future disconnect();

  Future<MailResponse<List<Mailbox>>> listMailboxes();

  Future<MailResponse<Mailbox>> selectMailbox(Mailbox mailbox,
      {bool enableCondstore = false, QResyncParameters qresync});

  Future<MailResponse<List<MimeMessage>>> fetchMessages(
      {Mailbox mailbox,
      int count = 20,
      int page = 1,
      FetchPreference fetchPreference});

  Future<MailResponse<List<MimeMessage>>> fetchMessageSequence(
      MessageSequence sequence,
      {FetchPreference fetchPreference,
      bool markAsSeen});

  Future<MailResponse<MimeMessage>> fetchMessageContents(MimeMessage message,
      {int maxSize, bool markAsSeen});

  Future<MailResponse<MimePart>> fetchMessagePart(
      MimeMessage message, String fetchId);

  Future<MailResponse<List<MimeMessage>>> poll();

  bool supportsFlagging();

  Future<MailResponse> store(MessageSequence sequence, List<String> flags,
      StoreAction action, int unchangedSinceModSequence);

  Future<MailResponse<DeleteResult>> deleteMessages(
      MessageSequence sequence, Mailbox trashMailbox);

  Future<MailResponse<DeleteResult>> undoDeleteMessages(
      DeleteResult deleteResult);

  Future<MailResponse<DeleteResult>> deleteAllMessages(Mailbox mailbox,
      {bool expunge});

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

  bool isPolling() {
    return _pollTimer?.isActive ?? false;
  }

  void _poll(Timer timer) async {
    await _pollImplementation();
  }
}

class _IncomingImapClient extends _IncomingMailClient {
  @override
  Object get client => _imapClient;
  @override
  ServerType get clientType => ServerType.imap;
  ImapClient _imapClient;
  bool _isQResyncEnabled = false;
  bool _supportsIdle = false;
  bool _isInIdleMode = false;
  final List<MimeMessage> _fetchMessages = <MimeMessage>[];
  bool _isReconnecting = false;
  final List<ImapEvent> _imapEventsDuringReconnecting = <ImapEvent>[];
  int _reconnectCounter = 0;
  bool _isIdlePaused = false;

  _IncomingImapClient(
      int downloadSizeLimit,
      EventBus eventBus,
      bool isLogEnabled,
      MailServerConfig config,
      String logName,
      MailClient mailClient)
      : super(downloadSizeLimit, config, mailClient) {
    _imapClient =
        ImapClient(bus: eventBus, isLogEnabled: isLogEnabled, logName: logName);
    _eventBus = eventBus;
    _isLogEnabled = isLogEnabled;
    eventBus.on<ImapEvent>().listen(_onImapEvent);
  }

  void _onImapEvent(ImapEvent event) async {
    if (event.imapClient != _imapClient) {
      return; // ignore events from other imap clients
    }
    // print(
    //     'imap event: ${event.eventType} - is currently currently reconnecting: $_isReconnecting');
    if (_isReconnecting && event.eventType != ImapEventType.connectionLost) {
      _imapEventsDuringReconnecting.add(event);
      return;
    }
    switch (event.eventType) {
      case ImapEventType.fetch:
        var message = (event as ImapFetchEvent).message;
        if (message.flags != null) {
          mailClient._fireEvent(MailUpdateEvent(message, mailClient));
        }
        // MailResponse<MimeMessage> response;
        // print('fetching message based on ImapFetchEvent...');
        // if (message.uid != null) {
        //   response = await fetchMessage(message.uid, true);
        // } else {
        //   response = await fetchMessage(message.sequenceId, false);
        // }
        // if (response.isOkStatus) {
        //   message = response.result;
        // }
        // mailClient._fireEvent(MailLoadEvent(message, mailClient));
        // _fetchMessages.add(message);
        break;
      case ImapEventType.exists:
        var evt = event as ImapMessagesExistEvent;
        //print(
        //    'exists event: new=${evt.newMessagesExists}, old=${evt.oldMessagesExists}, selected=${_selectedMailbox.messagesExists}');
        if (evt.newMessagesExists <= evt.oldMessagesExists) {
          // this is just an update eg after an EXPUNGE event
          // ignore:
          break;
        }
        var sequence = MessageSequence();
        if (evt.newMessagesExists - evt.oldMessagesExists > 1) {
          sequence.addRange(evt.oldMessagesExists, evt.newMessagesExists);
        } else {
          sequence.add(evt.newMessagesExists);
        }
        print('fetching message based on ImapMessagesExistEvent...');
        var response = await fetchMessageSequence(sequence);
        if (response.isOkStatus) {
          for (var message in response.result) {
            mailClient._fireEvent(MailLoadEvent(message, mailClient));
            _fetchMessages.add(message);
          }
        }
        break;
      case ImapEventType.vanished:
        var evt = event as ImapVanishedEvent;
        mailClient._fireEvent(
            MailVanishedEvent(evt.vanishedMessages, evt.isEarlier, mailClient));
        break;
      case ImapEventType.expunge:
        var evt = event as ImapExpungeEvent;
        mailClient._fireEvent(MailVanishedEvent(
            MessageSequence.fromId(evt.messageSequenceId), false, mailClient));
        break;
      case ImapEventType.connectionLost:
        _isReconnecting = true;
        unawaited(reconnect());
        break;
      case ImapEventType.recent:
        // ignore the recent event for now
        break;
    }
  }

  Future<void> _pauseIdle() {
    if (_isInIdleMode && !_isIdlePaused) {
      _isIdlePaused = true;
      return stopPolling();
    }
    return Future.value();
  }

  Future<void> _resumeIdle() async {
    if (_isIdlePaused) {
      try {
        await startPolling(_pollDuration);
        _isIdlePaused = false;
      } catch (e) {
        print('Error while resume IDLE: $e');
      }
    }
  }

  Future reconnect() async {
    print('reconnecting....');
    var restartPolling = (_pollTimer != null);
    if (restartPolling) {
      // turn off idle mode as this is an error case in which the client cannot send 'DONE' to the server anyhow.
      _isInIdleMode = false;
      await stopPolling();
    }
    _reconnectCounter++;
    var counter = _reconnectCounter;
    final box = _selectedMailbox;
    while (counter == _reconnectCounter) {
      try {
        print('trying to connect...');
        await connect();
        print('connected.');
        _isInIdleMode = false;
        if (box != null) {
          //TODO check with previous modification sequence and download new messages
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
      if (_imapClient.serverInfo.capabilities?.isEmpty ?? true) {
        await _imapClient.capability();
      }
      _config.serverCapabilities = _imapClient.serverInfo.capabilities;
      var enableCaps = <String>[];
      if (_config.supports('QRESYNC')) {
        enableCaps.add('QRESYNC');
      }
      if (_config.supports('UTF8=ACCEPT') || _config.supports('UTF8=ONLY')) {
        enableCaps.add('UTF8=ACCEPT');
      }
      if (enableCaps.isNotEmpty) {
        await _imapClient.enable(enableCaps);
        _isQResyncEnabled = _imapClient.serverInfo.isEnabled('QRESYNC');
      }

      _supportsIdle = _config.supports('IDLE');
    }
    return response;
  }

  @override
  Future disconnect() {
    if (_imapClient != null) {
      return _imapClient.closeConnection();
    }
    return Future.value();
  }

  @override
  Future<MailResponse<List<Mailbox>>> listMailboxes() async {
    await _pauseIdle();
    var mailboxResponse = await _imapClient.listMailboxes(recursive: true);
    if (mailboxResponse.isFailedStatus) {
      var errorId = 'list';
      return MailResponseHelper.failure<List<Mailbox>>(errorId);
    }
    var separator = _imapClient.serverInfo.pathSeparator;
    _config.pathSeparator = separator;
    await _resumeIdle();
    return MailResponseHelper.createFromImap<List<Mailbox>>(mailboxResponse);
  }

  @override
  Future<MailResponse<Mailbox>> selectMailbox(Mailbox mailbox,
      {bool enableCondstore = false, QResyncParameters qresync}) async {
    await _pauseIdle();
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
    await _resumeIdle();
    return MailResponseHelper.createFromImap<Mailbox>(imapResponse);
  }

  @override
  Future<MailResponse<List<MimeMessage>>> fetchMessages(
      {Mailbox mailbox,
      int count = 20,
      int page = 1,
      bool downloadContent,
      FetchPreference fetchPreference = FetchPreference.full}) {
    if (mailbox.messagesExists == 0) {
      // should the mailbox status be updated first?
      return Future.value(MailResponseHelper.success(<MimeMessage>[]));
    }
    var sequence = MessageSequence.fromAll();
    if (count != null) {
      var end = mailbox.messagesExists;
      if (page != null) {
        end -= (page - 1) * count;
        if (end < 1) {
          end = 1;
        }
      }
      var start = end - count;
      if (start < 1) {
        start = 1;
      }
      sequence = MessageSequence.fromRange(start, end);
    }
    return fetchMessageSequence(sequence, fetchPreference: fetchPreference);
  }

  @override
  Future<MailResponse<List<MimeMessage>>> fetchMessageSequence(
      MessageSequence sequence,
      {FetchPreference fetchPreference,
      bool markAsSeen}) async {
    try {
      await _pauseIdle();
      String criteria;
      fetchPreference ??= (downloadSizeLimit == null)
          ? FetchPreference.full
          : FetchPreference.envelope;
      switch (fetchPreference) {
        case FetchPreference.envelope:
          criteria = '(UID FLAGS RFC822.SIZE ENVELOPE)';
          break;
        case FetchPreference.bodystructure:
          criteria = '(UID FLAGS RFC822.SIZE BODYSTRUCTURE)';
          break;
        case FetchPreference.full:
          if (markAsSeen == true) {
            criteria = '(UID FLAGS RFC822.SIZE BODY[])';
          } else {
            criteria = '(UID FLAGS RFC822.SIZE BODY.PEEK[])';
          }
          break;
      }

      var response = sequence.isUidSequence ?? false
          ? await _imapClient.uidFetchMessages(sequence, criteria)
          : await _imapClient.fetchMessages(sequence, criteria);
      if (response.isFailedStatus) {
        return MailResponseHelper.failure<List<MimeMessage>>('fetch');
      }
      if (response.result.vanishedMessagesUidSequence?.isNotEmpty() ?? false) {
        mailClient._fireEvent(MailVanishedEvent(
            response.result.vanishedMessagesUidSequence, false, mailClient));
      }
      if (fetchPreference == FetchPreference.full &&
          downloadSizeLimit != null) {
        var smallEnoughMessages = response.result.messages
            .where((msg) => msg.size < downloadSizeLimit);
        sequence = MessageSequence();
        for (var msg in smallEnoughMessages) {
          sequence.add(msg.uid);
        }
        response = await _imapClient.fetchMessages(
            sequence, '(UID FLAGS BODY.PEEK[])');
        if (response.isFailedStatus) {
          return MailResponseHelper.failure<List<MimeMessage>>('fetch');
        }
      }
      response.result.messages
          .sort((msg1, msg2) => msg2.sequenceId.compareTo(msg1.sequenceId));
      return MailResponseHelper.success<List<MimeMessage>>(
          response.result.messages);
    } catch (e, s) {
      print('error while fetching: $e');
      print(s);
      return MailResponseHelper.failure<List<MimeMessage>>('fetch');
    } finally {
      await _resumeIdle();
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
  Future<MailResponse<MimePart>> fetchMessagePart(
      MimeMessage message, String fetchId) async {
    Response<FetchImapResult> imapResponse;
    await _pauseIdle();
    try {
      if (message.uid != null) {
        imapResponse =
            await _imapClient.uidFetchMessage(message.uid, '(BODY[$fetchId])');
      } else {
        imapResponse = await _imapClient.fetchMessage(
            message.sequenceId, '(BODY[$fetchId])');
      }
      if (imapResponse.isOkStatus &&
          imapResponse.result.messages?.length == 1) {
        var part = imapResponse.result.messages.first.getPart(fetchId);
        message.setPart(fetchId, part);
        return MailResponseHelper.success<MimePart>(part);
      } else {
        return MailResponseHelper.failure<MimePart>('fetch');
      }
    } finally {
      await _resumeIdle();
    }
  }

  @override
  Future<void> startPolling(Duration duration,
      {Future Function() pollImplementation}) {
    if (_supportsIdle) {
      // IMAP Idle timeout is 30 minutes, so official recommendation is to restart IDLE every 29 minutes.
      // Here is a shorter duration chosen, so that connection problems are detected earlier.
      if (duration == null || duration == MailClient.defaultPollingDuration) {
        duration = Duration(minutes: 5);
      }
      pollImplementation ??= _restartIdlePolling;
      _isInIdleMode = true;
      return _imapClient.idleStart();
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

  @override
  bool isPolling() {
    return _isInIdleMode || super.isPolling();
  }

  Future _restartIdlePolling() async {
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

  @override
  Future<MailResponse> store(MessageSequence sequence, List<String> flags,
      StoreAction action, int unchangedSinceModSequence) async {
    await _pauseIdle();
    try {
      Response<StoreImapResult> storeResult;
      if (sequence.isUidSequence ?? false) {
        storeResult = await _imapClient.uidStore(sequence, flags,
            action: action,
            silent: true,
            unchangedSinceModSequence: unchangedSinceModSequence);
      } else {
        storeResult = await _imapClient.store(sequence, flags,
            action: action,
            silent: true,
            unchangedSinceModSequence: unchangedSinceModSequence);
      }
      return MailResponseHelper.createFromImap(storeResult);
    } finally {
      await _resumeIdle();
    }
  }

  @override
  bool supportsFlagging() {
    return true;
  }

  @override
  Future<MailResponse<MimeMessage>> fetchMessageContents(
      final MimeMessage message,
      {int maxSize,
      bool markAsSeen}) async {
    if ((maxSize == null) ||
        (message.size < maxSize) ||
        (message.getHeaderContentType()?.mediaType?.top !=
            MediaToptype.multipart)) {
      final response = await fetchMessageSequence(
          MessageSequence.fromMessage(message),
          fetchPreference: FetchPreference.full,
          markAsSeen: markAsSeen);
      if (response.isOkStatus && (response.result?.isNotEmpty ?? false)) {
        return MailResponse<MimeMessage>()
          ..isOkStatus = true
          ..result = response.result.last;
      }
    } else {
      await _pauseIdle();
      final sequence = MessageSequence.fromMessage(message);
      var imapResponse = sequence.isUidSequence
          ? await _imapClient.uidFetchMessages(sequence, '(BODYSTRUCTURE)')
          : await _imapClient.fetchMessages(sequence, '(BODYSTRUCTURE)');
      if (imapResponse.isOkStatus &&
          (imapResponse.result?.messages?.isNotEmpty ?? false) &&
          (imapResponse.result.messages.first.body != null)) {
        // download all non-attachment parts:
        final matchingContents = <ContentInfo>[];
        final body = imapResponse.result.messages.first.body;
        body.collectContentInfo(ContentDisposition.attachment, matchingContents,
            reverse: true);
        final buffer = StringBuffer();
        buffer.write('(');
        var addSpace = false;
        for (final contentInfo in matchingContents) {
          if (addSpace) {
            buffer.write(' ');
          }
          if (markAsSeen == true) {
            buffer.write('BODY[');
          } else {
            buffer.write('BODY.PEEK[');
          }
          buffer..write(contentInfo.fetchId)..write(']');
          addSpace = true;
        }
        buffer.write(')');
        final criteria = buffer.toString();
        imapResponse = sequence.isUidSequence
            ? await _imapClient.uidFetchMessages(sequence, criteria)
            : await _imapClient.fetchMessages(sequence, criteria);
        if (imapResponse.isOkStatus &&
            (imapResponse?.result?.messages?.isNotEmpty ?? false)) {
          await _resumeIdle();
          final result = imapResponse.result.messages.first;
          // copy all data into original message, so that envelope and flags information etc is being kept:
          message.body = body;
          message.copyIndividualParts(result);
          return MailResponseHelper.success(message);
        }
      }
      await _resumeIdle();
    }
    return MailResponseHelper.failure('error.fetchContent');
  }

  @override
  Future<MailResponse<DeleteResult>> deleteMessages(
      MessageSequence sequence, Mailbox trashMailbox) async {
    if (trashMailbox == null || trashMailbox == _selectedMailbox) {
      await store(sequence, [MessageFlags.deleted], StoreAction.add, null);
      return MailResponseHelper.success(DeleteResult(true, DeleteAction.flag,
          sequence, _selectedMailbox, sequence, _selectedMailbox));
    } else {
      await _pauseIdle();
      DeleteAction deleteAction;
      Response<GenericImapResult> response;
      if (_imapClient.serverInfo.supports('MOVE')) {
        deleteAction = DeleteAction.move;
        if (sequence.isUidSequence) {
          response =
              await _imapClient.uidMove(sequence, targetMailbox: trashMailbox);
        } else {
          response =
              await _imapClient.move(sequence, targetMailbox: trashMailbox);
        }
      } else {
        deleteAction = DeleteAction.copy;

        if (sequence.isUidSequence) {
          response =
              await _imapClient.uidCopy(sequence, targetMailbox: trashMailbox);
        } else {
          response =
              await _imapClient.copy(sequence, targetMailbox: trashMailbox);
          if (response.isOkStatus) {
            await store(
                sequence, [MessageFlags.deleted], StoreAction.add, null);
          }
        }
      }
      // note: explicitely do not EXPUNGE after delete, so that undo becomes easier
      final copyUid = response.result?.responseCodeCopyUid;
      if (!response.isOkStatus || copyUid == null) {
        return MailResponseHelper.failure('delete');
      }
      await _resumeIdle();
      // copy and move commands result in a mapping sequence which is relevant for undo operations:
      return MailResponseHelper.success(DeleteResult(true, deleteAction,
          sequence, _selectedMailbox, copyUid.targetSequence, trashMailbox));
    }
  }

  @override
  Future<MailResponse<DeleteResult>> undoDeleteMessages(
      DeleteResult deleteResult) async {
    switch (deleteResult.action) {
      case DeleteAction.flag:
        await store(deleteResult.originalSequence, [MessageFlags.deleted],
            StoreAction.remove, null);
        break;
      case DeleteAction.move:
        await _pauseIdle();
        await _imapClient.closeMailbox();
        await _imapClient.selectMailbox(deleteResult.targetMailbox);

        if (deleteResult.targetSequence.isUidSequence) {
          await _imapClient.uidMove(deleteResult.targetSequence,
              targetMailbox: deleteResult.originalMailbox);
        } else {
          await _imapClient.move(deleteResult.targetSequence,
              targetMailbox: deleteResult.originalMailbox);
        }
        await _imapClient.closeMailbox();
        await _imapClient.selectMailbox(deleteResult.originalMailbox);
        await _resumeIdle();
        break;
      case DeleteAction.copy:
        await _pauseIdle();
        if (deleteResult.originalSequence.isUidSequence) {
          await _imapClient.uidStore(
              deleteResult.originalSequence, [MessageFlags.deleted],
              action: StoreAction.remove);
        } else {
          await _imapClient.store(
              deleteResult.originalSequence, [MessageFlags.deleted],
              action: StoreAction.remove);
        }
        await _imapClient.closeMailbox();
        await _imapClient.selectMailbox(deleteResult.targetMailbox);
        if (deleteResult.targetSequence.isUidSequence) {
          await _imapClient.uidStore(
              deleteResult.targetSequence, [MessageFlags.deleted],
              action: StoreAction.add);
        } else {
          await _imapClient.store(
              deleteResult.targetSequence, [MessageFlags.deleted],
              action: StoreAction.add);
        }

        await _imapClient.closeMailbox();
        await _imapClient.selectMailbox(deleteResult.originalMailbox);
        await _resumeIdle();
        break;
      case DeleteAction.pop:
        throw StateError('POP delete action not expected for IMAP connection.');
        break;
    }
    return MailResponseHelper.success(deleteResult.reverse());
  }

  @override
  Future<MailResponse<DeleteResult>> deleteAllMessages(Mailbox mailbox,
      {bool expunge}) async {
    var undoable = true;
    final sequence = MessageSequence.fromAll();
    final selectedMailbox = _selectedMailbox;
    await _pauseIdle();
    if (mailbox != selectedMailbox) {
      await _imapClient.selectMailbox(mailbox);
    }
    await _imapClient.markDeleted(sequence, silent: true);
    if (expunge == true) {
      undoable = false;
      await _imapClient.expunge();
    }
    if (selectedMailbox != mailbox) {
      await _imapClient.selectMailbox(selectedMailbox);
    }
    await _resumeIdle();
    return MailResponseHelper.success(DeleteResult(
        undoable, DeleteAction.flag, sequence, mailbox, null, null));
  }
}

class _IncomingPopClient extends _IncomingMailClient {
  @override
  Object get client => _popClient;
  @override
  ServerType get clientType => ServerType.pop;

  List<MessageListing> _popMessageListing;
  final Mailbox _popInbox =
      Mailbox.setup('Inbox', 'Inbox', [MailboxFlag.inbox]);

  PopClient _popClient;
  _IncomingPopClient(int downloadSizeLimit, EventBus eventBus,
      bool isLogEnabled, MailServerConfig config, MailClient mailClient)
      : super(downloadSizeLimit, config, mailClient) {
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
  Future disconnect() {
    if (_popClient != null) {
      return _popClient.closeConnection();
    }
    return Future.value();
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
      {Mailbox mailbox,
      int count = 20,
      int page = 1,
      FetchPreference fetchPreference}) async {
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
        var messageResponse = await _popClient.retrieve(id);
        if (messageResponse.isOkStatus) {
          var message = messageResponse.result;
          messages.add(message);
          mailClient._fireEvent(MailLoadEvent(message, mailClient));
        }
      }
    }
    return MailResponseHelper.success<List<MimeMessage>>(messages);
  }

  @override
  Future<MailResponse<List<MimeMessage>>> fetchMessageSequence(
      MessageSequence sequence,
      {FetchPreference fetchPreference,
      bool markAsSeen}) async {
    var ids = sequence.toList(_selectedMailbox?.messagesExists);
    var messages = <MimeMessage>[];
    for (var id in ids) {
      var messageResponse = await _popClient.retrieve(id);
      if (messageResponse.isOkStatus) {
        var message = messageResponse.result;
        messages.add(message);
      }
    }
    return MailResponseHelper.success<List<MimeMessage>>(messages);
  }

  @override
  Future<MailResponse> store(MessageSequence sequence, List<String> flags,
      StoreAction action, int unchangedSinceModSequence) async {
    if (flags.length == 1 && flags.first == MessageFlags.deleted) {
      if (action == StoreAction.remove) {
        var resetResponse = await _popClient.reset();
        return MailResponseHelper.createFromPop(resetResponse);
      }
      var ids = sequence.toList(_selectedMailbox?.messagesExists);
      for (var id in ids) {
        var deleteResponse = await _popClient.delete(id);
        if (deleteResponse.isFailedStatus) {
          return MailResponseHelper.failure('delete.failed');
        }
      }
      return MailResponseHelper.success(ids);
    }
    throw StateError('POP does not support storing flags.');
  }

  @override
  bool supportsFlagging() {
    return false;
  }

  @override
  Future<MailResponse<MimePart>> fetchMessagePart(
      MimeMessage message, String fetchId) {
    throw StateError('POP does not support fetching message parts.');
  }

  @override
  Future<MailResponse<MimeMessage>> fetchMessageContents(MimeMessage message,
      {int maxSize, bool markAsSeen}) async {
    final id = message.sequenceId;
    var messageResponse = await _popClient.retrieve(id);
    return MailResponseHelper.createFromPop<MimeMessage>(messageResponse);
  }

  @override
  Future<MailResponse<DeleteResult>> deleteMessages(
      MessageSequence sequence, Mailbox trashMailbox) async {
    var ids = sequence.toList(_selectedMailbox?.messagesExists);
    for (var id in ids) {
      var deleteResponse = await _popClient.delete(id);
      if (deleteResponse.isFailedStatus) {
        return MailResponseHelper.failure('delete.failed');
      }
    }
    return MailResponseHelper.success(DeleteResult(
        false, DeleteAction.pop, sequence, _selectedMailbox, null, null));
  }

  @override
  Future<MailResponse<DeleteResult>> deleteAllMessages(Mailbox mailbox,
      {bool expunge}) {
    // TODO: implement deleteAllMessages
    throw UnimplementedError();
  }

  @override
  Future<MailResponse<DeleteResult>> undoDeleteMessages(
      DeleteResult deleteResult) {
    // TODO: implement undoDeleteMessages
    throw UnimplementedError();
  }
}

abstract class _OutgoingMailClient {
  Object get client;
  ServerType get clientType;
  Future<MailResponse> sendMessage(MimeMessage message, {MailAddress from});

  Future disconnect();
}

class _OutgoingSmtpClient extends _OutgoingMailClient {
  @override
  Object get client => _smtpClient;
  @override
  ServerType get clientType => ServerType.smtp;

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
  Future<MailResponse> sendMessage(MimeMessage message,
      {MailAddress from}) async {
    var response = await _connectOutgoingIfRequired();
    if (response.isFailedStatus) {
      return response;
    }

    var sendResponse = await _smtpClient.sendMessage(message, from: from);
    if (sendResponse.isFailedStatus) {
      return MailResponseHelper.failure('smtp.send');
    }
    return MailResponseHelper.success(sendResponse.code);
  }

  @override
  Future disconnect() {
    if (_smtpClient != null) {
      return _smtpClient.closeConnection();
    }
    return Future.value();
  }
}
