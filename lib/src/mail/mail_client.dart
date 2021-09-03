import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/util/client_base.dart';
import 'package:event_bus/event_bus.dart';
import 'package:pedantic/pedantic.dart';

import '../imap/imap_search.dart';
import 'mail_search.dart';

/// Definition for optional event filters, compare [MailClient.addEventFilter].
typedef MailEventFilter = bool Function(MailEvent event);

/// The client's preference when fetching messages
enum FetchPreference {
  /// Only envelope data is preferred - this is the fasted option
  envelope,

  /// Only the structural information is preferred
  bodystructure,

  /// The full message details are preferred
  full,

  /// The full message whem the size is within the limits, otherwise envelope
  fullWhenWithinSize,
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
  final int? _downloadSizeLimit;
  final MailAccount _account;

  MailAccount get account => _account;

  /// Callback for refreshing tokens
  Future<OauthToken?> Function(MailClient client, OauthToken expiredToken)?
      _refreshOAuthToken;

  /// Callback for getting notified when the config has changed, ie after an OAuth login token has been refreshed
  Future Function(MailAccount account)? _onConfigChanged;

  /// Checks if the connected service supports threading
  ///
  /// Compare [fetchThreads]
  bool get supportsThreading => _incomingMailClient.supportsThreading;

  bool _isConnected = false;

  /// Checks if this mail client is connected
  ///
  /// Compare [connect]
  bool get isConnected => _isConnected;

  /// event bus for firing and listening to events
  EventBus get eventBus => _eventBus;
  final EventBus _eventBus;

  /// Filter for mail events, allows to subpress events being forwarded to the [eventBus].
  List<MailEventFilter>? _eventFilters;

  final bool _isLogEnabled;

  Mailbox? _selectedMailbox;

  /// Retrieves the currently selected mailbox, if any.
  ///
  /// Compare `selectMailbox(...)`.
  Mailbox? get selectedMailbox => _selectedMailbox;

  List<Mailbox>? _mailboxes;

  /// Retrieves the previously caches mailboxes
  List<Mailbox>? get mailboxes => _mailboxes;

  /// Retrieves the low level mail client for reading mails
  ///
  /// Example:
  /// ```
  /// if (mailClient.lowLevelIncomingMailClientType == ServerType.imap) {
  ///   final imapClient = mailClient.lowLevelIncomingMailClient as ImapClient;
  ///   final response = await imapClient.uidFetchMessage(1232, '(ENVELOPE HEADER[])');
  /// }
  /// ```
  ClientBase get lowLevelIncomingMailClient => _incomingMailClient.client;

  /// Retrieves the type pof the low level mail client, currently either ServerType.imap or ServerType.pop
  ServerType get lowLevelIncomingMailClientType =>
      _incomingMailClient.clientType;

  /// Retrieves the low level mail client for sending mails
  ///
  /// Example:
  /// ```
  /// final smtpClient = mailClient.lowLevelOutgoingMailClient as SmtpClient;
  /// final response = await smtpClient.ehlo();
  /// ```
  ClientBase get lowLevelOutgoingMailClient => _outgoingMailClient.client;

  /// Retrieves the type pof the low level mail client, currently always ServerType.smtp
  ServerType get lowLevelOutgoingMailClientType =>
      _outgoingMailClient.clientType;

  final Id? clientId;
  Id? get serverId => _incomingMailClient.serverId;

  late _IncomingMailClient _incomingMailClient;
  late _OutgoingMailClient _outgoingMailClient;

  /// Creates a new highlevel online mail client for the given [account].
  ///
  /// Specify the account settings with [account].
  /// Set [isLogEnabled] to true to debug connection issues.
  /// Specify the optional [downloadSizeLimit] in bytes to only download messages automatically that are this size or lower.
  /// [onBadCertificate] is an optional handler for unverifiable certificates. The handler receives the [X509Certificate], and can inspect it and decide (or let the user decide) whether to accept the connection or not.  The handler should return true to continue the [SecureSocket] connection.
  /// Set a [clientId] when the ID should be send automatically after logging in for IMAP servers that supports the [IMAP4 ID extension](https://datatracker.ietf.org/doc/html/rfc2971).
  MailClient(
    MailAccount account, {
    bool isLogEnabled = false,
    int? downloadSizeLimit,
    EventBus? eventBus,
    String? logName,
    bool Function(X509Certificate)? onBadCertificate,
    this.clientId,
  })  : _eventBus = eventBus ?? EventBus(),
        _account = account,
        _isLogEnabled = isLogEnabled,
        _downloadSizeLimit = downloadSizeLimit {
    final config = _account.incoming!;
    if (config.serverConfig!.type == ServerType.imap) {
      _incomingMailClient = _IncomingImapClient(
          _downloadSizeLimit, _eventBus, _isLogEnabled, logName, config, this,
          onBadCertificate: onBadCertificate);
    } else if (config.serverConfig!.type == ServerType.pop) {
      _incomingMailClient = _IncomingPopClient(
          _downloadSizeLimit, _eventBus, _isLogEnabled, logName, config, this,
          onBadCertificate: onBadCertificate);
    } else {
      throw StateError(
          'Unsupported incoming server type [${config.serverConfig!.typeName}].');
    }
    final outgoingConfig = _account.outgoing!;
    if (outgoingConfig.serverConfig!.type != ServerType.smtp) {
      print(
          'Warning: unknown outgoing server type ${outgoingConfig.serverConfig!.typeName}.');
    }
    _outgoingMailClient = _OutgoingSmtpClient(
      this,
      _account.outgoingClientDomain,
      _eventBus,
      _isLogEnabled,
      'SMTP-$logName',
      outgoingConfig,
      onBadCertificate: onBadCertificate,
    );
  }

  /// Adds the specified mail event [filter].
  ///
  /// You can use a filter to surpress matching `MailEvent`.
  /// Compare [eventBus].
  void addEventFilter(MailEventFilter filter) {
    _eventFilters ??= <MailEventFilter>[];
    _eventFilters!.add(filter);
  }

  /// Removes the specified mail event [filter].
  ///
  /// Compare `addEventFilter()`.
  void removeEventFilter(MailEventFilter filter) {
    if (_eventFilters != null) {
      _eventFilters!.remove(filter);
      if (_eventFilters!.isEmpty) {
        _eventFilters = null;
      }
    }
  }

  void _fireEvent(MailEvent event) {
    if (_eventFilters != null) {
      for (final filter in _eventFilters!) {
        if (filter(event)) {
          return;
        }
      }
    }
    eventBus.fire(event);
  }

  //Future<List<MimeMessage>> poll(Mailbox mailbox) {}

  /// Connects and authenticates with the specified incoming mail server.
  /// Specify the [refresh] callback in case you support OAuth-based tokens that might have been expired.
  /// Specify the optional [onConfigChanged] callback for persisting a changed token in the account, after it has been refreshed.
  ///
  /// Also compare [disconnect].
  Future<void> connect({
    Future<OauthToken?> Function(MailClient client, OauthToken expiredToken)?
        refresh,
    Future Function(MailAccount account)? onConfigChanged,
  }) async {
    _refreshOAuthToken = refresh;
    _onConfigChanged = onConfigChanged;
    await _prepareConnect();
    await _incomingMailClient.connect();
    _isConnected = true;
  }

  Future _prepareConnect() async {
    final refresh = _refreshOAuthToken;
    if (refresh != null) {
      final auth = account.incoming?.authentication;
      if (auth is OauthAuthentication && auth.token.isExpired) {
        OauthToken? refreshed;
        try {
          refreshed = await refresh(this, auth.token);
        } catch (e, s) {
          final message = 'Unable to refresh token: $e $s';
          throw MailException(this, message, stackTrace: s, details: e);
        }
        if (refreshed == null) {
          throw MailException(this, 'Unable to refresh token');
        }
        final newToken =
            auth.token.copyWith(refreshed.accessToken, refreshed.expiresIn);
        auth.token = newToken;
        final outAuth = account.outgoing?.authentication;
        if (outAuth is OauthAuthentication) {
          outAuth.token = newToken;
        }
        final onConfigChanged = _onConfigChanged;
        if (onConfigChanged != null) {
          try {
            await onConfigChanged(account);
          } catch (e, s) {
            print('Unable to handle onConfigChanged $onConfigChanged: $e $s');
          }
        }
      }
    }
  }

  /// Disconnects from the mail service.
  ///
  /// Also compare [connect].
  Future disconnect() async {
    final futures = <Future>[];
    futures.add(stopPollingIfNeeded());
    futures.add(_incomingMailClient.disconnect());
    futures.add(_outgoingMailClient.disconnect());
    _isConnected = false;
    return Future.wait(futures);
  }

  // Future<MailResponse> tryAuthenticate(
  //     ServerConfig serverConfig, MailAuthentication authentication) {
  //   return authentication.authenticate(this, serverConfig);
  // }

  /// Lists all mailboxes/folders of the incoming mail server.
  ///
  /// Optionally specify the [order] of the mailboxes, matching ones will be served in the given order.
  Future<List<Mailbox>> listMailboxes({List<MailboxFlag>? order}) async {
    var boxes = await _incomingMailClient.listMailboxes();
    _mailboxes = boxes;
    if (order != null) {
      boxes = sortMailboxes(order, boxes);
    }
    return boxes;
  }

  /// Lists all mailboxes/folders of the incoming mail server as a tree in the specified [order].
  ///
  /// Optionally set [createIntermediate] to false, in case not all intermediate folders should be created, if not already present on the server.
  Future<Tree<Mailbox?>> listMailboxesAsTree(
      {bool createIntermediate = true,
      List<MailboxFlag> order = defaultMailboxOrder}) async {
    final mailboxes = _mailboxes ?? await listMailboxes();
    List<Mailbox>? firstBoxes;
    firstBoxes = sortMailboxes(order, mailboxes, keepRemaining: false);
    final boxes = [...mailboxes];
    boxes.sort((b1, b2) => b1.path.compareTo(b2.path));
    final separator = _account.incoming?.pathSeparator ?? '/';
    final tree = Tree<Mailbox?>(null);
    tree.populateFromList(
        boxes,
        (child) => child!.getParent(boxes, separator,
            createIntermediate: createIntermediate));
    final parent = tree.root!;
    final children = parent.children;
    for (var i = firstBoxes.length; --i >= 0;) {
      final box = firstBoxes[i];
      var element = _extractTreeElementWithoutChildren(parent, box);
      if (element != null) {
        if (element.children?.isEmpty ?? true) {
          // this elemement has been removed:
          element.parent = parent;
        } else {
          element = TreeElement<Mailbox?>(box, parent);
        }
        children!.insert(0, element);
      }
    }

    return tree;
  }

  TreeElement<Mailbox?>? _extractTreeElementWithoutChildren(
      TreeElement root, Mailbox mailbox) {
    if (root.value == mailbox) {
      if ((root.children?.isEmpty ?? true) && (root.parent != null)) {
        root.parent!.children!.remove(root);
      }
      return root as TreeElement<Mailbox?>?;
    }
    if (root.children != null) {
      for (final child in root.children!) {
        final element = _extractTreeElementWithoutChildren(child, mailbox);
        if (element != null) {
          return element;
        }
      }
    }
    return null;
  }

  /// Retrieves the mailbox with the specified [flag] from the provided [boxes]. When no boxes are given, then the `MailClient.mailboxes` are used.
  Mailbox? getMailbox(MailboxFlag flag, [List<Mailbox>? boxes]) {
    boxes ??= mailboxes;
    return boxes?.firstWhereOrNull((box) => box.hasFlag(flag));
  }

  /// Retrieves the mailbox with the specified [order] from the provided [mailboxes].
  /// The underlying mailboxes are not changed.
  ///
  /// Set [keepRemaining] to `false` (defaults to `true`) to only return the mailboxes specified by the [order] [MailboxFlag]s.
  /// Set [sortRemainingAlphabetically] to `false` (defaults to `true`) to sort the remaining boxes by name, is only relevant when [keeyRemaining] is `true`.
  List<Mailbox> sortMailboxes(List<MailboxFlag> order, List<Mailbox> mailboxes,
      {bool keepRemaining = true, bool sortRemainingAlphabetically = true}) {
    final inputMailboxes = <Mailbox>[...mailboxes];
    final outputMailboxes = <Mailbox>[];
    for (final flag in order) {
      final box = getMailbox(flag, inputMailboxes);
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
  ///
  /// Optionally specify if CONDSTORE support should be enabled with [enableCondstore].
  /// Optionally specify quick resync parameters with [qresync].
  Future<Mailbox> selectMailboxByPath(String path,
      {bool enableCondstore = false, QResyncParameters? qresync}) async {
    var mailboxes = _mailboxes;
    mailboxes ??= await listMailboxes();
    final mailbox = mailboxes.firstWhereOrNull((box) => box.path == path);
    if (mailbox == null) {
      throw MailException(this, 'Unknown mailbox with path <$path>');
    }
    final box = await _incomingMailClient.selectMailbox(mailbox,
        enableCondstore: enableCondstore, qresync: qresync);
    _selectedMailbox = box;
    return box;
  }

  /// Selects the mailbox/folder with the specified [flag].
  ///
  /// Optionally specify if CONDSTORE support should be enabled with [enableCondstore].
  /// Optionally specify quick resync parameters with [qresync].
  Future<Mailbox> selectMailboxByFlag(MailboxFlag flag,
      {bool enableCondstore = false, QResyncParameters? qresync}) async {
    var mailboxes = _mailboxes;
    mailboxes ??= await listMailboxes();
    final mailbox = getMailbox(flag, mailboxes);
    if (mailbox == null) {
      throw MailException(this, 'Unknown mailbox with flag <$flag>');
    }
    final box = await _incomingMailClient.selectMailbox(mailbox,
        enableCondstore: enableCondstore, qresync: qresync);
    _selectedMailbox = box;
    return box;
  }

  /// Shortcut to select the INBOX.
  ///
  /// Optionally specify if CONDSTORE support should be enabled with [enableCondstore] - for IMAP servers that support CONDSTORE only.
  /// Optionally specify quick resync parameters with [qresync] - for IMAP servers that support QRESYNC only.
  Future<Mailbox> selectInbox(
      {bool enableCondstore = false, QResyncParameters? qresync}) async {
    var mailboxes = _mailboxes;
    mailboxes ??= await listMailboxes();
    var inbox = mailboxes.firstWhereOrNull((box) => box.isInbox);
    inbox ??=
        mailboxes.firstWhereOrNull((box) => box.name.toLowerCase() == 'inbox');
    if (inbox == null) {
      throw MailException(this, 'Unable to find inbox');
    }
    return selectMailbox(inbox,
        enableCondstore: enableCondstore, qresync: qresync);
  }

  /// Selects the specified [mailbox]/folder.
  ///
  /// Optionally specify if CONDSTORE support should be enabled with [enableCondstore].
  /// Optionally specify quick resync parameters with [qresync].
  Future<Mailbox> selectMailbox(Mailbox mailbox,
      {bool enableCondstore = false, QResyncParameters? qresync}) async {
    final box = await _incomingMailClient.selectMailbox(mailbox,
        enableCondstore: enableCondstore, qresync: qresync);
    _selectedMailbox = box;
    return box;
  }

  /// Loads the specified [page] of messages starting at the latest message and going down [count] messages.
  ///
  /// Specify [page] number - by default this is 1, so the first page is downloaded.
  /// Optionally specify the [mailbox] in case none has been selected before or if another mailbox/folder should be queried.
  /// Optionally specify the [fetchPreference] to define the preferred downloaded scope, defaults to `FetchPreference.fullWhenWithinSize`.
  /// By default  messages that are within the size bounds as defined in the `downloadSizeLimit`
  /// in the `MailClient`s constructor are donwloaded fully.
  /// Note that the preference cannot be realized on some backends such as POP3 mail servers.
  Future<List<MimeMessage>> fetchMessages(
      {Mailbox? mailbox,
      int count = 20,
      int page = 1,
      FetchPreference fetchPreference =
          FetchPreference.fullWhenWithinSize}) async {
    mailbox ??= _selectedMailbox;
    if (mailbox == null) {
      throw StateError('Either specify a mailbox or select a mailbox first');
    }
    if (mailbox != _selectedMailbox) {
      await selectMailbox(mailbox);
    }
    return _incomingMailClient.fetchMessages(
        mailbox: mailbox,
        count: count,
        page: page,
        fetchPreference: fetchPreference);
  }

  /// Loads the specified [sequence] of messages.
  ///
  /// Optionally specify the [mailbox] in case none has been selected before or if another mailbox/folder should be queried.
  /// Optionally specify the [fetchPreference] to define the preferred downloaded scope, defaults to `FetchPreference.fullWhenWithinSize`.
  /// Set [markAsSeen] to `true` to automatically add the `\Seen` flag in case it is not there yet when downloading the `fetchPreference.full`.
  /// Note that the preference cannot be realized on some backends such as POP3 mail servers.
  Future<List<MimeMessage>> fetchMessageSequence(MessageSequence sequence,
      {Mailbox? mailbox,
      FetchPreference fetchPreference = FetchPreference.fullWhenWithinSize,
      bool markAsSeen = false}) async {
    mailbox ??= _selectedMailbox;
    if (mailbox == null) {
      throw StateError('Either specify a mailbox or select a mailbox first');
    }
    if (mailbox != _selectedMailbox) {
      await selectMailbox(mailbox);
    }
    return _incomingMailClient.fetchMessageSequence(sequence,
        fetchPreference: fetchPreference, markAsSeen: markAsSeen);
  }

  /// Loads the next page of messages in the given [pagedSequence].
  ///
  /// Optionally specify the [mailbox] in case none has been selected before or if another mailbox/folder should be queried.
  /// Optionally specify the [fetchPreference] to define the preferred downloaded scope, defaults to `FetchPreference.fullWhenWithinSize`.
  /// Set [markAsSeen] to `true` to automatically add the `\Seen` flag in case it is not there yet when downloading the `fetchPreference.full`.
  /// Note that the preference cannot be realized on some backends such as POP3 mail servers.
  Future<List<MimeMessage>> fetchMessagesNextPage(
      PagedMessageSequence pagedSequence,
      {Mailbox? mailbox,
      FetchPreference fetchPreference = FetchPreference.fullWhenWithinSize,
      bool markAsSeen = false}) {
    if (pagedSequence.hasNext) {
      final sequence = pagedSequence.next();
      return fetchMessageSequence(sequence,
          fetchPreference: fetchPreference, markAsSeen: markAsSeen);
    } else {
      return Future.value([]);
    }
  }

  /// Fetches the contents of the specified [message].
  ///
  /// This can be useful when you have specified an automatic download
  /// limit with `downloadSizeLimit` in the MailClient's constructor or when you have specified a `fetchPreference` in `fetchMessages`.
  /// Optionally specify the [maxSize] in bytes to not download attachments of the message. The [maxSize] parameter is ignored over POP.
  /// Optionally set [markAsSeen] to `true` in case the message should be flagged as `\Seen` if not already done.
  /// Optionally specify [includedInlineTypes] to exclude parts with an inline disposition and a different media type than specified.
  Future<MimeMessage> fetchMessageContents(MimeMessage message,
      {int? maxSize,
      bool markAsSeen = false,
      List<MediaToptype>? includedInlineTypes}) {
    return _incomingMailClient.fetchMessageContents(message,
        maxSize: maxSize,
        markAsSeen: markAsSeen,
        includedInlineTypes: includedInlineTypes);
  }

  /// Fetches the part with the specified [fetchId] of the specified [message].
  ///
  /// This can be useful when you have specified an automatic download
  /// limit with [downloadSizeLimit] in the MailClient's constructor and want to download an individual attachment, for example.
  /// Note that this is only possible when the user is connected via IMAP and not via POP.
  /// Compare [lowLevelIncomingMailClientType].
  Future<MimePart> fetchMessagePart(MimeMessage message, String fetchId) {
    return _incomingMailClient.fetchMessagePart(message, fetchId);
  }

  /// Retrieves the threads starting at [since].
  ///
  /// Optionally specify the [mailbox], in case not the currently selected mailbox should be used.
  /// Choose with [threadPreference] if only the latest (default) or all messages should be fetched.
  /// Choose what message data should be fetched using [fetchPreference], which defaults to [FetchPreference.envelope].
  /// Choose the number of downloaded messages with [pageSize], which defaults to `30`.
  /// Note that you can download further pages using [fetchThreadsNextPage].
  /// Compare [supportsThreading].
  Future<ThreadResult> fetchThreads(
      {Mailbox? mailbox,
      required DateTime since,
      ThreadPreference threadPreference = ThreadPreference.latest,
      FetchPreference fetchPreference = FetchPreference.envelope,
      int pageSize = 30}) {
    mailbox ??= _selectedMailbox;
    if (mailbox == null) {
      throw StateError('no mailbox defined nor selected');
    }
    return _incomingMailClient.fetchThreads(
        mailbox, since, threadPreference, fetchPreference, pageSize);
  }

  /// Retrieves the next page for the given [threadResult] and returns the loaded messsages.
  ///
  /// The given [threadResult] will be updated to contain the loaded messages.
  /// Compare [fetchThreads].
  Future<List<MimeMessage>> fetchThreadsNextPage(
      ThreadResult threadResult) async {
    final messages = await fetchMessagesNextPage(threadResult.threadSequence,
        fetchPreference: threadResult.fetchPreference);
    threadResult.addAll(messages);
    return messages;
  }

  /// Retrieves thread information starting at [since].
  ///
  /// When you set [setThreadSequences] to `true`, then the [MimeMessage.threadSequence] will be populated automatically for future fetched mesages.
  /// Optionally specify the [mailbox], in case not the currently selected mailbox should be used.
  /// Compare [supportsThreading].
  Future<ThreadDataResult> fetchThreadData({
    Mailbox? mailbox,
    required DateTime since,
    bool setThreadSequences = false,
  }) {
    mailbox ??= _selectedMailbox;
    if (mailbox == null) {
      throw StateError('no mailbox defined nor selected');
    }
    return _incomingMailClient.fetchThreadData(
        mailbox, since, setThreadSequences);
  }

  /// Builds the mime message from the given [messageBuilder] with the recommended text encodings.
  Future<MimeMessage?> buildMimeMessageWithRecommendedTextEncoding(
      MessageBuilder messageBuilder) async {
    final supports8Bit = await supports8BitEncoding();
    messageBuilder.setRecommendedTextEncoding(supports8Bit);
    return messageBuilder.buildMimeMessage();
  }

  /// Sends the message defined with the specified [messageBuilder] with the recommended text encoding.
  ///
  /// Specify [from] as the originator in case it differs from the `From` header of the message.
  /// Optionally set [appendToSent] to `false` in case the message should NOT be appended to the SENT folder.
  /// By default the message is appended. Note that some mail providers automatically apppend sent messages to
  /// the SENT folder, this is not detected by this API.
  /// Optionally specify the [recipients], in which case the recipients defined in the message are ignored.
  Future<dynamic> sendMessageBuilder(
    MessageBuilder messageBuilder, {
    MailAddress? from,
    bool appendToSent = true,
    List<MailAddress>? recipients,
  }) async {
    final supports8Bit = await supports8BitEncoding();
    final builderEncoding =
        messageBuilder.setRecommendedTextEncoding(supports8Bit);
    final message = messageBuilder.buildMimeMessage();
    final use8Bit = (builderEncoding == TransferEncoding.eightBit);

    final futures = <Future>[];
    futures.add(_sendMessageViaOutgoing(message, from, use8Bit, recipients));
    if (appendToSent && _incomingMailClient.supportsAppendingMessages) {
      futures.add(appendMessageToFlag(message, MailboxFlag.sent,
          flags: [MessageFlags.seen]));
    }
    return Future.wait(futures);
  }

  /// Sends the specified [message].
  ///
  /// Use `MessageBuilder` to create new messages.
  /// Specify [from] as the originator in case it differs from the `From` header of the message.
  /// Optionally set [appendToSent] to `false` in case the message should NOT be appended to the SENT folder.
  /// By default the message is appended. Note that some mail providers automatically apppend sent messages to
  /// the SENT folder, this is not detected by this API.
  /// You can also specify if the message should be sent using 8 bit encoding with [use8BitEncoding], which default to `false`.
  /// Optionally specify the [recipients], in which case the recipients defined in the message are ignored.
  Future<void> sendMessage(
    MimeMessage message, {
    MailAddress? from,
    bool appendToSent = true,
    bool use8BitEncoding = false,
    List<MailAddress>? recipients,
  }) {
    final futures = <Future>[];
    futures.add(
        _sendMessageViaOutgoing(message, from, use8BitEncoding, recipients));
    if (appendToSent && _incomingMailClient.supportsAppendingMessages) {
      futures.add(appendMessageToFlag(message, MailboxFlag.sent,
          flags: [MessageFlags.seen]));
    }
    return Future.wait(futures);
  }

  Future _sendMessageViaOutgoing(MimeMessage message, MailAddress? from,
      bool use8BitEncoding, List<MailAddress>? recipients) async {
    await _outgoingMailClient.sendMessage(message,
        from: from, use8BitEncoding: use8BitEncoding, recipients: recipients);
    await _outgoingMailClient.disconnect();
  }

  /// Appends the [message] to the drafts mailbox with the `\Draft` and `\Seen` message flags.
  Future<UidResponseCode?> saveDraftMessage(MimeMessage message) {
    return appendMessageToFlag(message, MailboxFlag.drafts,
        flags: [MessageFlags.draft, MessageFlags.seen]);
  }

  /// Appends the [message] to the mailbox with the [targetMailboxFlag].
  ///
  /// Optionally specify the message [flags].
  Future<UidResponseCode?> appendMessageToFlag(
      MimeMessage message, MailboxFlag targetMailboxFlag,
      {List<String>? flags}) {
    final mailbox = getMailbox(targetMailboxFlag);
    if (mailbox == null) {
      throw MailException(
          this, 'No mailbox with flag $targetMailboxFlag found in $mailboxes.');
    }
    return appendMessage(message, mailbox, flags: flags);
  }

  /// Appends the [message] to the [targetMailboxF].
  ///
  /// Optionally specify the message [flags].
  Future<UidResponseCode?> appendMessage(
      MimeMessage message, Mailbox targetMailbox,
      {List<String>? flags}) {
    return _incomingMailClient.appendMessage(message, targetMailbox, flags);
  }

  /// Starts listening for new incoming messages.
  ///
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
  ///
  /// Reconnects the mail client in the background, if necessary.
  Future<void> resume() async {
    try {
      if (isPolling()) {
        await stopPolling();
        await startPolling();
      } else {
        await _incomingMailClient.noop();
      }
    } catch (e, s) {
      print('error while resuming: $e $s');
      // the re-connection should be triggered automatically
    }
  }

  /// Determines if message flags such as `\Seen` can be stored.
  ///
  /// POP3 servers do not support message flagging, for example.
  /// Note that even on POP3 servers the \Deleted "flag" can be set. However, messages are really deleted
  /// and cannot be retrieved after marking them as deleted after the current POP3 session is closed.
  bool supportsFlagging() {
    return _incomingMailClient.supportsFlagging();
  }

  /// Convenience method for marking the messages from the specified [sequence] as seen/read.
  ///
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store] method in case you need more control or want to change several flags.
  Future<void> markSeen(MessageSequence sequence,
      {int? unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.seen],
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as unseen/unread.
  ///
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store] method in case you need more control or want to change several flags.
  Future<void> markUnseen(MessageSequence sequence,
      {int? unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.seen],
        action: StoreAction.remove,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as flagged.
  ///
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store] method in case you need more control or want to change several flags.
  Future<void> markFlagged(MessageSequence sequence,
      {int? unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.flagged],
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as unflagged.
  ///
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store] method in case you need more control or want to change several flags.
  Future<void> markUnflagged(MessageSequence sequence,
      {int? unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.flagged],
        action: StoreAction.remove,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as deleted.
  ///
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store] method in case you need more control or want to change several flags.
  Future<void> markDeleted(MessageSequence sequence,
      {int? unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.deleted],
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as not deleted.
  ///
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store] method in case you need more control or want to change several flags.
  Future<void> markUndeleted(MessageSequence sequence,
      {int? unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.deleted],
        action: StoreAction.remove,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as answered.
  ///
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store] method in case you need more control or want to change several flags.
  Future<void> markAnswered(MessageSequence sequence,
      {int? unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.answered],
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as not answered.
  ///
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store] method in case you need more control or want to change several flags.
  Future<void> markUnanswered(MessageSequence sequence,
      {int? unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.answered],
        action: StoreAction.remove,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as forwarded.
  ///
  /// Note this uses the common but not-standarized `$Forwarded` keyword flag.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store] method in case you need more control or want to change several flags.
  Future<void> markForwarded(MessageSequence sequence,
      {bool? silent, int? unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.keywordForwarded],
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Convenience method for marking the messages from the specified [sequence] as not forwarded.
  ///
  /// Note this uses the common but not-standarized `$Forwarded` keyword flag.
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability
  /// Compare the [store] method in case you need more control or want to change several flags.
  Future<void> markUnforwarded(MessageSequence sequence,
      {int? unchangedSinceModSequence}) {
    return store(sequence, [MessageFlags.keywordForwarded],
        action: StoreAction.remove,
        unchangedSinceModSequence: unchangedSinceModSequence);
  }

  /// Flags the [message] with the specified flags.
  ///
  /// Set any bool parameter to either `true` or `false` if you want to change the corresponding flag.
  /// Keep a parameter `null` to not change the corresponding flag.
  /// Compare [store] for gaining more control.
  Future<void> flagMessage(
    MimeMessage message, {
    bool? isSeen,
    bool? isFlagged,
    bool? isAnswered,
    bool? isForwarded,
    bool? isDeleted,
    @Deprecated('use isReadRecieptSent instead') bool? isMdnSent,
    bool? isReadReceiptSent,
  }) {
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
      message.isReadReceiptSent = isMdnSent;
    }
    if (isReadReceiptSent != null) {
      message.isReadReceiptSent = isReadReceiptSent;
    }
    if (message.flags != null) {
      final sequence = MessageSequence.fromMessage(message);
      final flags = [...message.flags!];
      flags.remove(MessageFlags.recent);
      return store(sequence, flags, action: StoreAction.replace);
    } else {
      throw MailException(this, 'No message flags defined');
    }
  }

  /// Stores the specified message [flags] for the given message [sequence].
  ///
  /// By default the flags are added, but you can specify a different store [action].
  /// Specify the [unchangedSinceModSequence] to limit the store action to elements that have not changed since the specified modification sequence. This is only supported when the server supports the CONDSTORE or QRESYNC capability.
  /// Call [supportsFlagging] first to determine if the mail server supports flagging at all.
  Future<void> store(MessageSequence sequence, List<String> flags,
      {StoreAction action = StoreAction.add, int? unchangedSinceModSequence}) {
    return _incomingMailClient.store(
        sequence, flags, action, unchangedSinceModSequence);
  }

  /// Deletes the given [message].
  ///
  /// Depending on the service capabalities either the message is moved to the trash, copied to the trash or just flagged as deleted.
  /// Returns a `DeleteResult` that can be used for an undo operation,
  /// compare [undoDeleteMessages].
  Future<DeleteResult> deleteMessage(MimeMessage message) {
    return deleteMessages(MessageSequence.fromMessage(message));
  }

  /// Deletes the given message [sequence].
  ///
  /// Depending on the service capabalities either the sequence is moved to the trash, copied to the trash or just flagged as deleted.
  /// Optionally set [expunge] to `true` to clear the messages directly from disk on IMAP servers. In that case, the delete operation cannot be undone.
  /// Returns a `DeleteResult` that can be used for an undo operation, compare [undoDeleteMessages].
  Future<DeleteResult> deleteMessages(
    MessageSequence sequence, {
    bool expunge = false,
  }) {
    final trashMailbox = getMailbox(MailboxFlag.trash);
    return _incomingMailClient.deleteMessages(sequence, trashMailbox,
        expunge: expunge);
  }

  /// Reverts the previous [deleteResult], note that is only possible when `deleteResult.isUndoable` is `true`.
  Future<DeleteResult> undoDeleteMessages(DeleteResult deleteResult) {
    return _incomingMailClient.undoDeleteMessages(deleteResult);
  }

  /// Deletes all messages from the specified [mailbox].
  ///
  /// Optionally set [expunge] to `true` to clear the messages directly from disk on IMAP servers. In that case, the delete operation cannot be undone.
  Future<DeleteResult> deleteAllMessages(
    Mailbox mailbox, {
    bool expunge = false,
  }) async {
    final result =
        await _incomingMailClient.deleteAllMessages(mailbox, expunge: expunge);
    mailbox.messagesExists = 0;
    mailbox.messagesRecent = 0;
    mailbox.messagesUnseen = 0;
    return result;
  }

  /// Moves the specified [message] to the junk folder
  Future<MoveResult> junkMessage(MimeMessage message) {
    return moveMessageToFlag(message, MailboxFlag.junk);
  }

  /// Moves the specified message [sequence] to the junk folder
  Future<MoveResult> junkMessages(MessageSequence sequence) {
    return moveMessagesToFlag(sequence, MailboxFlag.junk);
  }

  /// Moves the specified [message] to the inbox folder
  Future<MoveResult> moveMessageToInbox(MimeMessage message) {
    return moveMessageToFlag(message, MailboxFlag.inbox);
  }

  /// Moves the specified message [sequence] to the inbox folder
  Future<MoveResult> moveMessagesToInbox(MessageSequence sequence) {
    return moveMessagesToFlag(sequence, MailboxFlag.inbox);
  }

  /// Moves the specified [message] to the folder flagged with the specified mailbox [flag].
  Future<MoveResult> moveMessageToFlag(MimeMessage message, MailboxFlag flag) {
    return moveMessagesToFlag(MessageSequence.fromMessage(message), flag);
  }

  /// Moves the specified message [sequence] to the folder flagged with the specified mailbox [flag].
  Future<MoveResult> moveMessagesToFlag(
      MessageSequence sequence, MailboxFlag flag) {
    final target = getMailbox(flag);
    if (target == null) {
      throw StateError('Move target mailbox with flag $flag not found');
    }
    return _incomingMailClient.moveMessages(sequence, target);
  }

  /// Moves the specified [message] to the given [target] folder
  Future<MoveResult> moveMessage(MimeMessage message, Mailbox target) {
    return _incomingMailClient.moveMessages(
        MessageSequence.fromMessage(message), target);
  }

  /// Moves the specified message [sequence] to the given [target] folder
  Future<MoveResult> moveMessages(MessageSequence sequence, Mailbox target) {
    return _incomingMailClient.moveMessages(sequence, target);
  }

  /// Reverts the previous move operation, if possible.
  Future<MoveResult> undoMoveMessages(MoveResult moveResult) {
    return _incomingMailClient.undoMove(moveResult);
  }

  /// Searches the messages with the criteria defined in [search].
  ///
  /// Compare [searchMessagesNextPage] for retrieving the next page of search results.
  Future<MailSearchResult> searchMessages(MailSearch search) {
    return _incomingMailClient.searchMessages(search);
  }

  /// Retrieves the next page of messages for the specified [searchResult].
  Future<List<MimeMessage>> searchMessagesNextPage(
      MailSearchResult searchResult) {
    return fetchNextPage(searchResult);
  }

  /// Retrieves the next page of messages for the specified [pagedResult].
  Future<List<MimeMessage>> fetchNextPage(
      PagedMessageResult pagedResult) async {
    final messages = await fetchMessagesNextPage(pagedResult.pagedSequence,
        fetchPreference: pagedResult.fetchPreference);
    pagedResult.insertAll(messages);
    return messages;
  }

  /// Checks if the mail provider supports 8 bit encoded messages for new messages.
  Future<bool> supports8BitEncoding() {
    // if (_incomingMailClient.supportsAppendingMessages &&
    //     !_incomingMailClient.supports8BitEncoding) {
    //   return Future.value(false);
    // }
    return _outgoingMailClient.supports8BitEncoding();
  }

  /// Checks if this mail client supports different mailboxes
  bool get supportsMailboxes => _incomingMailClient.supportsMailboxes;

  /// Creates a new mailbox with the given [mailboxName].
  ///
  /// Specify a [parentMailbox] in case the mailbox should not be created in the root.
  Future<Mailbox> createMailbox(String mailboxName,
      {Mailbox? parentMailbox}) async {
    if (!supportsMailboxes) {
      throw MailException(
          this, 'Mailboxes are not supported, check "supportsMailboxes" first');
    }
    final box = await _incomingMailClient.createMailbox(mailboxName,
        parentMailbox: parentMailbox);
    _mailboxes?.add(box);
    return box;
  }

  Future<void> deleteMailbox(Mailbox mailbox) async {
    if (!supportsMailboxes) {
      throw MailException(
          this, 'Mailboxes are not supported, check "supportsMailboxes" first');
    }
    await _incomingMailClient.deleteMailbox(mailbox);
    _mailboxes?.remove(mailbox);
  }
}

/// Defines the  thread fetching preference
enum ThreadPreference {
  /// All messages of each thread are fetched
  all,

  /// Only the newest message of each thread is fetched
  latest
}

abstract class _IncomingMailClient {
  final MailClient mailClient;
  ClientBase get client;
  ServerType get clientType;
  int? downloadSizeLimit;
  final MailServerConfig _config;
  Mailbox? _selectedMailbox;
  Future<void> Function()? _pollImplementation;
  Duration? _pollDuration;
  Timer? _pollTimer;

  /// Checks if the incoming mail client supports 8 bit encoded messages - is only correct after authorizing
  bool get supports8BitEncoding;

  /// Checks if the incoming mail client supports appending messsages
  bool get supportsAppendingMessages;

  _IncomingMailClient(this.downloadSizeLimit, this._config, this.mailClient);

  bool get supportsThreading;

  bool get supportsMailboxes;

  Id? get serverId => null;

  Future<void> connect();

  Future disconnect();

  Future<List<Mailbox>> listMailboxes();

  Future<Mailbox> selectMailbox(Mailbox mailbox,
      {bool enableCondstore = false, QResyncParameters? qresync});

  Future<List<MimeMessage>> fetchMessages(
      {required Mailbox mailbox,
      int count = 20,
      int page = 1,
      required FetchPreference fetchPreference});

  Future<ThreadResult> fetchThreads(
      Mailbox mailbox,
      DateTime since,
      ThreadPreference threadPreference,
      FetchPreference fetchPreference,
      int pageSize);

  Future<List<MimeMessage>> fetchMessageSequence(MessageSequence sequence,
      {FetchPreference fetchPreference = FetchPreference.fullWhenWithinSize,
      bool markAsSeen = false});

  Future<MimeMessage> fetchMessageContents(MimeMessage message,
      {int? maxSize,
      bool markAsSeen = false,
      List<MediaToptype>? includedInlineTypes});

  Future<MimePart> fetchMessagePart(MimeMessage message, String fetchId);

  Future<List<MimeMessage>> poll();

  bool supportsFlagging();

  Future<void> store(MessageSequence sequence, List<String> flags,
      StoreAction action, int? unchangedSinceModSequence);

  Future<DeleteResult> deleteMessages(
      MessageSequence sequence, Mailbox? trashMailbox,
      {bool expunge = false});

  Future<DeleteResult> undoDeleteMessages(DeleteResult deleteResult);

  Future<DeleteResult> deleteAllMessages(Mailbox mailbox,
      {bool expunge = false});

  Future<void> startPolling(Duration duration,
      {Future Function()? pollImplementation}) {
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
    await _pollImplementation!();
  }

  Future<MoveResult> moveMessages(MessageSequence sequence, Mailbox target);

  Future<MoveResult> undoMove(MoveResult moveResult);

  Future<MailSearchResult> searchMessages(MailSearch search);

  Future<UidResponseCode?> appendMessage(
      MimeMessage message, Mailbox targetMailbox, List<String>? flags);

  Future noop();

  Future<ThreadDataResult> fetchThreadData(
      Mailbox mailbox, DateTime since, bool setThreadSequences);

  Future<Mailbox> createMailbox(String mailboxName, {Mailbox? parentMailbox});

  Future<void> deleteMailbox(Mailbox mailbox);
}

class _IncomingImapClient extends _IncomingMailClient {
  @override
  ClientBase get client => _imapClient;
  @override
  ServerType get clientType => ServerType.imap;
  final ImapClient _imapClient;
  bool _isQResyncEnabled = false;
  bool _supportsIdle = false;
  bool _isInIdleMode = false;
  final List<MimeMessage> _fetchMessages = <MimeMessage>[];
  bool _isReconnecting = false;
  final List<ImapEvent> _imapEventsDuringReconnecting = <ImapEvent>[];
  int _reconnectCounter = 0;
  bool _isIdlePaused = false;
  ThreadDataResult? _threadData;
  @override
  bool get supportsMailboxes => true;
  Id? _serverId;
  @override
  Id? get serverId => _serverId;

  _IncomingImapClient(
    int? downloadSizeLimit,
    EventBus eventBus,
    bool isLogEnabled,
    String? logName,
    MailServerConfig config,
    MailClient mailClient, {
    bool Function(X509Certificate)? onBadCertificate,
  })  : _imapClient = ImapClient(
          bus: eventBus,
          isLogEnabled: isLogEnabled,
          logName: logName,
          onBadCertificate: onBadCertificate,
        ),
        super(downloadSizeLimit, config, mailClient) {
    eventBus.on<ImapEvent>().listen(_onImapEvent);
  }

  void _onImapEvent(ImapEvent event) async {
    if (event.imapClient != _imapClient) {
      return; // ignore events from other imap clients and in disconnected state
    }
    // print(
    //     'imap event: ${event.eventType} - is currently currently reconnecting: $_isReconnecting');
    if (_isReconnecting) {
      if (event.eventType != ImapEventType.connectionLost) {
        _imapEventsDuringReconnecting.add(event);
      }
      return;
    }
    switch (event.eventType) {
      case ImapEventType.fetch:
        final message = (event as ImapFetchEvent).message;
        if (message.flags != null) {
          mailClient._fireEvent(MailUpdateEvent(message, mailClient));
        }
        break;
      case ImapEventType.exists:
        final evt = event as ImapMessagesExistEvent;
        //print(
        //    'exists event: new=${evt.newMessagesExists}, old=${evt.oldMessagesExists}, selected=${_selectedMailbox.messagesExists}');
        if (evt.newMessagesExists <= evt.oldMessagesExists) {
          // this is just an update eg after an EXPUNGE event
          // ignore:
          break;
        }
        final sequence = MessageSequence();
        if (evt.newMessagesExists - evt.oldMessagesExists > 1) {
          sequence.addRange(evt.oldMessagesExists, evt.newMessagesExists);
        } else {
          sequence.add(evt.newMessagesExists);
        }
        final messages = await fetchMessageSequence(sequence,
            fetchPreference: FetchPreference.envelope);
        for (final message in messages) {
          mailClient._fireEvent(MailLoadEvent(message, mailClient));
          _fetchMessages.add(message);
        }
        if (messages.isNotEmpty) {
          final lastUid = messages.last.uid;
          if (lastUid != null) {
            _selectedMailbox!.uidNext = lastUid + 1;
          }
        }
        break;
      case ImapEventType.vanished:
        final evt = event as ImapVanishedEvent;
        mailClient._fireEvent(
            MailVanishedEvent(evt.vanishedMessages, evt.isEarlier, mailClient));
        break;
      case ImapEventType.expunge:
        final evt = event as ImapExpungeEvent;
        mailClient._fireEvent(MailVanishedEvent(
            MessageSequence.fromId(evt.messageSequenceId!), false, mailClient));
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
    _imapClient.log('reconnecting....', initial: ClientBase.initialApp);
    try {
      mailClient._fireEvent(MailConnectionLostEvent(mailClient));
    } catch (e, s) {
      print('ERROR: handler crashed at MailConnectionLostEvent: $e $s');
    }
    final restartPolling = (_pollTimer != null);
    if (restartPolling) {
      // turn off idle mode as this is an error case in which the client cannot send 'DONE' to the server anyhow.
      _isInIdleMode = false;
      await stopPolling();
    }
    _reconnectCounter++;
    final counter = _reconnectCounter;
    final box = _selectedMailbox;
    final uidNext = box?.uidNext;
    _imapClient.stashQueuedTasks();
    while (counter == _reconnectCounter) {
      try {
        _imapClient.log('trying to connect...', initial: ClientBase.initialApp);
        // refresh token if required:
        await mailClient._prepareConnect();
        await connect();
        _imapClient.log('connected.');
        _isInIdleMode = false;
        //TODO check with previous modification sequence and download new messages
        _imapClient.log(
            're-select mailbox "${box != null ? box.path : "inbox"}".',
            initial: ClientBase.initialApp);
        if (box != null) {
          _selectedMailbox = await _imapClient.selectMailbox(box);
        } else {
          _selectedMailbox = await _imapClient.selectInbox();
        }
        _imapClient.log('reselected mailbox.', initial: ClientBase.initialApp);
        await _imapClient.applyStashedTasks();
        _imapClient.log('applied queued commands, if any.',
            initial: ClientBase.initialApp);
        if (restartPolling) {
          _imapClient.log('restart polling...', initial: ClientBase.initialApp);
          await startPolling(_pollDuration,
              pollImplementation: _pollImplementation);
        }
        _imapClient.log('done reconnecting.', initial: ClientBase.initialApp);
        final events = _imapEventsDuringReconnecting.toList();
        _imapEventsDuringReconnecting.clear();
        _isReconnecting = false;
        try {
          mailClient._fireEvent(MailConnectionReEstablishedEvent(mailClient));
        } catch (e, s) {
          print(
              'Error: receiver could not handle MailConnectionReEstablishedEvent: $e $s');
        }
        if (events.isNotEmpty) {
          for (final event in events) {
            _onImapEvent(event);
          }
        }
        if (uidNext != null &&
            _selectedMailbox?.uidNext != null &&
            _selectedMailbox!.uidNext! > uidNext) {
          // there are new message in the meantime, download them:
          final sequence = MessageSequence.fromRange(
              uidNext, _selectedMailbox!.uidNext!,
              isUidSequence: true);
          final messages = await fetchMessageSequence(sequence,
              fetchPreference: FetchPreference.envelope);
          try {
            for (final message in messages) {
              mailClient._fireEvent(MailLoadEvent(message, mailClient));
            }
          } catch (e, s) {
            print(
                'Error: receiver could not handle MailLoadEvent after re-establishing connection: $e $s');
          }
        }
        return;
      } catch (e, s) {
        _imapClient.log('Unable to reconnect: $e $s',
            initial: ClientBase.initialApp);
        await Future.delayed(Duration(seconds: 60));
      }
    }
  }

  @override
  Future<void> connect() async {
    final serverConfig = _config.serverConfig!;
    final isSecure = (serverConfig.socketType == SocketType.ssl);
    await _imapClient.connectToServer(
        serverConfig.hostname!, serverConfig.port!,
        isSecure: isSecure);
    if (!isSecure) {
      //TODO check if server supports STARTTLS at all
      await _imapClient.startTls();
    }
    try {
      await _config.authentication!
          .authenticate(serverConfig, imap: _imapClient);
    } on ImapException catch (e, s) {
      throw MailException.fromImap(mailClient, e, s);
    } catch (e, s) {
      throw MailException(mailClient, e.toString(), stackTrace: s, details: e);
    }
    //TODO compare with previous capabilities and possibly fire events for new or removed server capabilities
    if (_imapClient.serverInfo.capabilities?.isEmpty ?? true) {
      await _imapClient.capability();
    }
    if (_imapClient.serverInfo.supportsId) {
      _serverId = await _imapClient.id(clientId: mailClient.clientId);
    }
    _config.serverCapabilities = _imapClient.serverInfo.capabilities;
    final serverInfo = _imapClient.serverInfo;
    final enableCaps = <String>[];
    if (serverInfo.supportsQresync) {
      enableCaps.add(ImapServerInfo.capabilityQresync);
    }
    if (serverInfo.supportsUtf8) {
      enableCaps.add(ImapServerInfo.capabilityUtf8Accept);
    }
    if (enableCaps.isNotEmpty) {
      await _imapClient.enable(enableCaps);
      _isQResyncEnabled =
          _imapClient.serverInfo.isEnabled(ImapServerInfo.capabilityQresync);
    }

    _supportsIdle = serverInfo.supportsIdle;
  }

  @override
  Future disconnect() {
    return _imapClient.disconnect();
  }

  @override
  Future<List<Mailbox>> listMailboxes() async {
    await _pauseIdle();
    try {
      final mailboxes = await _imapClient.listMailboxes(recursive: true);
      final separator = _imapClient.serverInfo.pathSeparator;
      _config.pathSeparator = separator;
      return mailboxes;
    } on ImapException catch (e) {
      throw MailException.fromImap(mailClient, e);
    } finally {
      await _resumeIdle();
    }
  }

  @override
  Future<Mailbox> selectMailbox(Mailbox mailbox,
      {bool enableCondstore = false, QResyncParameters? qresync}) async {
    await _pauseIdle();
    try {
      if (_selectedMailbox != null) {
        await _imapClient.closeMailbox();
      }
      if (qresync == null &&
          _isQResyncEnabled &&
          mailbox.highestModSequence != null) {
        qresync =
            QResyncParameters(mailbox.uidValidity, mailbox.highestModSequence);
      }
      final selectedMailbox = await _imapClient.selectMailbox(mailbox,
          enableCondStore: enableCondstore, qresync: qresync);
      _selectedMailbox = selectedMailbox;
      _threadData = null;
      return selectedMailbox;
    } on ImapException catch (e) {
      throw MailException.fromImap(mailClient, e);
    } finally {
      await _resumeIdle();
    }
  }

  @override
  Future<List<MimeMessage>> fetchMessages(
      {required Mailbox mailbox,
      int count = 20,
      int page = 1,
      required FetchPreference fetchPreference}) {
    if (mailbox.messagesExists == 0) {
      // should the mailbox status be updated first?
      return Future.value(<MimeMessage>[]);
    }
    var end = mailbox.messagesExists;
    end -= (page - 1) * count;
    if (end < 1) {
      end = 1;
    }
    var start = end - count;
    if (start < 1) {
      start = 1;
    }
    final sequence = MessageSequence.fromRange(start, end);
    return fetchMessageSequence(sequence, fetchPreference: fetchPreference);
  }

  @override
  Future<List<MimeMessage>> fetchMessageSequence(MessageSequence sequence,
      {FetchPreference fetchPreference = FetchPreference.fullWhenWithinSize,
      bool markAsSeen = false}) async {
    try {
      await _pauseIdle();

      return await _fetchMessageSequence(sequence,
          fetchPreference: fetchPreference, markAsSeen: markAsSeen);
    } on ImapException catch (e, s) {
      throw MailException.fromImap(mailClient, e, s);
    } catch (e, s) {
      throw MailException(mailClient, 'Error while fetching: $e',
          details: e, stackTrace: s);
    } finally {
      await _resumeIdle();
    }
  }

  /// fetches messages without pause or exception handling
  Future<List<MimeMessage>> _fetchMessageSequence(MessageSequence sequence,
      {FetchPreference fetchPreference = FetchPreference.fullWhenWithinSize,
      bool markAsSeen = false}) async {
    String criteria;
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
      case FetchPreference.fullWhenWithinSize:
        if (downloadSizeLimit == null) {
          if (markAsSeen == true) {
            criteria = '(UID FLAGS RFC822.SIZE BODY[])';
          } else {
            criteria = '(UID FLAGS RFC822.SIZE BODY.PEEK[])';
          }
        } else {
          criteria = '(UID FLAGS RFC822.SIZE ENVELOPE)';
        }
        break;
    }

    var fetchImapResult = sequence.isUidSequence
        ? await _imapClient.uidFetchMessages(sequence, criteria)
        : await _imapClient.fetchMessages(sequence, criteria);
    if (fetchImapResult.vanishedMessagesUidSequence?.isNotEmpty ?? false) {
      mailClient._fireEvent(MailVanishedEvent(
          fetchImapResult.vanishedMessagesUidSequence, false, mailClient));
    }
    if (fetchPreference == FetchPreference.full && downloadSizeLimit != null) {
      final smallEnoughMessages = fetchImapResult.messages
          .where((msg) => msg.size! < downloadSizeLimit!);
      sequence = MessageSequence();
      for (final msg in smallEnoughMessages) {
        sequence.add(msg.uid!);
      }
      fetchImapResult =
          await _imapClient.fetchMessages(sequence, '(UID FLAGS BODY.PEEK[])');
    }
    final threadData = _threadData;
    if (threadData != null) {
      for (final message in fetchImapResult.messages) {
        threadData.setThreadSequence(message);
      }
    }
    fetchImapResult.messages
        .sort((msg1, msg2) => msg1.sequenceId!.compareTo(msg2.sequenceId!));
    return fetchImapResult.messages;
  }

  @override
  Future<List<MimeMessage>> poll() async {
    _fetchMessages.clear();
    try {
      await _imapClient.noop();
      if (_fetchMessages.isEmpty) {
        return [];
      }
      return _fetchMessages.toList();
    } on ImapException catch (e) {
      throw MailException.fromImap(mailClient, e);
    }
  }

  @override
  Future<MimePart> fetchMessagePart(MimeMessage message, String fetchId) async {
    FetchImapResult fetchImapResult;
    await _pauseIdle();
    try {
      if (message.uid != null) {
        fetchImapResult =
            await _imapClient.uidFetchMessage(message.uid!, '(BODY[$fetchId])');
      } else {
        fetchImapResult = await _imapClient.fetchMessage(
            message.sequenceId!, '(BODY[$fetchId])');
      }
      if (fetchImapResult.messages.length == 1) {
        final part = fetchImapResult.messages.first.getPart(fetchId);
        if (part == null) {
          throw MailException(
              mailClient, 'Unable to fetch message part <$fetchId>');
        }
        message.setPart(fetchId, part);
        return part;
      } else {
        throw MailException(
            mailClient, 'Unable to fetch message part <$fetchId>');
      }
    } on ImapException catch (e) {
      throw MailException.fromImap(mailClient, e);
    } finally {
      await _resumeIdle();
    }
  }

  @override
  Future<void> startPolling(Duration? duration,
      {Future Function()? pollImplementation}) async {
    if (_supportsIdle) {
      // IMAP Idle timeout is 30 minutes, so official recommendation is to restart IDLE every 29 minutes.
      // Here is a shorter duration chosen, so that connection problems are detected earlier.
      if (duration == null || duration == MailClient.defaultPollingDuration) {
        duration = const Duration(minutes: 5);
      }
      pollImplementation ??= _restartIdlePolling;
      _isInIdleMode = true;
      try {
        await _imapClient.idleStart();
      } on ImapException catch (e) {
        throw MailException.fromImap(mailClient, e);
      }
    }
    return super
        .startPolling(duration!, pollImplementation: pollImplementation);
  }

  @override
  Future<void> stopPolling() async {
    if (_isInIdleMode) {
      _isInIdleMode = false;
      try {
        await _imapClient.idleDone();
      } on ImapException catch (e) {
        throw MailException.fromImap(mailClient, e);
      } catch (e, s) {
        throw MailException(mailClient, 'idleDone() call failed',
            details: e, stackTrace: s);
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
      _imapClient.log('Unable to restart IDLE: $e',
          initial: ClientBase.initialApp);
      print(s);
    }
    return Future.value();
  }

  @override
  Future<void> store(MessageSequence sequence, List<String> flags,
      StoreAction action, int? unchangedSinceModSequence) async {
    await _pauseIdle();
    try {
      if (sequence.isUidSequence == true) {
        await _imapClient.uidStore(sequence, flags,
            action: action,
            silent: true,
            unchangedSinceModSequence: unchangedSinceModSequence);
      } else {
        await _imapClient.store(sequence, flags,
            action: action,
            silent: true,
            unchangedSinceModSequence: unchangedSinceModSequence);
      }
    } on ImapException catch (e) {
      throw MailException.fromImap(mailClient, e);
    } finally {
      await _resumeIdle();
    }
  }

  @override
  bool supportsFlagging() {
    return true;
  }

  @override
  Future<MimeMessage> fetchMessageContents(final MimeMessage message,
      {int? maxSize,
      bool markAsSeen = false,
      List<MediaToptype>? includedInlineTypes}) async {
    BodyPart? body;
    final sequence = MessageSequence.fromMessage(message);
    if (maxSize != null && message.size! > maxSize) {
      // download body structure first, so the media type becomes known:
      try {
        await _pauseIdle();
        final fetchResult = sequence.isUidSequence
            ? await _imapClient.uidFetchMessages(sequence, '(BODYSTRUCTURE)')
            : await _imapClient.fetchMessages(sequence, '(BODYSTRUCTURE)');
        if (fetchResult.messages.isNotEmpty) {
          final lastMessage = fetchResult.messages.last;
          if (lastMessage.mediaType.top == MediaToptype.multipart) {
            // only for multipart messages it makes sense to download the inline parts:
            body = lastMessage.body;
          }
        }
      } on ImapException catch (e, s) {
        throw MailException.fromImap(mailClient, e, s);
      }
    }
    if (body == null) {
      final messages = await fetchMessageSequence(sequence,
          fetchPreference: FetchPreference.fullWhenWithinSize,
          markAsSeen: markAsSeen);
      if (messages.isNotEmpty) {
        return messages.last;
      }
    } else {
      try {
        // download all non-attachment parts:
        final matchingContents = <ContentInfo>[];
        body.collectContentInfo(ContentDisposition.attachment, matchingContents,
            reverse: true);
        if (includedInlineTypes != null && includedInlineTypes.isNotEmpty) {
          if (!includedInlineTypes.contains(MediaToptype.text)) {
            // some messages set the inline disposition-header also for the message text parts
            includedInlineTypes.add(MediaToptype.text);
          }
          matchingContents.removeWhere((info) =>
              (info.contentDisposition?.disposition ==
                  ContentDisposition.inline) &&
              !(includedInlineTypes.contains(info.mediaType?.top)));
        }
        final buffer = StringBuffer();
        buffer.write('(FLAGS BODY[HEADER] ');
        if (message.envelope == null) {
          buffer.write('ENVELOPE ');
        }
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
        final fetchResult = sequence.isUidSequence
            ? await _imapClient.uidFetchMessages(sequence, criteria)
            : await _imapClient.fetchMessages(sequence, criteria);
        if (fetchResult.messages.isNotEmpty) {
          final result = fetchResult.messages.first;
          // copy all data into original message, so that envelope and flags information etc is being kept:
          message.body = body;
          message.envelope ??= result.envelope!;
          message.headers = result.headers;
          message.copyIndividualParts(result);
          message.flags = result.flags;
          final threadData = _threadData;
          if (threadData != null) {
            threadData.setThreadSequence(message);
          }
          return message;
        }
      } on ImapException catch (e, s) {
        throw MailException.fromImap(mailClient, e, s);
      } finally {
        await _resumeIdle();
      }
    }
    throw MailException(mailClient,
        'Unable to download message with UID ${message.uid} / sequence ID ${message.sequenceId}');
  }

  @override
  Future<DeleteResult> deleteMessages(
      MessageSequence sequence, Mailbox? trashMailbox,
      {bool expunge = false}) async {
    if (trashMailbox == null || trashMailbox == _selectedMailbox || expunge) {
      try {
        await _pauseIdle();
        await _imapClient.store(sequence, [MessageFlags.deleted],
            action: StoreAction.add, silent: true);
        if (expunge) {
          await _imapClient.expunge();
        }
        final isUndoable = !expunge;
        return DeleteResult(isUndoable, DeleteAction.flag, sequence,
            _selectedMailbox, sequence, _selectedMailbox, mailClient);
      } on ImapException catch (e) {
        throw MailException.fromImap(mailClient, e);
      } finally {
        await _resumeIdle();
      }
    } else {
      try {
        await _pauseIdle();
        DeleteAction deleteAction;
        GenericImapResult imapResult;
        if (_imapClient.serverInfo.supportsMove) {
          deleteAction = DeleteAction.move;
          if (sequence.isUidSequence) {
            imapResult = await _imapClient.uidMove(sequence,
                targetMailbox: trashMailbox);
          } else {
            imapResult =
                await _imapClient.move(sequence, targetMailbox: trashMailbox);
          }
        } else {
          deleteAction = DeleteAction.copy;

          if (sequence.isUidSequence) {
            imapResult = await _imapClient.uidCopy(sequence,
                targetMailbox: trashMailbox);
          } else {
            imapResult =
                await _imapClient.copy(sequence, targetMailbox: trashMailbox);
          }
          await _imapClient.store(sequence, [MessageFlags.deleted],
              action: StoreAction.add, silent: true);
        }
        // note: explicitely do not EXPUNGE after delete, so that undo becomes easier

        final targetSequence = imapResult.responseCodeCopyUid?.targetSequence;
        // copy and move commands result in a mapping sequence which is relevant for undo operations:
        return DeleteResult(targetSequence != null, deleteAction, sequence,
            _selectedMailbox, targetSequence, trashMailbox, mailClient);
      } on ImapException catch (e) {
        throw MailException.fromImap(mailClient, e);
      } finally {
        await _resumeIdle();
      }
    }
  }

  @override
  Future<DeleteResult> undoDeleteMessages(DeleteResult deleteResult) async {
    switch (deleteResult.action) {
      case DeleteAction.flag:
        await store(deleteResult.originalSequence!, [MessageFlags.deleted],
            StoreAction.remove, null);
        break;
      case DeleteAction.move:
        try {
          await _pauseIdle();
          await _imapClient.closeMailbox();
          await _imapClient.selectMailbox(deleteResult.targetMailbox!);

          GenericImapResult result;
          if (deleteResult.targetSequence!.isUidSequence) {
            result = await _imapClient.uidMove(deleteResult.targetSequence!,
                targetMailbox: deleteResult.originalMailbox);
          } else {
            result = await _imapClient.move(deleteResult.targetSequence!,
                targetMailbox: deleteResult.originalMailbox);
          }
          await _imapClient.closeMailbox();
          await _imapClient.selectMailbox(deleteResult.originalMailbox!);

          final undoResult =
              deleteResult.reverseWith(result.responseCodeCopyUid);
          return undoResult;
        } on ImapException catch (e) {
          throw MailException.fromImap(mailClient, e);
        } finally {
          await _resumeIdle();
        }
      case DeleteAction.copy:
        try {
          await _pauseIdle();
          if (deleteResult.originalSequence!.isUidSequence) {
            await _imapClient.uidStore(
                deleteResult.originalSequence!, [MessageFlags.deleted],
                action: StoreAction.remove);
          } else {
            await _imapClient.store(
                deleteResult.originalSequence!, [MessageFlags.deleted],
                action: StoreAction.remove);
          }
          await _imapClient.closeMailbox();
          await _imapClient.selectMailbox(deleteResult.targetMailbox!);
          if (deleteResult.targetSequence!.isUidSequence) {
            await _imapClient.uidStore(
                deleteResult.targetSequence!, [MessageFlags.deleted],
                action: StoreAction.add);
          } else {
            await _imapClient.store(
                deleteResult.targetSequence!, [MessageFlags.deleted],
                action: StoreAction.add);
          }

          await _imapClient.closeMailbox();
          await _imapClient.selectMailbox(deleteResult.originalMailbox!);
        } on ImapException catch (e) {
          throw MailException.fromImap(mailClient, e);
        } finally {
          await _resumeIdle();
        }
        break;
      case DeleteAction.pop:
        throw StateError('POP delete action not expected for IMAP connection.');
    }
    return deleteResult.reverse();
  }

  @override
  Future<DeleteResult> deleteAllMessages(Mailbox mailbox,
      {bool expunge = false}) async {
    var undoable = true;
    final sequence = MessageSequence.fromAll();
    final selectedMailbox = _selectedMailbox;
    try {
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
        await _imapClient.selectMailbox(selectedMailbox!);
      }
    } on ImapException catch (e) {
      throw MailException.fromImap(mailClient, e);
    } finally {
      await _resumeIdle();
    }
    return DeleteResult(
        undoable, DeleteAction.flag, sequence, mailbox, null, null, mailClient);
  }

  Future<MoveResult> _moveMessages(
      MessageSequence? sequence, Mailbox? target) async {
    MoveAction moveAction;
    GenericImapResult imapResult;
    if (_imapClient.serverInfo.supports('MOVE')) {
      moveAction = MoveAction.move;
      if (sequence!.isUidSequence) {
        imapResult = await _imapClient.uidMove(sequence, targetMailbox: target);
      } else {
        imapResult = await _imapClient.move(sequence, targetMailbox: target);
      }
    } else {
      moveAction = MoveAction.copy;

      if (sequence!.isUidSequence) {
        imapResult = await _imapClient.uidCopy(sequence, targetMailbox: target);
      } else {
        imapResult = await _imapClient.copy(sequence, targetMailbox: target);
      }
      await _imapClient.store(sequence, [MessageFlags.deleted],
          action: StoreAction.add);
    }
    final targetSequence = imapResult.responseCodeCopyUid?.targetSequence;
    // copy and move commands result in a mapping sequence which is relevant for undo operations:
    return MoveResult(targetSequence != null, moveAction, sequence,
        _selectedMailbox, targetSequence, target, mailClient);
  }

  @override
  Future<MoveResult> moveMessages(
      MessageSequence sequence, Mailbox target) async {
    try {
      await _pauseIdle();
      final response = await _moveMessages(sequence, target);
      return response;
    } on ImapException catch (e) {
      throw MailException.fromImap(mailClient, e);
    } finally {
      await _resumeIdle();
    }
  }

  @override
  Future<MoveResult> undoMove(MoveResult moveResult) async {
    try {
      await _pauseIdle();
      await _imapClient.selectMailbox(moveResult.targetMailbox!);
      final response = await _moveMessages(
          moveResult.targetSequence, moveResult.originalMailbox);
      await _imapClient.selectMailbox(moveResult.originalMailbox!);
      return response;
    } on ImapException catch (e) {
      throw MailException.fromImap(mailClient, e);
    } finally {
      await _resumeIdle();
    }
  }

  @override
  Future<MailSearchResult> searchMessages(MailSearch search) async {
    final queryBuilder = SearchQueryBuilder.from(search.query, search.queryType,
        messageType: search.messageType,
        since: search.since,
        before: search.before,
        sentSince: search.sentSince,
        sentBefore: search.sentBefore);
    var resumeIdleInFinally = true;
    try {
      await _pauseIdle();
      SearchImapResult result;
      if (_imapClient.serverInfo.supportsUidPlus) {
        result = await _imapClient.uidSearchMessagesWithQuery(queryBuilder);
      } else {
        result = await _imapClient.searchMessagesWithQuery(queryBuilder);
      }

      // TODO consider supported ESEARCH / IMAP Extension for Referencing the Last SEARCH Result / https://tools.ietf.org/html/rfc5182
      final sequence = result.matchingSequence;
      if (sequence == null || sequence.isEmpty) {
        return MailSearchResult.empty(search);
      }

      final requestSequence = sequence.subsequenceFromPage(1, search.pageSize);
      final messages = await _fetchMessageSequence(requestSequence,
          fetchPreference: search.fetchPreference, markAsSeen: false);
      return MailSearchResult(
        search,
        PagedMessageSequence(sequence, pageSize: search.pageSize),
        messages,
        search.fetchPreference,
      );
    } on ImapException catch (e, s) {
      if (search.queryType == SearchQueryType.allTextHeaders) {
        resumeIdleInFinally = false;
        final orSearch = _selectedMailbox!.isSent
            ? SearchQueryType.toOrSubject
            : SearchQueryType.fromOrSubject;
        return searchMessages(search.copyWith(queryType: orSearch));
      }
      throw MailException.fromImap(mailClient, e, s);
    } finally {
      if (resumeIdleInFinally) {
        await _resumeIdle();
      }
    }
  }

  @override
  Future<UidResponseCode?> appendMessage(
      MimeMessage message, Mailbox targetMailbox, List<String>? flags) async {
    try {
      await _pauseIdle();
      final result = await _imapClient.appendMessage(message,
          targetMailbox: targetMailbox, flags: flags);
      return result.responseCodeAppendUid;
    } on ImapException catch (e, s) {
      throw MailException.fromImap(mailClient, e, s);
    } finally {
      await _resumeIdle();
    }
  }

  @override
  bool get supports8BitEncoding => _imapClient.serverInfo.supportsUtf8;

  @override
  bool get supportsAppendingMessages => true;

  @override
  Future noop() async {
    try {
      await _pauseIdle();
      await _imapClient.noop();
    } on ImapException catch (e, s) {
      throw MailException.fromImap(mailClient, e, s);
    } finally {
      await _resumeIdle();
    }
  }

  @override
  Future<ThreadResult> fetchThreads(
      Mailbox mailbox,
      DateTime since,
      ThreadPreference threadPreference,
      FetchPreference fetchPreference,
      int pageSize) async {
    try {
      await _pauseIdle();
      if (mailbox != _selectedMailbox) {
        await selectMailbox(mailbox);
      }
      if (_imapClient.serverInfo.supportedThreadingMethods.isEmpty) {
        throw MailException(mailClient, 'Threading not supported by server');
      }
      final method = _imapClient.serverInfo.supportedThreadingMethods.first;
      final threadNodes =
          await _imapClient.uidThreadMessages(method: method, since: since);
      final threadSequence = threadNodes.toMessageSequence(
          mode: threadPreference == ThreadPreference.latest
              ? SequenceNodeSelectionMode.lastLeaf
              : SequenceNodeSelectionMode.all);
      final pagedThreadSequence =
          PagedMessageSequence(threadSequence, pageSize: pageSize);
      final result = ThreadResult(threadNodes, pagedThreadSequence,
          threadPreference, fetchPreference, since, []);
      if (pagedThreadSequence.hasNext) {
        final sequence = pagedThreadSequence.next();
        final unthreadedMessages = await _fetchMessageSequence(sequence,
            fetchPreference: fetchPreference);
        result.addAll(unthreadedMessages);
      }
      return result;
    } on ImapException catch (e, s) {
      throw MailException.fromImap(mailClient, e, s);
    } finally {
      await _resumeIdle();
    }
  }

  @override
  bool get supportsThreading => _imapClient.serverInfo.supportsThreading;

  @override
  Future<ThreadDataResult> fetchThreadData(
      Mailbox mailbox, DateTime since, bool setThreadSequences) async {
    try {
      await _pauseIdle();
      if (mailbox != _selectedMailbox) {
        await selectMailbox(mailbox);
      }
      if (_imapClient.serverInfo.supportedThreadingMethods.isEmpty) {
        throw MailException(mailClient, 'Threading not supported by server');
      }
      final method = _imapClient.serverInfo.supportedThreadingMethods.first;
      final threadNodes =
          await _imapClient.uidThreadMessages(method: method, since: since);
      final result = ThreadDataResult(threadNodes, since);
      _threadData = setThreadSequences ? result : null;
      return result;
    } on ImapException catch (e, s) {
      throw MailException.fromImap(mailClient, e, s);
    } finally {
      await _resumeIdle();
    }
  }

  @override
  Future<Mailbox> createMailbox(String mailboxName,
      {Mailbox? parentMailbox}) async {
    final path = (parentMailbox != null)
        ? parentMailbox.encodedPath + parentMailbox.pathSeparator + mailboxName
        : mailboxName;
    try {
      await _pauseIdle();
      return await _imapClient.createMailbox(path);
    } on ImapException catch (e, s) {
      throw MailException.fromImap(mailClient, e, s);
    } finally {
      await _resumeIdle();
    }
  }

  @override
  Future<void> deleteMailbox(Mailbox mailbox) async {
    try {
      await _pauseIdle();
      await _imapClient.deleteMailbox(mailbox);
    } on ImapException catch (e, s) {
      throw MailException.fromImap(mailClient, e, s);
    } finally {
      await _resumeIdle();
    }
  }
}

class _IncomingPopClient extends _IncomingMailClient {
  @override
  ClientBase get client => _popClient;
  @override
  ServerType get clientType => ServerType.pop;

  List<MessageListing>? _popMessageListing;
  final Mailbox _popInbox =
      Mailbox.setup('Inbox', 'Inbox', [MailboxFlag.inbox]);

  final PopClient _popClient;
  _IncomingPopClient(
      int? downloadSizeLimit,
      EventBus eventBus,
      bool isLogEnabled,
      String? logName,
      MailServerConfig config,
      MailClient mailClient,
      {bool Function(X509Certificate)? onBadCertificate})
      : _popClient = PopClient(
            bus: eventBus,
            isLogEnabled: isLogEnabled,
            logName: logName,
            onBadCertificate: onBadCertificate),
        super(downloadSizeLimit, config, mailClient);

  @override
  Future<void> connect() async {
    final serverConfig = _config.serverConfig!;
    final isSecure = (serverConfig.socketType == SocketType.ssl);
    await _popClient.connectToServer(serverConfig.hostname!, serverConfig.port!,
        isSecure: isSecure);
    if (!isSecure) {
      //TODO check POP3 server capabilities first
      await _popClient.startTls();
    }
    try {
      final authResponse = await _config.authentication!
          .authenticate(serverConfig, pop: _popClient);

      return authResponse;
    } on PopException catch (e, s) {
      throw MailException.fromPop(mailClient, e, s);
    } catch (e, s) {
      throw MailException(mailClient, e.toString(), stackTrace: s, details: e);
    }
  }

  @override
  Future disconnect() {
    return _popClient.disconnect();
  }

  @override
  Future<List<Mailbox>> listMailboxes() {
    _config.pathSeparator = '/';
    return Future.value([_popInbox]);
  }

  @override
  Future<Mailbox> selectMailbox(Mailbox mailbox,
      {bool enableCondstore = false, QResyncParameters? qresync}) async {
    if (mailbox != _popInbox) {
      throw MailException(mailClient, 'Unknown mailbox $mailbox');
    }
    final status = await _popClient.status();
    mailbox.messagesExists = status.numberOfMessages;
    _selectedMailbox = mailbox;
    return mailbox;
  }

  @override
  Future<List<MimeMessage>> fetchMessages(
      {required Mailbox mailbox,
      int count = 20,
      int page = 1,
      required FetchPreference fetchPreference}) async {
    _popMessageListing ??= await _popClient.list();
    var listings = _popMessageListing;
    var startIndex = listings!.length - count;
    startIndex -= page * count;
    if (startIndex < 0) {
      count += startIndex;
      startIndex = 0;
    }
    listings = listings.sublist(startIndex, startIndex + count);
    final messages = <MimeMessage>[];
    for (final listing in listings) {
      //TODO check listing.sizeInBytes
      final message = await _popClient.retrieve(listing.id);
      messages.add(message);
    }
    return messages;
  }

  @override
  Future<List<MimeMessage>> poll() async {
    final numberOfKNownMessages = _selectedMailbox!.messagesExists;
    // in POP3 a new session is required to get a new status
    await connect();
    final status = await _popClient.status();
    final messages = <MimeMessage>[];
    final numberOfMessages = status.numberOfMessages;
    if (numberOfMessages < numberOfKNownMessages) {
      //TODO compare list UIDs with nown message UIDs instead of just checking the number of messages
      final diff = numberOfMessages - numberOfKNownMessages;
      for (var id = numberOfMessages; id > numberOfMessages - diff; id--) {
        final message = await _popClient.retrieve(id);
        messages.add(message);
        mailClient._fireEvent(MailLoadEvent(message, mailClient));
      }
    }
    return messages;
  }

  @override
  Future<List<MimeMessage>> fetchMessageSequence(MessageSequence sequence,
      {FetchPreference? fetchPreference, bool? markAsSeen}) async {
    final ids = sequence.toList(_selectedMailbox?.messagesExists);
    final messages = <MimeMessage>[];
    for (final id in ids) {
      final message = await _popClient.retrieve(id);
      messages.add(message);
    }
    return messages;
  }

  @override
  Future<void> store(MessageSequence sequence, List<String> flags,
      StoreAction action, int? unchangedSinceModSequence) async {
    if (flags.length == 1 && flags.first == MessageFlags.deleted) {
      if (action == StoreAction.remove) {
        await _popClient.reset();
      }
      final ids = sequence.toList(_selectedMailbox?.messagesExists);
      for (final id in ids) {
        await _popClient.delete(id);
      }
    }
    throw StateError('POP does not support storing flags.');
  }

  @override
  bool supportsFlagging() {
    return false;
  }

  @override
  Future<MimePart> fetchMessagePart(MimeMessage message, String fetchId) {
    throw StateError('POP does not support fetching message parts.');
  }

  @override
  Future<MimeMessage> fetchMessageContents(MimeMessage message,
      {int? maxSize,
      bool? markAsSeen,
      List<MediaToptype>? includedInlineTypes}) async {
    final id = message.sequenceId;
    final messageResponse = await _popClient.retrieve(id);
    return messageResponse;
  }

  @override
  Future<DeleteResult> deleteMessages(
      MessageSequence sequence, Mailbox? trashMailbox,
      {bool expunge = false}) async {
    final ids = sequence.toList(_selectedMailbox?.messagesExists);
    for (final id in ids) {
      await _popClient.delete(id);
    }
    return DeleteResult(false, DeleteAction.pop, sequence, _selectedMailbox,
        null, null, mailClient);
  }

  @override
  Future<DeleteResult> deleteAllMessages(Mailbox mailbox,
      {bool expunge = false}) {
    // TODO: implement deleteAllMessages
    throw UnimplementedError();
  }

  @override
  Future<DeleteResult> undoDeleteMessages(DeleteResult deleteResult) {
    // TODO: implement undoDeleteMessages
    throw UnimplementedError();
  }

  @override
  Future<MoveResult> moveMessages(MessageSequence sequence, Mailbox target) {
    // TODO: implement moveMessages
    throw UnimplementedError();
  }

  @override
  Future<MoveResult> undoMove(MoveResult moveResult) {
    // TODO: implement undoMove
    throw UnimplementedError();
  }

  @override
  Future<MailSearchResult> searchMessages(MailSearch search) {
    // TODO: implement searchMessages
    throw UnimplementedError();
  }

  @override
  Future<UidResponseCode?> appendMessage(
      MimeMessage message, Mailbox targetMailbox, List<String>? flags) {
    // TODO: implement appendMessage
    throw UnimplementedError();
  }

  @override
  bool get supports8BitEncoding => false; // TODO implement

  @override
  bool get supportsAppendingMessages => false;

  @override
  Future noop() {
    return _popClient.noop();
  }

  @override
  Future<ThreadResult> fetchThreads(
      Mailbox mailbox,
      DateTime since,
      ThreadPreference threadPreference,
      FetchPreference fetchPreference,
      int pageSize) {
    // TODO: implement fetchThreads
    throw UnimplementedError();
  }

  @override
  bool get supportsThreading => false;

  @override
  Future<ThreadDataResult> fetchThreadData(
      Mailbox mailbox, DateTime since, bool setThreadSequences) {
    // TODO: implement fetchThreadData
    throw UnimplementedError();
  }

  @override
  Future<Mailbox> createMailbox(String mailboxName, {Mailbox? parentMailbox}) {
    // TODO: implement createMailbox
    throw UnimplementedError();
  }

  @override
  bool get supportsMailboxes => false;

  @override
  Future<void> deleteMailbox(Mailbox mailbox) {
    // TODO: implement deleteMailbox
    throw UnimplementedError();
  }
}

abstract class _OutgoingMailClient {
  ClientBase get client;
  ServerType get clientType;

  /// Checks if the incoming mail client supports 8 bit encoded messages - is only correct after authorizing
  Future<bool> supports8BitEncoding();

  Future<void> sendMessage(MimeMessage message,
      {MailAddress? from,
      bool use8BitEncoding = false,
      List<MailAddress>? recipients});

  Future<void> disconnect();
}

class _OutgoingSmtpClient extends _OutgoingMailClient {
  @override
  ClientBase get client => _smtpClient;
  @override
  ServerType get clientType => ServerType.smtp;
  final MailClient mailClient;
  final SmtpClient _smtpClient;
  final MailServerConfig _mailConfig;

  _OutgoingSmtpClient(this.mailClient, outgoingClientDomain, EventBus? eventBus,
      bool isLogEnabled, String logName, MailServerConfig mailConfig,
      {bool Function(X509Certificate)? onBadCertificate})
      : _smtpClient = SmtpClient(
          outgoingClientDomain,
          bus: eventBus,
          isLogEnabled: isLogEnabled,
          logName: logName,
          onBadCertificate: onBadCertificate,
        ),
        _mailConfig = mailConfig;

  Future<void> _connectOutgoingIfRequired() async {
    if (!_smtpClient.isLoggedIn) {
      final config = _mailConfig.serverConfig!;
      final isSecure = (config.socketType == SocketType.ssl);
      try {
        await _smtpClient.connectToServer(config.hostname!, config.port!,
            isSecure: isSecure);
        await _smtpClient.ehlo();
        if (!isSecure && _smtpClient.serverInfo.supportsStartTls) {
          await _smtpClient.startTls();
        }
        await _mailConfig.authentication!
            .authenticate(config, smtp: _smtpClient);
      } on SmtpException catch (e, s) {
        throw MailException.fromSmtp(mailClient, e, s);
      } catch (e, s) {
        throw MailException(mailClient, e.toString(),
            stackTrace: s, details: e);
      }
    }
  }

  @override
  Future<void> sendMessage(
    MimeMessage message, {
    MailAddress? from,
    bool use8BitEncoding = false,
    List<MailAddress>? recipients,
  }) async {
    await _connectOutgoingIfRequired();
    try {
      if (_smtpClient.serverInfo.supportsChunking) {
        await _smtpClient.sendChunkedMessage(
          message,
          from: from,
          use8BitEncoding: use8BitEncoding,
          recipients: recipients,
        );
      } else {
        await _smtpClient.sendMessage(
          message,
          from: from,
          use8BitEncoding: use8BitEncoding,
          recipients: recipients,
        );
      }
    } on SmtpException catch (e) {
      throw MailException.fromSmtp(mailClient, e);
    }
  }

  @override
  Future<void> disconnect() {
    return _smtpClient.disconnect();
  }

  @override
  Future<bool> supports8BitEncoding() async {
    if (!_smtpClient.isLoggedIn) {
      await _connectOutgoingIfRequired();
    }
    return _smtpClient.serverInfo.supports8BitMime;
  }
}
