import 'dart:async';

import 'package:enough_mail/imap/message_sequence.dart';
import 'package:test/test.dart';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:event_bus/event_bus.dart';
import 'package:enough_mail/enough_mail.dart';
import 'mock_imap_server.dart';
import '../mock_socket.dart';

bool _isLogEnabled = false;
String imapHost, imapUser, imapPassword;
ImapClient client;
MockImapServer mockServer;
Response<List<Capability>> capResponse;
List<ImapFetchEvent> fetchEvents = <ImapFetchEvent>[];
List<int> expungedMessages = <int>[];
MessageSequence vanishedMessages;
const String supportedMessageFlags =
    r'\Answered \Flagged \Deleted \Seen \Draft $Forwarded $social $promotion $HasAttachment $HasNoAttachment $HasChat $MDNSent';
const String supportedPermanentMessageFlags = supportedMessageFlags + r' \*';
ServerMailbox mockInbox;
Mailbox inbox;

void main() {
  setUp(() async {
    if (client != null) {
      return;
    }
    _log('setting up ImapClient tests');
    var envVars = Platform.environment;

    var imapPort = 993;
    var useRealConnection =
        (!envVars.containsKey('IMAP_USE') || envVars['IMAP_USE'] == 'true') &&
            envVars.containsKey('IMAP_HOST') &&
            envVars.containsKey('IMAP_USER') &&
            envVars.containsKey('IMAP_PASSWORD');
    if (useRealConnection) {
      if (envVars.containsKey('IMAP_LOG')) {
        _isLogEnabled = (envVars['IMAP_LOG'] == 'true');
      } else {
        _isLogEnabled = true;
      }
      imapHost = envVars['IMAP_HOST'];
      imapUser = envVars['IMAP_USER'];
      imapPassword = envVars['IMAP_PASSWORD'];
      if (envVars.containsKey('IMAP_PORT')) {
        imapPort = int.parse(envVars['IMAP_PORT']);
      }
    } else if (envVars.containsKey('IMAP_LOG')) {
      _isLogEnabled = (envVars['IMAP_LOG'] == 'true');
      //print("log-enabled: $_isLogEnabled  [IMAP_LOG=${envVars['IMAP_LOG']}]");
    }
    //_isLogEnabled = true;
    client = ImapClient(bus: EventBus(sync: true), isLogEnabled: _isLogEnabled);

    client.eventBus
        .on<ImapExpungeEvent>()
        .listen((e) => expungedMessages.add(e.messageSequenceId));
    client.eventBus
        .on<ImapVanishedEvent>()
        .listen((e) => vanishedMessages = e.vanishedMessages);
    client.eventBus.on<ImapFetchEvent>().listen((e) => fetchEvents.add(e));

    if (useRealConnection) {
      await client.connectToServer(imapHost, imapPort);
      capResponse = await client.login(imapUser, imapPassword);
    } else {
      var connection = MockConnection();
      client.connect(connection.socketClient);
      mockServer = MockImapServer.connect(connection.socketServer);
      client.serverInfo = ImapServerInfo()
        ..host = 'imaptest.enough.de'
        ..port = 993
        ..isSecure = true;
      capResponse = await client.login('testuser', 'testpassword');
    }
    mockInbox = ServerMailbox('INBOX', [MailboxFlag.hasChildren],
        supportedMessageFlags, supportedPermanentMessageFlags);
    _log('ImapClient test setup complete');
  });

  test('ImapClient login', () async {
    _log('login result: ${capResponse.status}');
    expect(capResponse.status, ResponseStatus.OK);
    expect(capResponse.result, isNotNull,
        reason: 'capability response does not contain a result');
    expect(capResponse.result.isNotEmpty, true,
        reason: 'capability response does not contain a single capability');
    _log('');
    _log('Capabilities=${capResponse.result}');
    if (mockServer != null) {
      expect(capResponse.result.length, 3);
      expect(capResponse.result[0].name, 'IMAP4rev1');
      expect(capResponse.result[1].name, 'IDLE');
      expect(capResponse.result[2].name, 'METADATA');
    }
  });

  test('ImapClient authenticateWithOAuth2', () async {
    if (mockServer != null) {
      var authResponse =
          await client.authenticateWithOAuth2('testuser', 'ABC123456789abc');
      expect(authResponse.status, ResponseStatus.OK);
    }
  });

  test('ImapClient authenticateWithOAuthBearer', () async {
    if (mockServer != null) {
      var authResponse = await client.authenticateWithOAuthBearer(
          'testuser', 'ABC123456789abc');
      expect(authResponse.status, ResponseStatus.OK);
    }
  });

  test('ImapClient capability', () async {
    var capabilityResponse = await client.capability();
    expect(capabilityResponse.status, ResponseStatus.OK);
    expect(capabilityResponse.result, isNotNull,
        reason: 'capability response does not contain a result');
    expect(capabilityResponse.result.isNotEmpty, true,
        reason: 'capability response does not contain a single capability');
    _log('');
    _log('Capabilities=${capabilityResponse.result}');
    if (mockServer != null) {
      expect(capabilityResponse.result.length, 3);
      expect(capabilityResponse.result[0].name, 'IMAP4rev1');
      expect(capabilityResponse.result[1].name, 'IDLE');
      expect(capabilityResponse.result[2].name, 'METADATA');
    }
  });

  test('ImapClient listMailboxes', () async {
    _log('');
    if (mockServer != null) {
      mockInbox.messagesExists = 256;
      mockInbox.messagesRecent = 23;
      mockInbox.firstUnseenMessageSequenceId = 21419;
      mockInbox.uidValidity = 1466002015;
      mockInbox.uidNext = 37323;
      mockInbox.highestModSequence = 110414;
      mockServer.mailboxes.clear();
      mockServer.mailboxes.add(mockInbox);
      mockServer.mailboxes.add(ServerMailbox(
          'Public',
          List<MailboxFlag>.from(
              [MailboxFlag.noSelect, MailboxFlag.hasChildren]),
          supportedMessageFlags,
          supportedPermanentMessageFlags));
      mockServer.mailboxes.add(ServerMailbox(
          'Shared',
          List<MailboxFlag>.from(
              [MailboxFlag.noSelect, MailboxFlag.hasChildren]),
          supportedMessageFlags,
          supportedPermanentMessageFlags));
    }
    var listResponse = await client.listMailboxes();
    _log('list result: ${listResponse.status}');
    expect(listResponse.status, ResponseStatus.OK,
        reason: 'expecting OK list result');
    expect(listResponse.result, isNotNull,
        reason: 'list response does not conatin a result');
    expect(listResponse.result.isNotEmpty, true,
        reason: 'list response does not contain a single mailbox');
    for (var box in listResponse.result) {
      _log('list mailbox: ' +
          box.name +
          (box.hasChildren ? ' with children' : ' without children') +
          (box.isUnselectable ? ' not selectable' : ' selectable'));
    }
    if (mockServer != null) {
      expect(client.serverInfo.pathSeparator, mockServer.pathSeparator,
          reason: 'different path separator than in server');
      expect(3, listResponse.result.length,
          reason: 'Set up 3 mailboxes in root');
      var box = listResponse.result[0];
      expect('INBOX', box.name);
      expect(true, box.hasChildren);
      expect(false, box.isSelected);
      expect(false, box.isUnselectable);
      box = listResponse.result[1];
      expect('Public', box.name);
      expect(true, box.hasChildren);
      expect(false, box.isSelected);
      expect(true, box.isUnselectable);
      box = listResponse.result[2];
      expect('Shared', box.name);
      expect(true, box.hasChildren);
      expect(false, box.isSelected);
      expect(true, box.isUnselectable);
    }
  });
  test('ImapClient LSUB', () async {
    _log('');
    if (mockServer != null) {
      mockServer.mailboxesSubscribed.clear();
      mockServer.mailboxesSubscribed.add(mockInbox);
      mockServer.mailboxesSubscribed.add(ServerMailbox(
          'Public',
          List<MailboxFlag>.from(
              [MailboxFlag.noSelect, MailboxFlag.hasChildren]),
          supportedMessageFlags,
          supportedPermanentMessageFlags));
    }
    var listResponse = await client.listSubscribedMailboxes();
    _log('lsub result: ' + listResponse.status.toString());
    expect(listResponse.status, ResponseStatus.OK,
        reason: 'expecting OK lsub result');
    expect(listResponse.result, isNotNull,
        reason: 'lsub response does not contain a result');
    expect(listResponse.result.isNotEmpty, true,
        reason: 'lsub response does not contain a single mailbox');
    for (var box in listResponse.result) {
      _log('lsub mailbox: ' +
          box.name +
          (box.hasChildren ? ' with children' : ' without children') +
          (box.isUnselectable ? ' not selectable' : ' selectable'));
    }
    if (mockServer != null) {
      expect(client.serverInfo.pathSeparator, mockServer.pathSeparator,
          reason: 'different path separator than in server');
      expect(2, listResponse.result.length,
          reason: 'Set up 2 mailboxes as subscribed');
      var box = listResponse.result[0];
      expect('INBOX', box.name);
      expect(true, box.hasChildren);
      expect(false, box.isSelected);
      expect(false, box.isUnselectable);
      box = listResponse.result[1];
      expect('Public', box.name);
      expect(true, box.hasChildren);
      expect(false, box.isSelected);
      expect(true, box.isUnselectable);
    }
  });
  test('ImapClient LIST Inbox', () async {
    _log('');
    var listResponse = await client.listMailboxes(path: 'INBOX');
    _log('INBOX result: ' + listResponse.status.toString());
    expect(listResponse.status, ResponseStatus.OK,
        reason: 'expecting OK LIST INBOX result');
    expect(listResponse.result, isNotNull,
        reason: 'list response does not contain a result ');
    expect(listResponse.result.length == 1, true,
        reason: 'list response does not contain exactly one result');
    for (var box in listResponse.result) {
      _log('INBOX mailbox: ' +
          box.path +
          (box.hasChildren ? ' with children' : ' without children') +
          (box.isSelected ? ' select' : ' no select'));
    }
    if (mockServer != null) {
      expect(client.serverInfo.pathSeparator, mockServer.pathSeparator,
          reason: 'different path separator than in server');
      expect(1, listResponse.result.length,
          reason: 'There can be only one INBOX');
      var box = listResponse.result[0];
      expect('INBOX', box.name);
      expect(true, box.hasChildren);
      expect(false, box.isSelected);
      expect(false, box.isUnselectable);
    }

    _log('');
    inbox = listResponse.result[0];
    var selectResponse = await client.selectMailbox(inbox);
    expect(selectResponse.status, ResponseStatus.OK,
        reason: 'expecting OK SELECT INBOX response');
    expect(selectResponse.result, isNotNull,
        reason: 'select response does not contain a result ');
    expect(selectResponse.result.isReadWrite, true,
        reason: 'SELECT should open INBOX in READ-WRITE ');
    expect(
        selectResponse.result.messagesExists != null &&
            selectResponse.result.messagesExists > 0,
        true,
        reason: 'expecting at least 1 mail in INBOX');
    _log(
        '${inbox.name} exist=${inbox.messagesExists} recent=${inbox.messagesRecent} uidValidity=${inbox.uidValidity} uidNext=${inbox.uidNext}');
    if (mockServer != null) {
      expect(inbox.messagesExists, 256);
      expect(inbox.messagesRecent, 23);
      expect(inbox.firstUnseenMessageSequenceId, 21419);
      expect(inbox.uidValidity, 1466002015);
      expect(inbox.uidNext, 37323);
      expect(inbox.highestModSequence, 110414);
      expect(inbox.messageFlags, isNotNull, reason: 'message flags expected');
      expect(_toString(inbox.messageFlags),
          r'\Answered \Flagged \Deleted \Seen \Draft $Forwarded $social $promotion $HasAttachment $HasNoAttachment $HasChat $MDNSent');
      expect(inbox.permanentMessageFlags, isNotNull,
          reason: 'permanent message flags expected');
      expect(_toString(inbox.permanentMessageFlags),
          r'\Answered \Flagged \Deleted \Seen \Draft $Forwarded $social $promotion $HasAttachment $HasNoAttachment $HasChat $MDNSent \*');
    }
  });

  test('ImapClient search', () async {
    _log('');
    if (mockServer != null) {
      mockInbox.messageSequenceIdsUnseen = [
        mockInbox.firstUnseenMessageSequenceId,
        3423,
        17,
        3
      ];
    }
    var searchResponse = await client.searchMessages('UNSEEN');
    expect(searchResponse.status, ResponseStatus.OK);
    expect(searchResponse.result.ids, isNotNull);
    expect(searchResponse.result.ids, isNotEmpty);
    _log('searched messages: ' + searchResponse.result.toString());
    if (mockServer != null) {
      expect(searchResponse.result.ids.length,
          mockInbox.messageSequenceIdsUnseen.length);
      expect(searchResponse.result.ids,
          [mockInbox.firstUnseenMessageSequenceId, 3423, 17, 3]);
    }
  });

  test('ImapClient uid search', () async {
    _log('');
    if (mockServer != null) {
      mockInbox.messageSequenceIdsUnseen = [
        mockInbox.firstUnseenMessageSequenceId,
        3423,
        17,
        3
      ];
    }
    var searchResponse = await client.uidSearchMessages('UNSEEN');
    expect(searchResponse.status, ResponseStatus.OK);
    expect(searchResponse.result.ids, isNotNull);
    expect(searchResponse.result.ids, isNotEmpty);
    _log('uid searched messages: ${searchResponse.result}');
    if (mockServer != null) {
      expect(searchResponse.result.ids.length,
          mockInbox.messageSequenceIdsUnseen.length);
      expect(searchResponse.result.ids,
          [mockInbox.firstUnseenMessageSequenceId, 3423, 17, 3]);
    }
  });

  test('ImapClient fetch FULL', () async {
    _log('');
    var lowerIndex = math.max(inbox.messagesExists - 1, 0);
    if (mockServer != null) {
      mockServer.fetchResponses.clear();
      mockServer.fetchResponses.add(inbox.messagesExists.toString() +
          r' FETCH (MODSEQ (12323) FLAGS () INTERNALDATE "25-Oct-2019 16:35:31 +0200" '
              'RFC822.SIZE 15320 ENVELOPE ("Fri, 25 Oct 2019 16:35:28 +0200 (CEST)" {61}\r\n'
              'New appointment: SoW (x2) for rebranding of App & Mobile Apps'
              '(("=?UTF-8?Q?Sch=C3=B6n=2C_Rob?=" NIL "rob.schoen" "domain.com")) (("=?UTF-8?Q?Sch=C3=B6n=2C_'
              'Rob?=" NIL "rob.schoen" "domain.com")) (("=?UTF-8?Q?Sch=C3=B6n=2C_Rob?=" NIL "rob.schoen" '
              '"domain.com")) (("Alice Dev" NIL "alice.dev" "domain.com")) NIL NIL "<Appointment.59b0d625-afaf-4fc6'
              '-b845-4b0fce126730@domain.com>" "<130499090.797.1572014128349@product-gw2.domain.com>") BODY (("text" "plain" '
              '("charset" "UTF-8") NIL NIL "quoted-printable" 1289 53)("text" "html" ("charset" "UTF-8") NIL NIL "quoted-printable" '
              '7496 302) "alternative"))');
      mockServer.fetchResponses.add(lowerIndex.toString() +
          r' FETCH (MODSEQ (12328) FLAGS (new seen) INTERNALDATE "25-Oct-2019 17:03:12 +0200" '
              'RFC822.SIZE 20630 ENVELOPE ("Fri, 25 Oct 2019 11:02:30 -0400 (EDT)" "New appointment: Discussion and '
              'Q&A" (("Tester, Theresa" NIL "t.tester" "domain.com")) (("Tester, Theresa" NIL "t.tester" "domain.com"))'
              ' (("Tester, Theresa" NIL "t.tester" "domain.com")) (("Alice Dev" NIL "alice.dev" "domain.com"))'
              ' NIL NIL "<Appointment.963a03aa-4a81-49bf-b3a2-77e39df30ee9@domain.com>" "<1814674343.1008.1572015750561@appsuite-g'
              'w2.domain.com>") BODY (("TEXT" "PLAIN" ("CHARSET" "US-ASCII") NIL NIL "7BIT" 1152 '
              '23)("TEXT" "PLAIN" ("CHARSET" "US-ASCII" "NAME" "cc.diff")'
              '"<960723163407.20117h@cac.washington.edu>" "Compiler diff" '
              '"BASE64" 4554 73) "MIXED"))');
    }
    var fetchResponse = await client.fetchMessages(
        MessageSequence.fromRange(lowerIndex, inbox.messagesExists), 'FULL',
        changedSinceModSequence: 0);
    expect(fetchResponse.status, ResponseStatus.OK,
        reason: 'support for FETCH FULL expected');
    if (mockServer != null) {
      expect(fetchResponse.result, isNotNull, reason: 'fetch result expected');
      expect(fetchResponse.result.messages.length, 2);
      var message = fetchResponse.result.messages[0];
      expect(message.sequenceId, lowerIndex + 1);
      expect(message.modSequence, 12323);
      expect(message.flags, isNotNull);
      expect(message.flags.length, 0);
      expect(message.internalDate, '25-Oct-2019 16:35:31 +0200');
      expect(message.size, 15320);
      expect(message.envelope, isNotNull);
      expect(message.envelope.date,
          DateCodec.decodeDate('Fri, 25 Oct 2019 16:35:28 +0200 (CEST)'));
      expect(message.envelope.subject,
          'New appointment: SoW (x2) for rebranding of App & Mobile Apps');
      expect(message.envelope.inReplyTo,
          '<Appointment.59b0d625-afaf-4fc6-b845-4b0fce126730@domain.com>');
      expect(message.envelope.messageId,
          '<130499090.797.1572014128349@product-gw2.domain.com>');
      expect(message.cc, isNotNull);
      expect(message.cc.isEmpty, isTrue);
      expect(message.bcc, isNotNull);
      expect(message.bcc.isEmpty, isTrue);
      expect(message.envelope.from, isNotNull);
      expect(message.envelope.from.length, 1);
      expect(message.envelope.from.first.personalName, 'Schön, Rob');
      expect(message.envelope.from.first.sourceRoute, null);
      expect(message.envelope.from.first.mailboxName, 'rob.schoen');
      expect(message.envelope.from.first.hostName, 'domain.com');
      expect(message.from, isNotNull);
      expect(message.from.length, 1);
      expect(message.from.first.personalName, 'Schön, Rob');
      expect(message.from.first.sourceRoute, null);
      expect(message.from.first.mailboxName, 'rob.schoen');
      expect(message.from.first.hostName, 'domain.com');
      expect(message.sender, isNotNull);
      expect(message.sender.personalName, 'Schön, Rob');
      expect(message.sender.sourceRoute, null);
      expect(message.sender.mailboxName, 'rob.schoen');
      expect(message.sender.hostName, 'domain.com');
      expect(message.replyTo, isNotNull);
      expect(message.replyTo.first.personalName, 'Schön, Rob');
      expect(message.replyTo.first.sourceRoute, null);
      expect(message.replyTo.first.mailboxName, 'rob.schoen');
      expect(message.replyTo.first.hostName, 'domain.com');
      expect(message.to, isNotNull);
      expect(message.to.first.personalName, 'Alice Dev');
      expect(message.to.first.sourceRoute, null);
      expect(message.to.first.mailboxName, 'alice.dev');
      expect(message.to.first.hostName, 'domain.com');
      expect(message.body, isNotNull);
      expect(message.body.contentType, isNotNull);
      expect(message.body.contentType.mediaType.sub,
          MediaSubtype.multipartAlternative);
      expect(message.body.parts, isNotNull);
      expect(message.body.parts.length, 2);
      expect(message.body.parts[0].contentType, isNotNull);
      expect(message.body.parts[0].contentType.mediaType.sub,
          MediaSubtype.textPlain);
      expect(message.body.parts[0].description, null);
      expect(message.body.parts[0].id, null);
      expect(message.body.parts[0].encoding, 'quoted-printable');
      expect(message.body.parts[0].size, 1289);
      expect(message.body.parts[0].numberOfLines, 53);
      expect(message.body.parts[0].contentType.charset, 'utf-8');
      expect(message.body.parts[1].contentType.mediaType.sub,
          MediaSubtype.textHtml);
      expect(message.body.parts[1].description, null);
      expect(message.body.parts[1].id, null);
      expect(message.body.parts[1].encoding, 'quoted-printable');
      expect(message.body.parts[1].size, 7496);
      expect(message.body.parts[1].numberOfLines, 302);
      expect(message.body.parts[1].contentType.charset, 'utf-8');

      message = fetchResponse.result.messages[1];
      expect(message.sequenceId, lowerIndex);
      expect(message.modSequence, 12328);
      expect(message.flags, isNotNull);
      expect(message.flags.length, 2);
      expect(message.flags[0], 'new');
      expect(message.flags[1], 'seen');
      expect(message.internalDate, '25-Oct-2019 17:03:12 +0200');
      expect(message.size, 20630);
      expect(message.envelope.date,
          DateCodec.decodeDate('Fri, 25 Oct 2019 11:02:30 -0400 (EDT)'));
      expect(message.envelope.subject, 'New appointment: Discussion and Q&A');
      expect(message.envelope.inReplyTo,
          '<Appointment.963a03aa-4a81-49bf-b3a2-77e39df30ee9@domain.com>');
      expect(message.envelope.messageId,
          '<1814674343.1008.1572015750561@appsuite-gw2.domain.com>');
      expect(message.cc, isNotNull);
      expect(message.cc.isEmpty, isTrue);
      expect(message.bcc, isNotNull);
      expect(message.bcc.isEmpty, isTrue);
      expect(message.from, isNotNull);
      expect(message.from.length, 1);
      expect(message.from.first.personalName, 'Tester, Theresa');
      expect(message.from.first.sourceRoute, null);
      expect(message.from.first.mailboxName, 't.tester');
      expect(message.from.first.hostName, 'domain.com');
      expect(message.sender, isNotNull);
      expect(message.sender.personalName, 'Tester, Theresa');
      expect(message.sender.sourceRoute, null);
      expect(message.sender.mailboxName, 't.tester');
      expect(message.sender.hostName, 'domain.com');
      expect(message.replyTo, isNotNull);
      expect(message.replyTo.first.personalName, 'Tester, Theresa');
      expect(message.replyTo.first.sourceRoute, null);
      expect(message.replyTo.first.mailboxName, 't.tester');
      expect(message.replyTo.first.hostName, 'domain.com');
      expect(message.to, isNotNull);
      expect(message.to.first.personalName, 'Alice Dev');
      expect(message.to.first.sourceRoute, null);
      expect(message.to.first.mailboxName, 'alice.dev');
      expect(message.to.first.hostName, 'domain.com');
      expect(message.body, isNotNull);
      expect(
          message.body.contentType.mediaType.sub, MediaSubtype.multipartMixed);
      expect(message.body.parts, isNotNull);
      expect(message.body.parts.length, 2);
      expect(message.body.parts[0].contentType.mediaType.sub,
          MediaSubtype.textPlain);
      expect(message.body.parts[0].description, null);
      expect(message.body.parts[0].id, null);
      expect(message.body.parts[0].encoding, '7bit');
      expect(message.body.parts[0].size, 1152);
      expect(message.body.parts[0].numberOfLines, 23);
      expect(message.body.parts[0].contentType.charset, 'us-ascii');
      expect(message.body.parts[1].contentType.mediaType.sub,
          MediaSubtype.textPlain);
      expect(message.body.parts[1].description, 'Compiler diff');
      expect(
          message.body.parts[1].id, '<960723163407.20117h@cac.washington.edu>');
      expect(message.body.parts[1].encoding, 'base64');
      expect(message.body.parts[1].size, 4554);
      expect(message.body.parts[1].numberOfLines, 73);
      expect(message.body.parts[1].contentType.charset, 'us-ascii');
      expect(message.body.parts[1].contentType.parameters['name'], 'cc.diff');
    }
  });

  test('ImapClient fetch BODY[HEADER]', () async {
    _log('');
    var lowerIndex = math.max(inbox.messagesExists - 1, 0);
    if (mockServer != null) {
      mockServer.fetchResponses.clear();
      mockServer.fetchResponses.add(inbox.messagesExists.toString() +
          ' FETCH (BODY[HEADER] {345}\r\n'
              'Date: Wed, 17 Jul 1996 02:23:25 -0700 (PDT)\r\n'
              'From: Terry Gray <gray@cac.washington.edu>\r\n'
              'Subject: IMAP4rev1 WG mtg summary and minutes\r\n'
              'To: imap@cac.washington.edu\r\n'
              'cc: minutes@CNRI.Reston.VA.US, \r\n'
              '   John Klensin <KLENSIN@MIT.EDU>\r\n'
              'Message-Id: <B27397-0100000@cac.washington.edu>\r\n'
              'MIME-Version: 1.0\r\n'
              'Content-Type: TEXT/PLAIN; CHARSET=US-ASCII\r\n'
              ')\r\n');
      mockServer.fetchResponses.add(lowerIndex.toString() +
          ' FETCH (BODY[HEADER] {319}\r\n'
              'Date: Wed, 17 Jul 2020 02:23:25 -0700 (PDT)\r\n'
              'From: COI JOY <coi@coi.me>\r\n'
              'Subject: COI\r\n'
              'To: imap@cac.washington.edu\r\n'
              'cc: minutes@CNRI.Reston.VA.US, \r\n'
              '   John Klensin <KLENSIN@MIT.EDU>\r\n'
              'Message-Id: <chat\$.B27397-0100000@cac.washington.edu>\r\n'
              'MIME-Version: 1.0\r\n'
              'Chat-Version: 1.0\r\n'
              'Content-Type: text/plan; charset="UTF-8"\r\n'
              ')\r\n');
    }
    var fetchResponse = await client.fetchMessages(
        MessageSequence.fromRange(lowerIndex, inbox.messagesExists),
        'BODY[HEADER]');
    expect(fetchResponse.status, ResponseStatus.OK,
        reason: 'support for FETCH BODY[] expected');
    if (mockServer != null) {
      expect(fetchResponse.result, isNotNull, reason: 'fetch result expected');
      // for (int i=0; i<fetchResponse.result.length; i++) {
      //   print("$i: fetch body[header]:");
      //   print(fetchResponse.result[i].toString());
      // }

      expect(fetchResponse.result.messages.length, 2);
      var message = fetchResponse.result.messages[0];
      expect(message.sequenceId, lowerIndex + 1);
      expect(message.headers, isNotNull);
      expect(message.headers.length, 8);
      expect(message.getHeaderValue('From'),
          'Terry Gray <gray@cac.washington.edu>');

      message = fetchResponse.result.messages[1];
      expect(message.sequenceId, lowerIndex);
      expect(message.headers, isNotNull);
      expect(message.headers.length, 9);
      expect(message.getHeaderValue('Chat-Version'), '1.0');
      expect(
          message.getHeaderValue('Content-Type'), 'text/plan; charset="UTF-8"');
    }
  });

  test('ImapClient uid fetch BODY[HEADER]', () async {
    _log('');
    var lowerId = math.max(inbox.uidNext - 2, 0);
    if (mockServer != null) {
      mockServer.fetchResponses.clear();
      mockServer.fetchResponses.add(inbox.messagesExists.toString() +
          ' FETCH (BODY[HEADER] {345}\r\n'
              'Date: Wed, 17 Jul 1996 02:23:25 -0700 (PDT)\r\n'
              'From: Terry Gray <gray@cac.washington.edu>\r\n'
              'Subject: IMAP4rev1 WG mtg summary and minutes\r\n'
              'To: imap@cac.washington.edu\r\n'
              'cc: minutes@CNRI.Reston.VA.US, \r\n'
              '   John Klensin <KLENSIN@MIT.EDU>\r\n'
              'Message-Id: <B27397-0100000@cac.washington.edu>\r\n'
              'MIME-Version: 1.0\r\n'
              'Content-Type: TEXT/PLAIN; CHARSET=US-ASCII\r\n'
              ')\r\n');
      mockServer.fetchResponses.add(lowerId.toString() +
          ' FETCH (BODY[HEADER] {319}\r\n'
              'Date: Wed, 17 Jul 2020 02:23:25 -0700 (PDT)\r\n'
              'From: COI JOY <coi@coi.me>\r\n'
              'Subject: COI\r\n'
              'To: imap@cac.washington.edu\r\n'
              'cc: minutes@CNRI.Reston.VA.US, \r\n'
              '   John Klensin <KLENSIN@MIT.EDU>\r\n'
              'Message-Id: <chat\$.B27397-0100000@cac.washington.edu>\r\n'
              'MIME-Version: 1.0\r\n'
              'Chat-Version: 1.0\r\n'
              'Content-Type: text/plan; charset="UTF-8"\r\n'
              ')\r\n');
    }
    var fetchResponse = await client.uidFetchMessages(
        MessageSequence.fromRange(lowerId, inbox.uidNext - 1), 'BODY[HEADER]');
    expect(fetchResponse.status, ResponseStatus.OK,
        reason: 'support for FETCH BODY[] expected');
    if (mockServer != null) {
      expect(fetchResponse.result, isNotNull, reason: 'fetch result expected');
      // for (int i=0; i<fetchResponse.result.length; i++) {
      //   print("$i: fetch body[header]:");
      //   print(fetchResponse.result[i].toString());
      // }

      expect(fetchResponse.result.messages.length, 2);
      var message = fetchResponse.result.messages[0];
      expect(message.headers, isNotNull);
      expect(message.headers.length, 8);
      expect(message.getHeaderValue('From'),
          'Terry Gray <gray@cac.washington.edu>');

      message = fetchResponse.result.messages[1];
      expect(message.headers, isNotNull);
      expect(message.headers.length, 9);
      expect(message.getHeaderValue('Chat-Version'), '1.0');
      expect(
          message.getHeaderValue('Content-Type'), 'text/plan; charset="UTF-8"');
    }
  });

  test('ImapClient fetch BODY.PEEK[HEADER.FIELDS (References)]', () async {
    _log('');
    var lowerIndex = math.max(inbox.messagesExists - 1, 0);
    if (mockServer != null) {
      mockServer.fetchResponses.clear();
      mockServer.fetchResponses.add(inbox.messagesExists.toString() +
          ' FETCH (BODY[HEADER.FIELDS (REFERENCES)] {50}\r\n'
              r'References: <chat$1579598212023314@russyl.com>'
              '\r\n\r\n'
              ')\r\n');
      mockServer.fetchResponses.add(lowerIndex.toString() +
          ' FETCH (BODY[HEADER.FIELDS (REFERENCES)] {2}\r\n'
              '\r\n'
              ')\r\n');
    }
    var fetchResponse = await client.fetchMessages(
        MessageSequence.fromRange(lowerIndex, inbox.messagesExists),
        'BODY.PEEK[HEADER.FIELDS (REFERENCES)]');
    expect(fetchResponse.status, ResponseStatus.OK,
        reason:
            'support for FETCH BODY.PEEK[HEADER.FIELDS (REFERENCES)] expected');
    if (mockServer != null) {
      expect(fetchResponse.result, isNotNull, reason: 'fetch result expected');

      expect(fetchResponse.result.messages.length, 2);
      var message = fetchResponse.result.messages[0];
      expect(message.sequenceId, lowerIndex + 1);
      expect(message.headers, isNotNull);
      expect(message.headers.length, 1);
      expect(message.getHeaderValue('References'),
          r'<chat$1579598212023314@russyl.com>');

      message = fetchResponse.result.messages[1];
      expect(message.sequenceId, lowerIndex);
      expect(message.headers == null, true);
      expect(message.getHeaderValue('References'), null);
      //expect(message.headers.length, 0);
      // expect(message.getHeaderValue('Chat-Version'), '1.0');
      // expect(
      //     message.getHeaderValue('Content-Type'), 'text/plan; charset="UTF-8"');
    }
  });

  test('ImapClient fetch BODY.PEEK[HEADER.FIELDS.NOT (References)]', () async {
    _log('');
    var lowerIndex = math.max(inbox.messagesExists - 1, 0);
    if (mockServer != null) {
      mockServer.fetchResponses.clear();
      mockServer.fetchResponses.add(inbox.messagesExists.toString() +
          ' FETCH (BODY[HEADER.FIELDS.NOT (REFERENCES)] {46}\r\n'
              'From: Shirley <Shirley.Jackson@domain.com>\r\n'
              '\r\n'
              ')\r\n');
      mockServer.fetchResponses.add(lowerIndex.toString() +
          ' FETCH (BODY[HEADER.FIELDS.NOT (REFERENCES)] {2}\r\n'
              '\r\n'
              ')\r\n');
    }
    var fetchResponse = await client.fetchMessages(
        MessageSequence.fromRange(lowerIndex, inbox.messagesExists),
        'BODY.PEEK[HEADER.FIELDS.NOT (REFERENCES)]');
    expect(fetchResponse.status, ResponseStatus.OK,
        reason:
            'support for FETCH BODY.PEEK[HEADER.FIELDS.NOT (REFERENCES)] expected');
    if (mockServer != null) {
      expect(fetchResponse.result, isNotNull, reason: 'fetch result expected');

      expect(fetchResponse.result.messages.length, 2);
      var message = fetchResponse.result.messages[0];
      expect(message.sequenceId, lowerIndex + 1);
      expect(message.headers, isNotNull);
      expect(message.headers.length, 1);
      expect(message.getHeaderValue('From'),
          'Shirley <Shirley.Jackson@domain.com>');

      message = fetchResponse.result.messages[1];
      expect(message.sequenceId, lowerIndex);
      expect(message.headers == null, true);
      expect(message.getHeaderValue('References'), null);
      expect(message.getHeaderValue('From'), null);
      //expect(message.headers.length, 0);
      // expect(message.getHeaderValue('Chat-Version'), '1.0');
      // expect(
      //     message.getHeaderValue('Content-Type'), 'text/plan; charset="UTF-8"');
    }
  });

  test('ImapClient fetch BODY[]', () async {
    _log('');
    var lowerIndex = math.max(inbox.messagesExists - 1, 0);
    if (mockServer != null) {
      mockServer.fetchResponses.clear();
      mockServer.fetchResponses.add(inbox.messagesExists.toString() +
          ' FETCH (BODY[] {359}\r\n'
              'Date: Wed, 17 Jul 1996 02:23:25 -0700 (PDT)\r\n'
              'From: Terry Gray <gray@cac.washington.edu>\r\n'
              'Subject: IMAP4rev1 WG mtg summary and minutes\r\n'
              'To: imap@cac.washington.edu\r\n'
              'cc: minutes@CNRI.Reston.VA.US, \r\n'
              '   John Klensin <KLENSIN@MIT.EDU>\r\n'
              'Message-Id: <B27397-0100000@cac.washington.edu>\r\n'
              'MIME-Version: 1.0\r\n'
              'Content-Type: TEXT/PLAIN; CHARSET=US-ASCII\r\n'
              '\r\n'
              'Hello Word\r\n'
              ')\r\n');
      mockServer.fetchResponses.add(lowerIndex.toString() +
          ' FETCH (BODY[] {374}\r\n'
              'Date: Wed, 17 Jul 1996 02:23:25 -0700 (PDT)\r\n'
              'From: Terry Gray <gray@cac.washington.edu>\r\n'
              'Subject: IMAP4rev1 WG mtg summary and minutes\r\n'
              'To: imap@cac.washington.edu\r\n'
              'cc: minutes@CNRI.Reston.VA.US, \r\n'
              '   John Klensin <KLENSIN@MIT.EDU>\r\n'
              'Message-Id: <B27397-0100000@cac.washington.edu>\r\n'
              'MIME-Version: 1.0\r\n'
              'Content-Type: text/plain; charset="utf-8"\r\n'
              '\r\n'
              'Welcome to Enough MailKit.\r\n'
              ')\r\n');
    }
    var fetchResponse = await client.fetchMessages(
        MessageSequence.fromRange(lowerIndex, inbox.messagesExists), 'BODY[]');
    expect(fetchResponse.status, ResponseStatus.OK,
        reason: 'support for FETCH BODY[] expected');
    if (mockServer != null) {
      expect(fetchResponse.result, isNotNull, reason: 'fetch result expected');
      expect(fetchResponse.result.messages.length, 2);
      var message = fetchResponse.result.messages[0];
      expect(message.sequenceId, lowerIndex + 1);
      expect(message.bodyRaw, 'Hello Word\r\n');

      message = fetchResponse.result.messages[1];
      expect(message.sequenceId, lowerIndex);
      expect(message.bodyRaw, 'Welcome to Enough MailKit.\r\n');
      expect(message.getHeaderValue('MIME-Version'), '1.0');
      expect(message.getHeaderValue('Content-Type'),
          'text/plain; charset="utf-8"');
      //expect(message.getHeader('Content-Type').first.value, 'text/plain; charset="utf-8"');
    }
  });

  test('ImapClient fetch BODY[1]', () async {
    _log('');
    var lowerIndex = math.max(inbox.messagesExists - 1, 0);
    if (mockServer != null) {
      mockServer.fetchResponses.clear();
      mockServer.fetchResponses.add(inbox.messagesExists.toString() +
          ' FETCH (BODY[1] {12}\r\n'
              'Hello Word\r\n'
              ')\r\n');
      mockServer.fetchResponses.add(lowerIndex.toString() +
          ' FETCH (BODY[1] {28}\r\n'
              'Welcome to Enough MailKit.\r\n'
              ')\r\n');
    }
    var fetchResponse = await client.fetchMessages(
        MessageSequence.fromRange(lowerIndex, inbox.messagesExists), 'BODY[0]');
    expect(fetchResponse.status, ResponseStatus.OK,
        reason: 'support for FETCH BODY[0] expected');
    if (mockServer != null) {
      expect(fetchResponse.result, isNotNull, reason: 'fetch result expected');
      expect(fetchResponse.result.messages.length, 2);
      var message = fetchResponse.result.messages[0];
      expect(message.sequenceId, lowerIndex + 1);
      expect(message.getBodyPart(0), 'Hello Word\r\n');

      message = fetchResponse.result.messages[1];
      expect(message.sequenceId, lowerIndex);
      expect(message.getBodyPart(0), 'Welcome to Enough MailKit.\r\n');
    }
  });

  test('ImapClient noop', () async {
    _log('');
    await Future.delayed(Duration(seconds: 1));
    var noopResponse = await client.noop();
    expect(noopResponse.status, ResponseStatus.OK);

    if (mockServer != null) {
      expungedMessages.clear();
      mockInbox.noopChanges = [
        '2232 EXPUNGE',
        '1234 EXPUNGE',
        '23 EXISTS',
        '3 RECENT',
        r'14 FETCH (FLAGS (\Seen \Deleted))',
        r'2322 FETCH (FLAGS (\Seen $Chat))',
      ];
      noopResponse = await client.noop();
      await Future.delayed(Duration(milliseconds: 50));
      expect(noopResponse.status, ResponseStatus.OK);
      expect(expungedMessages, [2232, 1234],
          reason: 'Expunged messages should fit');
      expect(inbox.messagesExists, 23);
      expect(inbox.messagesRecent, 3);
      expect(fetchEvents.length, 2, reason: 'Expecting 2 fetch events');
      var event = fetchEvents[0];
      expect(event.message, isNotNull);
      expect(event.message.sequenceId, 14);
      expect(event.message.flags, [r'\Seen', r'\Deleted']);
      event = fetchEvents[1];
      expect(event.message, isNotNull);
      expect(event.message.sequenceId, 2322);
      expect(event.message.flags, [r'\Seen', r'$Chat']);

      expungedMessages.clear();
      fetchEvents.clear();
      vanishedMessages = null;
      mockInbox.noopChanges = [
        'VANISHED 1232:1236',
        '233 EXISTS',
        '33 RECENT',
        r'14 FETCH (FLAGS (\Seen \Deleted))',
        r'2322 FETCH (FLAGS (\Seen $Chat))',
      ];
      noopResponse = await client.noop();
      await Future.delayed(Duration(milliseconds: 50));
      expect(noopResponse.status, ResponseStatus.OK);
      expect(expungedMessages, [], reason: 'Expunged messages should fit');
      expect(vanishedMessages, isNotNull);
      expect(vanishedMessages.toList(), [1232, 1233, 1234, 1235, 1236]);
      expect(inbox.messagesExists, 233);
      expect(inbox.messagesRecent, 33);
      expect(fetchEvents.length, 2, reason: 'Expecting 2 fetch events');
      event = fetchEvents[0];
      expect(event.message, isNotNull);
      expect(event.message.sequenceId, 14);
      expect(event.message.flags, [r'\Seen', r'\Deleted']);
      event = fetchEvents[1];
      expect(event.message, isNotNull);
      expect(event.message.sequenceId, 2322);
      expect(event.message.flags, [r'\Seen', r'$Chat']);
    }
  });

  test('ImapClient check', () async {
    _log('');
    await Future.delayed(Duration(seconds: 1));
    var checkResponse = await client.check();
    expect(checkResponse.status, ResponseStatus.OK);

    if (mockServer != null) {
      await Future.delayed(Duration(milliseconds: 50));
      expungedMessages.clear();
      mockInbox.noopChanges = ['2232 EXPUNGE', '1234 EXPUNGE'];
      checkResponse = await client.check();
      await Future.delayed(Duration(milliseconds: 50));
      expect(checkResponse.status, ResponseStatus.OK);
      expect(expungedMessages, [2232, 1234],
          reason: 'Expunged messages should fit');
    }
  });

  test('ImapClient expunge', () async {
    _log('');
    await Future.delayed(Duration(seconds: 1));
    var expungeResponse = await client.expunge();
    expect(expungeResponse.status, ResponseStatus.OK);

    if (mockServer != null) {
      expungedMessages.clear();
      mockServer.expungeResponses = [
        '* 3 EXPUNGE\r\n',
        '* 3 EXPUNGE\r\n',
        '* 23 EXPUNGE\r\n',
        '* 26 EXPUNGE\r\n'
      ];
      expungeResponse = await client.expunge();
      await Future.delayed(Duration(milliseconds: 50));
      expect(expungeResponse.status, ResponseStatus.OK);
      expect(expungedMessages, [3, 3, 23, 26],
          reason: 'Expunged messages should fit');
    }
  });

  test('ImapClient uidExpunge', () async {
    if (mockServer != null) {
      _log('');
      await Future.delayed(Duration(milliseconds: 20));
      expungedMessages.clear();
      mockServer.expungeResponses = [
        '* 3 EXPUNGE\r\n',
        '* 3 EXPUNGE\r\n',
        '* 23 EXPUNGE\r\n',
        '* 26 EXPUNGE\r\n'
      ];
      var expungeResponse =
          await client.uidExpunge(MessageSequence.fromRange(273, 277));
      await Future.delayed(Duration(milliseconds: 50));
      expect(expungeResponse.status, ResponseStatus.OK);
      expect(expungedMessages, [3, 3, 23, 26],
          reason: 'Expunged messages should fit');
    }
  });

  test('ImapClient copy', () async {
    if (mockServer != null) {
      _log('');
      var copyResponse = await client.copy(MessageSequence.fromRange(1, 3),
          targetMailboxPath: 'TRASH');
      expect(copyResponse.status, ResponseStatus.OK);
    }
  });

  test('ImapClient uid copy', () async {
    if (mockServer != null) {
      _log('');
      var copyResponse = await client.uidCopy(
          MessageSequence.fromRange(1232, 1236),
          targetMailboxPath: 'TRASH');
      expect(copyResponse.status, ResponseStatus.OK);
    }
  });

  test('ImapClient move', () async {
    if (mockServer != null) {
      _log('');
      var moveResponse = await client.move(MessageSequence.fromRange(1, 3),
          targetMailboxPath: 'TRASH');
      expect(moveResponse.status, ResponseStatus.OK);
    }
  });

  test('ImapClient uid move', () async {
    if (mockServer != null) {
      _log('');
      var moveResponse = await client.uidMove(
          MessageSequence.fromRange(1232, 1236),
          targetMailboxPath: 'TRASH');
      expect(moveResponse.status, ResponseStatus.OK);
    }
  });

  test('ImapClient store', () async {
    _log('');
    if (mockServer != null) {
      mockServer.storeResponses = [
        r'* 1 FETCH (FLAGS (\Flagged \Seen))' '\r\n',
        r'* 2 FETCH (FLAGS (\Deleted \Seen))' '\r\n',
        r'* 3 FETCH (FLAGS (\Seen))' '\r\n'
      ];
    }
    var storeResponse = await client.store(
        MessageSequence.fromRange(1, 3), [r'\Seen'],
        unchangedSinceModSequence: inbox.highestModSequence);
    expect(storeResponse.status, ResponseStatus.OK);
    if (mockServer != null) {
      expect(storeResponse.result.changedMessages, isNotNull);
      expect(storeResponse.result.changedMessages, isNotEmpty);
      expect(storeResponse.result.changedMessages.length, 3);
      expect(storeResponse.result.changedMessages[0].sequenceId, 1);
      expect(storeResponse.result.changedMessages[0].flags,
          [r'\Flagged', r'\Seen']);
      expect(storeResponse.result.changedMessages[1].sequenceId, 2);
      expect(storeResponse.result.changedMessages[1].flags,
          [r'\Deleted', r'\Seen']);
      expect(storeResponse.result.changedMessages[2].sequenceId, 3);
      expect(storeResponse.result.changedMessages[2].flags, [r'\Seen']);
    }
  });

  test('ImapClient store with modified sequence', () async {
    _log('');
    if (mockServer != null) {
      mockServer.storeResponses = [
        r'* 5 FETCH (MODSEQ (320162350))' '\r\n',
      ];
      mockServer.overrideResponse =
          'OK [MODIFIED 7,9] Conditional STORE failed';
      var storeResponse = await client.store(
          MessageSequence.fromRange(4, 9), [r'\Seen'],
          unchangedSinceModSequence: inbox.highestModSequence);
      mockServer.overrideResponse = null;
      expect(storeResponse.status, ResponseStatus.OK);
      expect(storeResponse.result.changedMessages, isNotNull);
      expect(storeResponse.result.changedMessages, isNotEmpty);
      expect(storeResponse.result.changedMessages.length, 1);
      expect(storeResponse.result.changedMessages[0].sequenceId, 5);
      expect(storeResponse.result.modifiedMessageIds.length, 2);
      expect(storeResponse.result.modifiedMessageIds, [7, 9]);
    }
  });

  test('ImapClient uid store', () async {
    _log('');
    if (mockServer != null) {
      mockServer.storeResponses = [
        r'* 123 FETCH (UID 12342 FLAGS (\Flagged \Seen))' '\r\n',
        r'* 124 FETCH (UID 12343 FLAGS (\Deleted \Seen))' '\r\n',
        r'* 125 FETCH (UID 12344 FLAGS (\Seen))' '\r\n'
      ];
    }
    var storeResponse = await client
        .uidStore(MessageSequence.fromRange(12342, 12344), [r'\Seen']);
    expect(storeResponse.status, ResponseStatus.OK);
    if (mockServer != null) {
      expect(storeResponse.result.changedMessages, isNotNull);
      expect(storeResponse.result.changedMessages, isNotEmpty);
      expect(storeResponse.result.changedMessages.length, 3);
      expect(storeResponse.result.changedMessages[0].uid, 12342);
      expect(storeResponse.result.changedMessages[0].flags,
          [r'\Flagged', r'\Seen']);
      expect(storeResponse.result.changedMessages[1].uid, 12343);
      expect(storeResponse.result.changedMessages[1].flags,
          [r'\Deleted', r'\Seen']);
      expect(storeResponse.result.changedMessages[2].uid, 12344);
      expect(storeResponse.result.changedMessages[2].flags, [r'\Seen']);
    }
  });

  test('ImapClient markSeen', () async {
    _log('');
    if (mockServer != null) {
      mockServer.storeResponses = [
        r'* 1 FETCH (FLAGS (\Flagged \Seen))' '\r\n',
        r'* 2 FETCH (FLAGS (\Deleted \Seen))' '\r\n',
        r'* 3 FETCH (FLAGS (\Seen))' '\r\n'
      ];
    }
    var storeResponse = await client.markSeen(MessageSequence.fromRange(1, 3));
    expect(storeResponse.status, ResponseStatus.OK);
    if (mockServer != null) {
      expect(storeResponse.result.changedMessages, isNotNull);
      expect(storeResponse.result.changedMessages, isNotEmpty);
      expect(storeResponse.result.changedMessages.length, 3);
      expect(storeResponse.result.changedMessages[0].sequenceId, 1);
      expect(storeResponse.result.changedMessages[0].flags,
          [r'\Flagged', r'\Seen']);
      expect(storeResponse.result.changedMessages[1].sequenceId, 2);
      expect(storeResponse.result.changedMessages[1].flags,
          [r'\Deleted', r'\Seen']);
      expect(storeResponse.result.changedMessages[2].sequenceId, 3);
      expect(storeResponse.result.changedMessages[2].flags, [r'\Seen']);
    }
  });

  test('ImapClient markFlagged', () async {
    _log('');
    if (mockServer != null) {
      mockServer.storeResponses = [
        r'* 1 FETCH (FLAGS (\Flagged \Seen))' '\r\n',
        r'* 2 FETCH (FLAGS (\Deleted \Flagged \Seen))' '\r\n',
        r'* 3 FETCH (FLAGS (\Seen \Flagged))' '\r\n'
      ];
    }
    var storeResponse =
        await client.markFlagged(MessageSequence.fromRange(1, 3));
    expect(storeResponse.status, ResponseStatus.OK);
    if (mockServer != null) {
      expect(storeResponse.result.changedMessages, isNotNull);
      expect(storeResponse.result.changedMessages, isNotEmpty);
      expect(storeResponse.result.changedMessages.length, 3);
      expect(storeResponse.result.changedMessages[0].sequenceId, 1);
      expect(storeResponse.result.changedMessages[0].flags,
          [r'\Flagged', r'\Seen']);
      expect(storeResponse.result.changedMessages[1].sequenceId, 2);
      expect(storeResponse.result.changedMessages[1].flags,
          [r'\Deleted', r'\Flagged', r'\Seen']);
      expect(storeResponse.result.changedMessages[2].sequenceId, 3);
      expect(storeResponse.result.changedMessages[2].flags,
          [r'\Seen', r'\Flagged']);
    }
  });

  test('ImapClient enable', () async {
    _log('');
    if (mockServer != null) {
      mockServer.enableResponses = ['* ENABLED CONDSTORE QRESYNC\r\n'];
      var enableResponse = await client.enable(['QRESYNC', 'CONDSTORE']);
      expect(enableResponse.status, ResponseStatus.OK);
      var enabledCaps = enableResponse.result;
      expect(enabledCaps, isNotEmpty);
      expect(enabledCaps.length, 2);
      expect(enabledCaps[0].name, 'CONDSTORE');
      expect(enabledCaps[1].name, 'QRESYNC');
    }
  });

  test('ImapClient getmetadata 1', () async {
    _log('');
    if (mockServer != null) {
      mockServer.getMetaDataResponses = [
        '* METADATA "INBOX" (/private/comment "My own comment")\r\n'
      ];
    }
    var metaDataResponse = await client.getMetaData('/private/comment');
    expect(metaDataResponse.status, ResponseStatus.OK);

    if (mockServer != null) {
      var metaData = metaDataResponse.result;
      expect(metaData, isNotNull);
      expect(metaData, isNotEmpty);
      expect(metaData[0].entry, '/private/comment');
      expect(metaData[0].mailboxName, 'INBOX');
      expect(metaData[0].valueText, 'My own comment');
    }
  });

  test('ImapClient getmetadata 2', () async {
    _log('');
    if (mockServer != null) {
      mockServer.getMetaDataResponses = [
        '* METADATA "" (/private/vendor/vendor.dovecot/webpush/vapid {136}\r\n',
        '-----BEGIN PUBLIC KEY-----\r\n'
            'MDkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDIgACYHfTQ0biATut1VhK/AW2KmZespz+\r\n'
            'DEQ1yH3nvbayCuY=\r\n'
            '-----END PUBLIC KEY-----)\r\n'
      ];
    }
    var metaDataResponse = await client.getMetaData('/private/comment');
    expect(metaDataResponse.status, ResponseStatus.OK);

    if (mockServer != null) {
      var metaData = metaDataResponse.result;
      expect(metaData, isNotNull);
      expect(metaData, isNotEmpty);
      expect(metaData[0].entry, '/private/vendor/vendor.dovecot/webpush/vapid');
      expect(metaData[0].mailboxName, '');
      expect(
          metaData[0].valueText,
          '-----BEGIN PUBLIC KEY-----\r\n'
          'MDkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDIgACYHfTQ0biATut1VhK/AW2KmZespz+\r\n'
          'DEQ1yH3nvbayCuY=\r\n'
          '-----END PUBLIC KEY-----');
    }
  });

  test('ImapClient getmetadata with several entries', () async {
    _log('');
    if (mockServer != null) {
      mockServer.getMetaDataResponses = [
        '* METADATA "" (/private/vendor/vendor.dovecot/coi/config/enabled {3}\r\n',
        'yes',
        ' /private/vendor/vendor.dovecot/coi/config/mailbox-root {3}\r\n',
        'COI',
        ' /private/vendor/vendor.dovecot/coi/config/message-filter {6}\r\n',
        'active',
        ')\r\n'
      ];
    }
    var metaDataResponse = await client.getMetaData('/private/comment');
    expect(metaDataResponse.status, ResponseStatus.OK);

    if (mockServer != null) {
      var metaData = metaDataResponse.result;
      expect(metaData, isNotNull);
      expect(metaData, isNotEmpty);
      expect(metaData.length, 3);
      expect(metaData[0].entry,
          '/private/vendor/vendor.dovecot/coi/config/enabled');
      expect(metaData[0].mailboxName, '');
      expect(metaData[0].valueText, 'yes');
      expect(metaData[1].entry,
          '/private/vendor/vendor.dovecot/coi/config/mailbox-root');
      expect(metaData[1].mailboxName, '');
      expect(metaData[1].valueText, 'COI');
      expect(metaData[2].entry,
          '/private/vendor/vendor.dovecot/coi/config/message-filter');
      expect(metaData[2].mailboxName, '');
      expect(metaData[2].valueText, 'active');
    }
  });

  test('ImapClient setmetadata', () async {
    _log('');
    if (mockServer != null) {
      mockServer.setMetaDataResponses = [];
    }
    var entry = MetaDataEntry()..entry = '/private/comment';
    var metaDataResponse = await client.setMetaData(entry);
    if (mockServer != null) {
      expect(metaDataResponse.status, ResponseStatus.OK);
    }
  });

  test('ImapClient append', () async {
    _log('');
    var message = MessageBuilder.buildSimpleTextMessage(
        MailAddress('User Name', 'user.name@domain.com'),
        [MailAddress('Rita Recpient', 'rr@domain.com')],
        'Hey,\r\nhow are things today?\r\n\r\nAll the best!',
        subject: 'Appended draft message');
    var appendResponse =
        await client.appendMessage(message, flags: [r'\Draft', r'\Seen']);
    if (mockServer != null) {
      expect(appendResponse.status, ResponseStatus.OK);
      expect(appendResponse.result, isNotNull);
      expect(appendResponse.result.responseCode, isNotNull);
      expect(
          appendResponse.result.responseCode.substring(0, 'APPENDUID'.length),
          'APPENDUID');
      // OK [APPENDUID 1466002016 176] is hardcoded
      var uidResponseCode = appendResponse.result.responseCodeAppendUid;
      expect(uidResponseCode, isNotNull);
      expect(uidResponseCode.uidValidity, 1466002016);
      expect(uidResponseCode.uid, 176);
    }
  });

  test('ImapClient idle', () async {
    _log('');
    expungedMessages.clear();
    await client.idleStart();

    if (mockServer != null) {
      mockInbox.messagesExists += 4;
      mockServer.fire(Duration(milliseconds: 100),
          '* 2 EXPUNGE\r\n* 17 EXPUNGE\r\n* ${mockInbox.messagesExists} EXISTS\r\n');
    }
    await Future.delayed(Duration(milliseconds: 200));
    await client.idleDone();
    if (mockServer != null) {
      expect(expungedMessages.length, 2);
      expect(expungedMessages[0], 2);
      expect(expungedMessages[1], 17);
      expect(inbox.messagesExists, mockInbox.messagesExists);
    }

    //expect(doneResponse.status, ResponseStatus.OK);
  });

  test('ImapClient close', () async {
    _log('');
    var closeResponse = await client.closeMailbox();
    expect(closeResponse.status, ResponseStatus.OK);
  });

  test('ImapClient logout', () async {
    _log('');
    var logoutResponse = await client.logout();
    expect(logoutResponse.status, ResponseStatus.OK);

    //await Future.delayed(Duration(seconds: 1));
    await client.closeConnection();
    _log('done connecting');
    client = null;
  });
}

void _log(String text) {
  if (_isLogEnabled) {
    print(text);
  }
}

String _toString(List elements, [String separator = ' ']) {
  var buffer = StringBuffer();
  var addSeparator = false;
  for (var element in elements) {
    if (addSeparator) {
      buffer.write(separator);
    }
    buffer.write(element);
    addSeparator = true;
  }
  return buffer.toString();
}
