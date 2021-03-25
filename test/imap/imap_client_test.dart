import 'dart:async';

import 'package:enough_mail/imap/message_sequence.dart';
import 'package:enough_mail/src/util/client_base.dart';
import 'package:test/test.dart';
import 'dart:io' show Platform;
import 'package:event_bus/event_bus.dart';
import 'package:enough_mail/enough_mail.dart';
import 'mock_imap_server.dart';
import '../mock_socket.dart';

late ImapClient client;
late MockImapServer mockServer;
List<ImapFetchEvent> fetchEvents = <ImapFetchEvent>[];
List<int?> expungedMessages = <int?>[];
MessageSequence? vanishedMessages;

void main() {
  setUp(() async {
    final envVars = Platform.environment;
    final isLogEnabled = (envVars['IMAP_LOG'] == 'true');
    client = ImapClient(bus: EventBus(sync: true), isLogEnabled: isLogEnabled);

    client.eventBus
        .on<ImapExpungeEvent>()
        .listen((e) => expungedMessages.add(e.messageSequenceId));
    client.eventBus
        .on<ImapVanishedEvent>()
        .listen((e) => vanishedMessages = e.vanishedMessages);
    client.eventBus.on<ImapFetchEvent>().listen((e) => fetchEvents.add(e));

    final connection = MockConnection();
    client.connect(connection.socketClient,
        connectionInformation: ConnectionInfo('imaptest.enough.de', 993, true));
    mockServer = MockImapServer.connect(connection.socketServer);
    connection.socketServer.write(
        '* OK [CAPABILITY IMAP4rev1 CHILDREN ENABLE ID IDLE LIST-EXTENDED LIST-STATUS LITERAL- MOVE NAMESPACE QUOTA SASL-IR SORT SPECIAL-USE THREAD=ORDEREDSUBJECT UIDPLUS UNSELECT WITHIN AUTH=LOGIN AUTH=PLAIN] IMAP server ready H mieue154 15.6 IMAP-1My4Ij-1k2Oa32EiF-00yVN8\r\n');
    // allow processing of server greeting:
    await Future.delayed(const Duration(milliseconds: 15));
  });

  test('ImapClient login', () async {
    mockServer.response =
        '* CAPABILITY IMAP4rev1 CHILDREN ENABLE ID IDLE LIST-EXTENDED LIST-STATUS LITERAL- MOVE NAMESPACE QUOTA SASL-IR SORT SPECIAL-USE THREAD=ORDEREDSUBJECT UIDPLUS UNSELECT WITHIN AUTH=LOGIN AUTH=PLAIN\r\n'
        '<tag> OK LOGIN completed';
    final capResponse = await client.login('testuser', 'testpassword');
    expect(capResponse, isNotNull,
        reason: 'login response does not contain a result');
    expect(capResponse.isNotEmpty, true,
        reason: 'login response does not contain a single capability');
    expect(capResponse.length, 20);
    expect(capResponse[0].name, 'IMAP4rev1');
    expect(capResponse[1].name, 'CHILDREN');
    expect(capResponse[2].name, 'ENABLE');
  });

  test('ImapClient authenticateWithOAuth2', () async {
    mockServer.response = '<tag> OK AUTH completed';
    final authResponse =
        await client.authenticateWithOAuth2('testuser', 'ABC123456789abc');
    expect(authResponse, isNotNull,
        reason: 'auth response does not contain a result');
  });

  test('ImapClient authenticateWithOAuthBearer', () async {
    mockServer.response = '<tag> OK AUTH completed';
    final authResponse =
        await client.authenticateWithOAuthBearer('testuser', 'ABC123456789abc');
    expect(authResponse, isNotNull,
        reason: 'auth response does not contain a result');
  });

  test('ImapClient capability', () async {
    mockServer.response =
        '* CAPABILITY IMAP4rev1 CHILDREN ENABLE ID IDLE LIST-EXTENDED LIST-STATUS LITERAL- MOVE NAMESPACE QUOTA SASL-IR SORT SPECIAL-USE THREAD=ORDEREDSUBJECT UIDPLUS UNSELECT WITHIN AUTH=LOGIN AUTH=PLAIN\r\n'
        '<tag> OK CAPABILITY completed';
    final capabilityResponse = await client.capability();
    expect(capabilityResponse, isNotNull,
        reason: 'capability response does not contain a result');
    expect(capabilityResponse.isNotEmpty, true,
        reason: 'capability response does not contain a single capability');
    expect(capabilityResponse.length, 20);
    expect(capabilityResponse[0].name, 'IMAP4rev1');
    expect(capabilityResponse[1].name, 'CHILDREN');
    expect(capabilityResponse[2].name, 'ENABLE');
  });

  test('ImapClient listMailboxes with escaped Mailbox-Flags', () async {
    mockServer.response = '* LIST (\\HasChildren \\Marked) "/" INBOX\r\n'
        '* LIST (\\HasChildren \\Noselect) "/" Public\r\n'
        '* LIST (\\HasNoChildren \\Trash) "/" Trash\r\n'
        '* LIST (\\HasChildren \\Noselect) "/" Shared\r\n'
        '<tag> OK List completed (0.000 + 0.000 secs).';
    final listResponse = await client.listMailboxes();
    expect(listResponse, isNotNull,
        reason: 'list response does not contain a result');
    expect(listResponse.isNotEmpty, true,
        reason: 'list response does not contain a single mailbox');
    expect(listResponse.length, 4, reason: 'Set up 3 mailboxes in root');
    var box = listResponse[0];
    expect('INBOX', box.name);
    expect(box.hasChildren, isTrue);
    expect(box.isSelected, isFalse);
    expect(box.isMarked, isTrue);
    expect(box.isUnselectable, isFalse);
    box = listResponse[1];
    expect('Public', box.name);
    expect(box.hasChildren, isTrue);
    expect(box.isSelected, isFalse);
    expect(box.isUnselectable, isTrue);
    box = listResponse[2];
    expect('Trash', box.name);
    expect(box.hasChildren, isFalse);
    expect(box.isSelected, isFalse);
    expect(box.isUnselectable, isFalse);
    box = listResponse[3];
    expect('Shared', box.name);
    expect(box.hasChildren, isTrue);
    expect(box.isSelected, isFalse);
    expect(box.isUnselectable, isTrue);
    expect(client.serverInfo.pathSeparator, '/',
        reason: 'different path separator than in server');
  });

  test('ImapClient LSUB', () async {
    mockServer.response = '* LSUB (\\HasChildren \\Marked) "/" INBOX\r\n'
        '* LSUB (\\HasChildren \\Noselect) "/" Public\r\n'
        '<tag> OK LSUB completed (0.000 + 0.000 secs).';
    final listResponse = await client.listSubscribedMailboxes();
    expect(listResponse, isNotNull,
        reason: 'lsub response does not contain a result');
    expect(listResponse.length, 2,
        reason: 'lsub response does not contain 2 mailboxes');
    expect(client.serverInfo.pathSeparator, '/',
        reason: 'different path separator than set up');
    var box = listResponse[0];
    expect('INBOX', box.name);
    expect(true, box.hasChildren);
    expect(false, box.isSelected);
    expect(false, box.isUnselectable);
    box = listResponse[1];
    expect('Public', box.name);
    expect(true, box.hasChildren);
    expect(false, box.isSelected);
    expect(true, box.isUnselectable);
  });

  test('ImapClient LIST and SELECT', () async {
    mockServer.response =
        '* LIST (\\HasNoChildren \\UnMarked \\Archive) "/" INBOX/Archive\r\n'
        '* LIST (\\HasNoChildren \\UnMarked \\Sent) "/" INBOX/Sent\r\n'
        '* LIST (\\HasNoChildren \\Marked \\Trash) "/" INBOX/Trash\r\n'
        '* LIST (\\HasNoChildren \\Marked \\Junk) "/" INBOX/Spam\r\n'
        '* LIST (\\HasNoChildren \\UnMarked \\Drafts) "/" INBOX/Drafts\r\n'
        '<tag> OK List completed (0.000 + 0.000 secs).';
    final listResponse = await client.listMailboxes(path: '"INBOX"');
    expect(listResponse, isNotNull,
        reason: 'list response does not conatin a result');
    expect(client.serverInfo.pathSeparator, '/',
        reason: 'different path separator than set up');
    expect(listResponse.length, 5, reason: 'Set up 6 mailboxes');
    var box = listResponse[0];
    expect(box.name, 'Archive');
    expect(box.hasChildren, isFalse);
    expect(box.isSelected, isFalse);
    expect(box.isUnselectable, isFalse);
    expect(box.isArchive, isTrue);
    box = listResponse[1];
    expect(box.name, 'Sent');
    expect(box.hasChildren, isFalse);
    expect(box.isSelected, isFalse);
    expect(box.isUnselectable, isFalse);
    expect(box.isSent, isTrue);
    box = listResponse[2];
    expect(box.name, 'Trash');
    expect(box.hasChildren, isFalse);
    expect(box.isSelected, isFalse);
    expect(box.isUnselectable, isFalse);
    expect(box.isTrash, isTrue);

    final archive = listResponse[0];

    mockServer.response = '* 63510 EXISTS\r\n'
        '* 23 RECENT\r\n'
        '* FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft \$Forwarded \$Unsubscribed)\r\n'
        '* OK [PERMANENTFLAGS (\\Answered \\Flagged \\Draft \\Deleted \\Seen \$Forwarded \$Unsubscribed \\*)] Unlimited\r\n'
        '* OK [UNSEEN 30130] Message 30130 is first unseen\r\n'
        '* OK [UIDNEXT 351118] Predicted next UID\r\n'
        '* OK [UIDVALIDITY 1245213765] UIDs valid\r\n'
        '<tag> OK [READ-WRITE] SELECT completed';
    final selectResponse = await client.selectMailbox(archive);
    expect(selectResponse, isNotNull,
        reason: 'select response does not contain a result ');
    expect(selectResponse.isReadWrite, true,
        reason: 'SELECT should open in READ-WRITE ');
    expect(selectResponse.messagesExists, 63510,
        reason: 'expecting at least 63510 mails in SELECT response');
    expect(archive.messagesRecent, 23);
    expect(archive.firstUnseenMessageSequenceId, 30130);
    expect(archive.uidValidity, 1245213765);
    expect(archive.uidNext, 351118);
    expect(archive.highestModSequence, null);
    expect(archive.messageFlags, isNotNull, reason: 'message flags expected');
    expect(archive.messageFlags, [
      '\\Answered',
      '\\Flagged',
      '\\Deleted',
      '\\Seen',
      '\\Draft',
      '\$Forwarded',
      '\$Unsubscribed'
    ]);
    expect(
        archive.permanentMessageFlags,
        [
          '\\Answered',
          '\\Flagged',
          '\\Draft',
          '\\Deleted',
          '\\Seen',
          '\$Forwarded',
          '\$Unsubscribed',
          '\\*'
        ],
        reason: 'permanent message flags expected');
  });

  test('ImapClient search', () async {
    mockServer.response = '* SEARCH 3423 17 3\r\n'
        '<tag> OK SEARCH completed';
    final searchResponse = await client.searchMessages('UNSEEN');
    expect(searchResponse.matchingSequence, isNotNull);
    expect(searchResponse.matchingSequence!.toList(), [3, 17, 3423]);
  });

  test('ImapClient uid search', () async {
    mockServer.response = '* SEARCH 3423 17 3\r\n'
        '<tag> OK UID SEARCH completed';
    final searchResult = await client.uidSearchMessages('UNSEEN');
    expect(searchResult.matchingSequence, isNotNull);
    expect(searchResult.matchingSequence!.isNotEmpty(), true);
    expect(searchResult.matchingSequence!.toList(), [3, 17, 3423]);
  });

  test('ImapClient sort', () async {
    final testSequence = [
      184,
      182,
      183,
      181,
      180,
      179,
      178,
      177,
      176,
      175,
      174,
      173,
      172,
      171,
      170,
      169,
      168,
      167,
      166,
      164,
      163
    ];
    mockServer.response = '* SORT ${testSequence.join(' ')}\r\n'
        '<tag> OK SORT Completed';
    final sortResponse = await client.sortMessages('ARRIVAL');
    expect(sortResponse.matchingSequence, isNotNull);
    expect(sortResponse.matchingSequence!.toList(), testSequence);
  });

  test('ImapClient uid sort', () async {
    final testSequence = [
      184,
      182,
      183,
      181,
      180,
      179,
      178,
      177,
      176,
      175,
      174,
      173,
      172,
      171,
      170,
      169,
      168,
      167,
      166,
      164,
      163
    ];
    mockServer.response = '* SORT ${testSequence.join(' ')}\r\n'
        '<tag> OK UID SORT Completed';
    final sortResponse = await client.uidSortMessages('ARRIVAL');
    expect(sortResponse.matchingSequence, isNotNull);
    expect(sortResponse.matchingSequence!.toList(), testSequence);
  });

  test('ImapClient extended search', () async {
    final testSequence = [2, 17, 3423];
    mockServer.response =
        '* ESEARCH (TAG "<tag>") MIN 2 COUNT 3 ALL ${testSequence.join(',')}\r\n'
        '<tag> OK SEARCH Completed';

    final searchResponse = await client.searchMessages('UNSEEN',
        [ReturnOption.count(), ReturnOption.min(), ReturnOption.all()]);
    expect(searchResponse.isExtended, isTrue);
    expect(searchResponse.count, 3);
    expect(searchResponse.min, 2);

    expect(searchResponse.matchingSequence, isNotNull);
    expect(searchResponse.matchingSequence!.toList(), testSequence);
  });

  test('ImapClient extended uid search', () async {
    final testSequence = [2, 17, 3423];
    mockServer.response =
        '* ESEARCH (TAG "<tag>") MIN 2 COUNT 3 UID ALL ${testSequence.join(',')}\r\n'
        '<tag> OK UID SEARCH Completed';

    final searchResponse = await client.uidSearchMessages('UNSEEN',
        [ReturnOption.count(), ReturnOption.min(), ReturnOption.all()]);
    expect(searchResponse.isExtended, isTrue);
    expect(searchResponse.count, 3);
    expect(searchResponse.min, 2);

    expect(searchResponse.matchingSequence, isNotNull);
    expect(searchResponse.matchingSequence!.toList(), testSequence);
  });

  test('ImapClient extended sort', () async {
    final testSequence = [
      184,
      182,
      183,
      181,
      180,
      179,
      178,
      177,
      176,
      175,
      174,
      173,
      172,
      171,
      170,
      169,
      168,
      167,
      166,
      164,
      163
    ];
    mockServer.response =
        '* ESEARCH (TAG "<tag>") COUNT 21 ALL ${testSequence.join(',')}\r\n'
        '<tag> OK UID SORT Completed';
    final sortResponse = await client.sortMessages(
        'ARRIVAL', 'ALL', 'UTF-8', [ReturnOption.count(), ReturnOption.all()]);
    expect(sortResponse.matchingSequence, isNotNull);
    expect(sortResponse.matchingSequence!.toList(), testSequence);
    expect(sortResponse.count, 21);
  });

  test('ImapClient extended uid sort', () async {
    final testSequence = [
      184,
      182,
      183,
      181,
      180,
      179,
      178,
      177,
      176,
      175,
      174,
      173,
      172,
      171,
      170,
      169,
      168,
      167,
      166,
      164,
      163
    ];
    mockServer.response =
        '* ESEARCH (TAG "<tag>") COUNT 21 UID ALL ${testSequence.join(',')}\r\n'
        '<tag> OK UID SORT Completed';
    final sortResponse = await client.uidSortMessages(
        'ARRIVAL', 'ALL', 'UTF-8', [ReturnOption.count(), ReturnOption.all()]);
    expect(sortResponse.matchingSequence, isNotNull);
    expect(sortResponse.matchingSequence!.toList(), testSequence);
    expect(sortResponse.count, 21);
  });

  test('ImapClient fetch FULL', () async {
    mockServer.response =
        '* 123456  FETCH (MODSEQ (12323) FLAGS () INTERNALDATE "25-Oct-2019 16:35:31 +0200" '
        'RFC822.SIZE 15320 ENVELOPE ("Fri, 25 Oct 2019 16:35:28 +0200 (CEST)" {61}\r\n'
        'New appointment: SoW (x2) for rebranding of App & Mobile Apps'
        '(("=?UTF-8?Q?Sch=C3=B6n=2C_Rob?=" NIL "rob.schoen" "domain.com")) (("=?UTF-8?Q?Sch=C3=B6n=2C_'
        'Rob?=" NIL "rob.schoen" "domain.com")) (("=?UTF-8?Q?Sch=C3=B6n=2C_Rob?=" NIL "rob.schoen" '
        '"domain.com")) (("Alice Dev" NIL "alice.dev" "domain.com")) NIL NIL "<Appointment.59b0d625-afaf-4fc6'
        '-b845-4b0fce126730@domain.com>" "<130499090.797.1572014128349@product-gw2.domain.com>") BODY (("text" "plain" '
        '("charset" "UTF-8") NIL NIL "quoted-printable" 1289 53)("text" "html" ("charset" "UTF-8") NIL NIL "quoted-printable" '
        '7496 302) "alternative"))\r\n'
        '* 123455 FETCH (MODSEQ (12328) FLAGS (new seen) INTERNALDATE "25-Oct-2019 17:03:12 +0200" '
        'RFC822.SIZE 20630 ENVELOPE ("Fri, 25 Oct 2019 11:02:30 -0400 (EDT)" "New appointment: Discussion and '
        'Q&A" (("Tester, Theresa" NIL "t.tester" "domain.com")) (("Tester, Theresa" NIL "t.tester" "domain.com"))'
        ' (("Tester, Theresa" NIL "t.tester" "domain.com")) (("Alice Dev" NIL "alice.dev" "domain.com"))'
        ' NIL NIL "<Appointment.963a03aa-4a81-49bf-b3a2-77e39df30ee9@domain.com>" "<1814674343.1008.1572015750561@appsuite-g'
        'w2.domain.com>") BODY (("TEXT" "PLAIN" ("CHARSET" "US-ASCII") NIL NIL "7BIT" 1152 '
        '23)("TEXT" "PLAIN" ("CHARSET" "US-ASCII" "NAME" "cc.diff")'
        '"<960723163407.20117h@cac.washington.edu>" "Compiler diff" '
        '"BASE64" 4554 73) "MIXED"))\r\n'
        '<tag> OK FETCH completed';
    final fetchResponse = await client.fetchMessages(
        MessageSequence.fromRange(123455, 123456), 'FULL',
        changedSinceModSequence: 0);
    expect(fetchResponse, isNotNull, reason: 'fetch result expected');
    expect(fetchResponse.messages.length, 2);
    var message = fetchResponse.messages[0];
    expect(message.sequenceId, 123456);
    expect(message.modSequence, 12323);
    expect(message.flags, isNotNull);
    expect(message.flags!.length, 0);
    expect(message.internalDate, '25-Oct-2019 16:35:31 +0200');
    expect(message.size, 15320);
    expect(message.envelope, isNotNull);
    expect(message.envelope!.date,
        DateCodec.decodeDate('Fri, 25 Oct 2019 16:35:28 +0200 (CEST)'));
    expect(message.decodeDate(),
        DateCodec.decodeDate('Fri, 25 Oct 2019 16:35:28 +0200 (CEST)'));
    expect(message.envelope!.subject,
        'New appointment: SoW (x2) for rebranding of App & Mobile Apps');
    expect(message.decodeSubject(),
        'New appointment: SoW (x2) for rebranding of App & Mobile Apps');
    expect(message.envelope!.inReplyTo,
        '<Appointment.59b0d625-afaf-4fc6-b845-4b0fce126730@domain.com>');
    expect(message.getHeaderValue('in-reply-to'),
        '<Appointment.59b0d625-afaf-4fc6-b845-4b0fce126730@domain.com>');
    expect(message.envelope!.messageId,
        '<130499090.797.1572014128349@product-gw2.domain.com>');
    expect(message.getHeaderValue('message-id'),
        '<130499090.797.1572014128349@product-gw2.domain.com>');
    expect(message.cc, isNotNull);
    expect(message.cc!.isEmpty, isTrue);
    expect(message.bcc, isNotNull);
    expect(message.bcc!.isEmpty, isTrue);
    expect(message.envelope!.from, isNotNull);
    expect(message.envelope!.from!.length, 1);
    expect(message.envelope!.from!.first.personalName, 'Schön, Rob');
    expect(message.envelope!.from!.first.sourceRoute, null);
    expect(message.envelope!.from!.first.mailboxName, 'rob.schoen');
    expect(message.envelope!.from!.first.hostName, 'domain.com');
    expect(message.from, isNotNull);
    expect(message.from!.length, 1);
    expect(message.from!.first.personalName, 'Schön, Rob');
    expect(message.from!.first.sourceRoute, null);
    expect(message.from!.first.mailboxName, 'rob.schoen');
    expect(message.from!.first.hostName, 'domain.com');
    expect(message.sender, isNotNull);
    expect(message.sender!.personalName, 'Schön, Rob');
    expect(message.sender!.sourceRoute, null);
    expect(message.sender!.mailboxName, 'rob.schoen');
    expect(message.sender!.hostName, 'domain.com');
    expect(message.replyTo, isNotNull);
    expect(message.replyTo!.first.personalName, 'Schön, Rob');
    expect(message.replyTo!.first.sourceRoute, null);
    expect(message.replyTo!.first.mailboxName, 'rob.schoen');
    expect(message.replyTo!.first.hostName, 'domain.com');
    expect(message.to, isNotNull);
    expect(message.to!.first.personalName, 'Alice Dev');
    expect(message.to!.first.sourceRoute, null);
    expect(message.to!.first.mailboxName, 'alice.dev');
    expect(message.to!.first.hostName, 'domain.com');
    expect(message.body, isNotNull);
    expect(message.body!.contentType, isNotNull);
    expect(message.body!.contentType!.mediaType.sub,
        MediaSubtype.multipartAlternative);
    expect(message.body!.parts, isNotNull);
    expect(message.body!.parts!.length, 2);
    expect(message.body!.parts![0].contentType, isNotNull);
    expect(message.body!.parts![0].contentType!.mediaType.sub,
        MediaSubtype.textPlain);
    expect(message.body!.parts![0].description, null);
    expect(message.body!.parts![0].cid, null);
    expect(message.body!.parts![0].encoding, 'quoted-printable');
    expect(message.body!.parts![0].size, 1289);
    expect(message.body!.parts![0].numberOfLines, 53);
    expect(message.body!.parts![0].contentType!.charset, 'utf-8');
    expect(message.body!.parts![1].contentType!.mediaType.sub,
        MediaSubtype.textHtml);
    expect(message.body!.parts![1].description, null);
    expect(message.body!.parts![1].cid, null);
    expect(message.body!.parts![1].encoding, 'quoted-printable');
    expect(message.body!.parts![1].size, 7496);
    expect(message.body!.parts![1].numberOfLines, 302);
    expect(message.body!.parts![1].contentType!.charset, 'utf-8');

    message = fetchResponse.messages[1];
    expect(message.sequenceId, 123455);
    expect(message.modSequence, 12328);
    expect(message.flags, isNotNull);
    expect(message.flags!.length, 2);
    expect(message.flags![0], 'new');
    expect(message.flags![1], 'seen');
    expect(message.internalDate, '25-Oct-2019 17:03:12 +0200');
    expect(message.size, 20630);
    expect(message.envelope!.date,
        DateCodec.decodeDate('Fri, 25 Oct 2019 11:02:30 -0400 (EDT)'));
    expect(message.envelope!.subject, 'New appointment: Discussion and Q&A');
    expect(message.envelope!.inReplyTo,
        '<Appointment.963a03aa-4a81-49bf-b3a2-77e39df30ee9@domain.com>');
    expect(message.envelope!.messageId,
        '<1814674343.1008.1572015750561@appsuite-gw2.domain.com>');
    expect(message.cc, isNotNull);
    expect(message.cc!.isEmpty, isTrue);
    expect(message.bcc, isNotNull);
    expect(message.bcc!.isEmpty, isTrue);
    expect(message.from, isNotNull);
    expect(message.from!.length, 1);
    expect(message.from!.first.personalName, 'Tester, Theresa');
    expect(message.from!.first.sourceRoute, null);
    expect(message.from!.first.mailboxName, 't.tester');
    expect(message.from!.first.hostName, 'domain.com');
    expect(message.sender, isNotNull);
    expect(message.sender!.personalName, 'Tester, Theresa');
    expect(message.sender!.sourceRoute, null);
    expect(message.sender!.mailboxName, 't.tester');
    expect(message.sender!.hostName, 'domain.com');
    expect(message.replyTo, isNotNull);
    expect(message.replyTo!.first.personalName, 'Tester, Theresa');
    expect(message.replyTo!.first.sourceRoute, null);
    expect(message.replyTo!.first.mailboxName, 't.tester');
    expect(message.replyTo!.first.hostName, 'domain.com');
    expect(message.to, isNotNull);
    expect(message.to!.first.personalName, 'Alice Dev');
    expect(message.to!.first.sourceRoute, null);
    expect(message.to!.first.mailboxName, 'alice.dev');
    expect(message.to!.first.hostName, 'domain.com');
    expect(message.body, isNotNull);
    expect(
        message.body!.contentType!.mediaType.sub, MediaSubtype.multipartMixed);
    expect(message.body!.parts, isNotNull);
    expect(message.body!.parts!.length, 2);
    expect(message.body!.parts![0].contentType!.mediaType.sub,
        MediaSubtype.textPlain);
    expect(message.body!.parts![0].description, null);
    expect(message.body!.parts![0].cid, null);
    expect(message.body!.parts![0].encoding, '7bit');
    expect(message.body!.parts![0].size, 1152);
    expect(message.body!.parts![0].numberOfLines, 23);
    expect(message.body!.parts![0].contentType!.charset, 'us-ascii');
    expect(message.body!.parts![1].contentType!.mediaType.sub,
        MediaSubtype.textPlain);
    expect(message.body!.parts![1].description, 'Compiler diff');
    expect(message.body!.parts![1].cid,
        '<960723163407.20117h@cac.washington.edu>');
    expect(message.body!.parts![1].encoding, 'base64');
    expect(message.body!.parts![1].size, 4554);
    expect(message.body!.parts![1].numberOfLines, 73);
    expect(message.body!.parts![1].contentType!.charset, 'us-ascii');
    expect(message.body!.parts![1].contentType!.parameters['name'], 'cc.diff');
  });

  test('ImapClient fetch BODY[HEADER]', () async {
    mockServer.response = '* 123456 FETCH (BODY[HEADER] {345}\r\n'
        'Date: Wed, 17 Jul 1996 02:23:25 -0700 (PDT)\r\n'
        'From: Terry Gray <gray@cac.washington.edu>\r\n'
        'Subject: IMAP4rev1 WG mtg summary and minutes\r\n'
        'To: imap@cac.washington.edu\r\n'
        'cc: minutes@CNRI.Reston.VA.US, \r\n'
        '   John Klensin <KLENSIN@MIT.EDU>\r\n'
        'Message-Id: <B27397-0100000@cac.washington.edu>\r\n'
        'MIME-Version: 1.0\r\n'
        'Content-Type: TEXT/PLAIN; CHARSET=US-ASCII\r\n'
        ')\r\n'
        '* 123455 FETCH (BODY[HEADER] {319}\r\n'
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
        ')\r\n'
        '<tag> OK FETCH completed';
    final fetchResponse = await client.fetchMessages(
        MessageSequence.fromRange(123455, 123456), 'BODY[HEADER]');
    expect(fetchResponse, isNotNull, reason: 'fetch result expected');
    expect(fetchResponse.messages.length, 2);
    var message = fetchResponse.messages[0];
    expect(message.sequenceId, 123456);
    expect(message.headers, isNotNull);
    expect(message.headers!.length, 8);
    expect(
        message.getHeaderValue('From'), 'Terry Gray <gray@cac.washington.edu>');

    message = fetchResponse.messages[1];
    expect(message.sequenceId, 123455);
    expect(message.headers, isNotNull);
    expect(message.headers!.length, 9);
    expect(message.getHeaderValue('Chat-Version'), '1.0');
    expect(
        message.getHeaderValue('Content-Type'), 'text/plan; charset="UTF-8"');
  });

  test('ImapClient uid fetch BODY[HEADER]', () async {
    mockServer.response = '* 123456 FETCH (BODY[HEADER] {345}\r\n'
        'Date: Wed, 17 Jul 1996 02:23:25 -0700 (PDT)\r\n'
        'From: Terry Gray <gray@cac.washington.edu>\r\n'
        'Subject: IMAP4rev1 WG mtg summary and minutes\r\n'
        'To: imap@cac.washington.edu\r\n'
        'cc: minutes@CNRI.Reston.VA.US, \r\n'
        '   John Klensin <KLENSIN@MIT.EDU>\r\n'
        'Message-Id: <B27397-0100000@cac.washington.edu>\r\n'
        'MIME-Version: 1.0\r\n'
        'Content-Type: TEXT/PLAIN; CHARSET=US-ASCII\r\n'
        ')\r\n'
        '* 123455 FETCH (BODY[HEADER] {319}\r\n'
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
        ')\r\n'
        '<tag> OK FETCH completed';
    final fetchResponse = await client.uidFetchMessages(
        MessageSequence.fromRange(123455, 123456), 'BODY[HEADER]');
    expect(fetchResponse, isNotNull, reason: 'fetch result expected');
    expect(fetchResponse.messages.length, 2);
    var message = fetchResponse.messages[0];
    expect(message.headers, isNotNull);
    expect(message.headers!.length, 8);
    expect(
        message.getHeaderValue('From'), 'Terry Gray <gray@cac.washington.edu>');

    message = fetchResponse.messages[1];
    expect(message.headers, isNotNull);
    expect(message.headers!.length, 9);
    expect(message.getHeaderValue('Chat-Version'), '1.0');
    expect(
        message.getHeaderValue('Content-Type'), 'text/plan; charset="UTF-8"');
  });

  test('ImapClient fetch BODY.PEEK[HEADER.FIELDS (References)]', () async {
    mockServer.response =
        '* 123456 FETCH (BODY[HEADER.FIELDS (REFERENCES)] {50}\r\n'
        r'References: <chat$1579598212023314@russyl.com>'
        '\r\n\r\n'
        ')\r\n'
        '* 123455 FETCH (BODY[HEADER.FIELDS (REFERENCES)] {2}\r\n'
        '\r\n'
        ')\r\n'
        '<tag> OK FETCH completed';
    final fetchResponse = await client.fetchMessages(
        MessageSequence.fromRange(123455, 123456),
        'BODY.PEEK[HEADER.FIELDS (REFERENCES)]');
    expect(fetchResponse, isNotNull, reason: 'fetch result expected');

    expect(fetchResponse.messages.length, 2);
    var message = fetchResponse.messages[0];
    expect(message.sequenceId, 123456);
    expect(message.headers, isNotNull);
    expect(message.headers!.length, 1);
    expect(message.getHeaderValue('References'),
        r'<chat$1579598212023314@russyl.com>');

    message = fetchResponse.messages[1];
    expect(message.sequenceId, 123455);
    expect(message.headers, isEmpty);
    expect(message.getHeaderValue('References'), null);
  });

  test('ImapClient fetch BODY.PEEK[HEADER.FIELDS.NOT (References)]', () async {
    mockServer.response =
        '* 123456 FETCH (BODY[HEADER.FIELDS.NOT (REFERENCES)] {46}\r\n'
        'From: Shirley <Shirley.Jackson@domain.com>\r\n'
        '\r\n'
        ')\r\n'
        '* 123455 FETCH (BODY[HEADER.FIELDS.NOT (REFERENCES)] {2}\r\n'
        '\r\n'
        ')\r\n'
        '<tag> OK FETCH completed';
    final fetchResponse = await client.fetchMessages(
        MessageSequence.fromRange(123455, 123456),
        'BODY.PEEK[HEADER.FIELDS.NOT (REFERENCES)]');
    expect(fetchResponse, isNotNull, reason: 'fetch result expected');

    expect(fetchResponse.messages.length, 2);
    var message = fetchResponse.messages[0];
    expect(message.sequenceId, 123456);
    expect(message.headers, isNotNull);
    expect(message.headers!.length, 1);
    expect(
        message.getHeaderValue('From'), 'Shirley <Shirley.Jackson@domain.com>');

    message = fetchResponse.messages[1];
    expect(message.sequenceId, 123455);
    expect(message.headers, isEmpty);
    expect(message.getHeaderValue('References'), null);
    expect(message.getHeaderValue('From'), null);
  });

  test('ImapClient fetch BODY[]', () async {
    mockServer.response = '* 123456 FETCH (BODY[] {359}\r\n'
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
        ')\r\n'
        '* 123455 FETCH (BODY[] {374}\r\n'
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
        ')\r\n'
        '<tag> OK FETCH completed';
    final fetchResponse = await client.fetchMessages(
        MessageSequence.fromRange(123455, 123456), 'BODY[]');
    expect(fetchResponse, isNotNull, reason: 'fetch result expected');
    expect(fetchResponse.messages.length, 2);
    var message = fetchResponse.messages[0];
    expect(message.sequenceId, 123456);
    expect(message.decodeContentText(), 'Hello Word\r\n');

    message = fetchResponse.messages[1];
    expect(message.sequenceId, 123455);
    expect(message.decodeContentText(), 'Welcome to Enough MailKit.\r\n');
    expect(message.getHeaderValue('MIME-Version'), '1.0');
    expect(
        message.getHeaderValue('Content-Type'), 'text/plain; charset="utf-8"');
  });

  test('ImapClient fetch with split response', () async {
    mockServer.response = '* 123456 FETCH (BODY[] {359}\r\n'
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
        ')\r\n'
        '* 123456 FETCH (UID 16 FLAGS (\\Seen))\r\n'
        '<tag> OK FETCH completed';
    final fetchResponse = await client.fetchMessages(
        MessageSequence.fromId(123456, isUid: false), 'BODY[]');
    expect(fetchResponse, isNotNull, reason: 'fetch result expected');
    expect(fetchResponse.messages.length, 1);
    var message = fetchResponse.messages[0];
    expect(message.sequenceId, 123456);
    expect(message.decodeContentText(), 'Hello Word\r\n');
    expect(message.uid, 16);
    expect(message.flags, ['\\Seen']);
  });

  test('ImapClient fetch BODY[1]', () async {
    mockServer.response = '* 123456 FETCH (BODY[1] {14}\r\n'
        '\r\nHello Word\r\n'
        ')\r\n'
        '* 123455 FETCH (BODY[1] {27}\r\n'
        '\r\nWelcome to Enough Mail.\r\n'
        ')\r\n'
        '<tag> OK FETCH completed';

    final fetchResponse = await client.fetchMessages(
        MessageSequence.fromRange(123455, 123456), 'BODY[1]');
    expect(fetchResponse, isNotNull, reason: 'fetch result expected');
    expect(fetchResponse.messages.length, 2);
    var message = fetchResponse.messages[0];
    expect(message.sequenceId, 123456);
    final part = message.getPart('1')!;
    expect(part.decodeContentText(), '\r\nHello Word\r\n');

    message = fetchResponse.messages[1];
    expect(message.sequenceId, 123455);
    expect(message.getPart('1')!.decodeContentText(),
        '\r\nWelcome to Enough Mail.\r\n');
  });

  Future<Mailbox> _selectInbox() {
    mockServer.response = '* 63510 EXISTS\r\n'
        '* 23 RECENT\r\n'
        '* FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft \$Forwarded \$Unsubscribed)\r\n'
        '* OK [PERMANENTFLAGS (\\Answered \\Flagged \\Draft \\Deleted \\Seen \$Forwarded \$Unsubscribed \\*)] Unlimited\r\n'
        '* OK [UNSEEN 30130] Message 30130 is first unseen\r\n'
        '* OK [UIDNEXT 351118] Predicted next UID\r\n'
        '* OK [UIDVALIDITY 1245213765] UIDs valid\r\n'
        '<tag> OK [READ-WRITE] SELECT completed';
    client.serverInfo.pathSeparator ??= '/';
    return client.selectInbox();
  }

  test('ImapClient noop', () async {
    expungedMessages = [];
    final box = await _selectInbox();
    await Future.delayed(Duration(milliseconds: 20));
    mockServer.response = '<tag> OK NOOP Completed';
    await client.noop();
    mockServer.response = '* 2232 EXPUNGE\r\n'
        '* 1234 EXPUNGE\r\n'
        '* 23 EXISTS\r\n'
        '* 3 RECENT\r\n'
        '* 14 FETCH (FLAGS (\\Seen \\Deleted))\r\n'
        '* 2322 FETCH (FLAGS (\\Seen \$Chat))\r\n'
        '<tag> OK NOOP Completed';
    await client.noop();
    await Future.delayed(Duration(milliseconds: 10));
    expect(expungedMessages, [2232, 1234],
        reason: 'Expunged messages should fit');
    expect(box.messagesExists, 23);
    expect(box.messagesRecent, 3);
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
    mockServer.response = '* VANISHED 1232:1236\r\n'
        '* 233 EXISTS\r\n'
        '* 33 RECENT\r\n'
        '* 14 FETCH (FLAGS (\\Seen \\Deleted))\r\n'
        '* 2322 FETCH (FLAGS (\\Seen \$Chat))\r\n'
        '<tag> OK NOOP Completed';
    await client.noop();
    await Future.delayed(Duration(milliseconds: 50));
    expect(expungedMessages, [], reason: 'Expunged messages should fit');
    expect(vanishedMessages, isNotNull);
    expect(vanishedMessages!.toList(), [1232, 1233, 1234, 1235, 1236]);
    expect(box.messagesExists, 233);
    expect(box.messagesRecent, 33);
    expect(fetchEvents.length, 2, reason: 'Expecting 2 fetch events');
    event = fetchEvents[0];
    expect(event.message, isNotNull);
    expect(event.message.sequenceId, 14);
    expect(event.message.flags, [r'\Seen', r'\Deleted']);
    event = fetchEvents[1];
    expect(event.message, isNotNull);
    expect(event.message.sequenceId, 2322);
    expect(event.message.flags, [r'\Seen', r'$Chat']);
  });

  test('ImapClient check', () async {
    await _selectInbox();
    await Future.delayed(Duration(seconds: 1));
    expungedMessages = [];
    mockServer.response = '* 2232 EXPUNGE\r\n'
        '* 1234 EXPUNGE\r\n'
        '* VANISHED 1232:1236\r\n'
        '* 233 EXISTS\r\n'
        '* 33 RECENT\r\n'
        '* 14 FETCH (FLAGS (\\Seen \\Deleted))\r\n'
        '* 2322 FETCH (FLAGS (\\Seen \$Chat))\r\n'
        '<tag> OK CHECK Completed';
    await client.check();

    await Future.delayed(Duration(milliseconds: 50));
    expect(expungedMessages, [2232, 1234],
        reason: 'Expunged messages should fit');
  });

  test('ImapClient expunge', () async {
    await _selectInbox();
    expungedMessages = [];
    await Future.delayed(Duration(seconds: 1));

    mockServer.response = '* 3 EXPUNGE\r\n'
        '* 3 EXPUNGE\r\n'
        '* 23 EXPUNGE\r\n'
        '* 26 EXPUNGE\r\n'
        '<tag> OK EXPUNGE completed';

    await client.expunge();
    await Future.delayed(Duration(milliseconds: 50));
    expect(expungedMessages, [3, 3, 23, 26],
        reason: 'Expunged messages should fit');
  });

  test('ImapClient uidExpunge', () async {
    await _selectInbox();
    expungedMessages = [];
    await Future.delayed(Duration(seconds: 1));

    mockServer.response = '* 12345 EXPUNGE\r\n'
        '* 12346 EXPUNGE\r\n'
        '<tag> OK UID EXPUNGE completed';

    await client.uidExpunge(MessageSequence.fromRange(12345, 12346));
    await Future.delayed(Duration(milliseconds: 50));
    expect(expungedMessages, [12345, 12346],
        reason: 'Expunged messages should fit');
  });

  test('ImapClient copy', () async {
    await _selectInbox();
    mockServer.response = '<tag> OK messages copied';
    await client.copy(MessageSequence.fromRange(1, 3),
        targetMailboxPath: 'TRASH');
  });

  test('ImapClient uid copy', () async {
    await _selectInbox();
    mockServer.response =
        '<tag> OK [COPYUID 1232132 1232,1236 12345,12346] messages copied';
    final copyResponse = await client.uidCopy(
        MessageSequence.fromRange(1232, 1236),
        targetMailboxPath: 'TRASH');
    expect(copyResponse, isNotNull);
    expect(copyResponse.responseCodeCopyUid?.targetSequence, isNotNull);
    expect(copyResponse.responseCodeCopyUid!.targetSequence.toList(),
        [12345, 12346]);
  });

  test('ImapClient move', () async {
    await _selectInbox();
    mockServer.response =
        '<tag> OK [COPYUID 1232132 1232,1236 12345,12346] messages copied';
    final moveResponse = await client.move(MessageSequence.fromRange(1, 3),
        targetMailboxPath: 'TRASH');
    expect(moveResponse, isNotNull);
    expect(moveResponse.responseCodeCopyUid?.targetSequence, isNotNull);
    expect(moveResponse.responseCodeCopyUid!.targetSequence.toList(),
        [12345, 12346]);
  });

  test('ImapClient uid move', () async {
    await _selectInbox();
    mockServer.response =
        '<tag> OK [COPYUID 1232132 1232,1236 12345,12346] messages copied';
    final moveResponse = await client.uidMove(MessageSequence.fromRange(1, 3),
        targetMailboxPath: 'TRASH');
    expect(moveResponse, isNotNull);
    expect(moveResponse.responseCodeCopyUid?.targetSequence, isNotNull);
    expect(moveResponse.responseCodeCopyUid!.targetSequence.toList(),
        [12345, 12346]);
  });

  test('ImapClient store', () async {
    await _selectInbox();
    mockServer.response = '* 1 FETCH (FLAGS (\\Flagged \\Seen))\r\n'
        '* 2 FETCH (FLAGS (\\Deleted \\Seen))\r\n'
        '* 3 FETCH (FLAGS (\\Seen))\r\n'
        '<tag> OK store completed';
    final storeResponse = await client.store(
        MessageSequence.fromRange(1, 3), [r'\Seen'],
        unchangedSinceModSequence: 12346);
    expect(storeResponse.changedMessages, isNotNull);
    expect(storeResponse.changedMessages, isNotEmpty);
    expect(storeResponse.changedMessages!.length, 3);
    expect(storeResponse.changedMessages![0].sequenceId, 1);
    expect(storeResponse.changedMessages![0].flags, [r'\Flagged', r'\Seen']);
    expect(storeResponse.changedMessages![1].sequenceId, 2);
    expect(storeResponse.changedMessages![1].flags, [r'\Deleted', r'\Seen']);
    expect(storeResponse.changedMessages![2].sequenceId, 3);
    expect(storeResponse.changedMessages![2].flags, [r'\Seen']);
  });

  test('ImapClient store with modified sequence', () async {
    await _selectInbox();

    mockServer.response = '* 5 FETCH (MODSEQ (320162350))\r\n'
        '<tag> OK [MODIFIED 7,9] Conditional STORE done';
    final storeResponse = await client.store(
        MessageSequence.fromRange(4, 9), [r'\Seen'],
        unchangedSinceModSequence: 12345);
    expect(storeResponse.changedMessages, isNotNull);
    expect(storeResponse.changedMessages, isNotEmpty);
    expect(storeResponse.changedMessages!.length, 1);
    expect(storeResponse.changedMessages![0].sequenceId, 5);
    expect(storeResponse.modifiedMessageSequence, isNotNull);
    expect(storeResponse.modifiedMessageSequence!.length, 2);
    expect(storeResponse.modifiedMessageSequence!.toList(), [7, 9]);
  });

  test('ImapClient uid store', () async {
    await _selectInbox();
    mockServer.response = '* 123 FETCH (UID 12342 FLAGS (\\Flagged \\Seen))\r\n'
        '* 124 FETCH (UID 12343 FLAGS (\\Deleted \\Seen))\r\n'
        '* 125 FETCH (UID 12344 FLAGS (\\Seen))\r\n'
        '<tag> OK store completed';

    final storeResponse = await client
        .uidStore(MessageSequence.fromRange(12342, 12344), [r'\Seen']);
    expect(storeResponse.changedMessages, isNotNull);
    expect(storeResponse.changedMessages, isNotEmpty);
    expect(storeResponse.changedMessages!.length, 3);
    expect(storeResponse.changedMessages![0].uid, 12342);
    expect(storeResponse.changedMessages![0].flags, [r'\Flagged', r'\Seen']);
    expect(storeResponse.changedMessages![1].uid, 12343);
    expect(storeResponse.changedMessages![1].flags, [r'\Deleted', r'\Seen']);
    expect(storeResponse.changedMessages![2].uid, 12344);
    expect(storeResponse.changedMessages![2].flags, [r'\Seen']);
  });

  test('ImapClient markSeen', () async {
    await _selectInbox();
    mockServer.response = '* 1 FETCH (FLAGS (\\Flagged \\Seen))\r\n'
        '* 2 FETCH (FLAGS (\\Deleted \\Seen))\r\n'
        '* 3 FETCH (FLAGS (\\Seen))\r\n'
        '<tag> OK store completed';
    final storeResponse =
        await client.markSeen(MessageSequence.fromRange(1, 3));
    expect(storeResponse.changedMessages, isNotNull);
    expect(storeResponse.changedMessages, isNotEmpty);
    expect(storeResponse.changedMessages!.length, 3);
    expect(storeResponse.changedMessages![0].sequenceId, 1);
    expect(storeResponse.changedMessages![0].flags, [r'\Flagged', r'\Seen']);
    expect(storeResponse.changedMessages![1].sequenceId, 2);
    expect(storeResponse.changedMessages![1].flags, [r'\Deleted', r'\Seen']);
    expect(storeResponse.changedMessages![2].sequenceId, 3);
    expect(storeResponse.changedMessages![2].flags, [r'\Seen']);
  });

  test('ImapClient markFlagged', () async {
    await _selectInbox();
    mockServer.response = '* 1 FETCH (FLAGS (\\Flagged \\Seen))\r\n'
        '* 2 FETCH (FLAGS (\\Deleted \\Flagged \\Seen))\r\n'
        '* 3 FETCH (FLAGS (\\Seen \\Flagged))\r\n'
        '<tag> OK store completed';
    final storeResponse =
        await client.markFlagged(MessageSequence.fromRange(1, 3));
    expect(storeResponse.changedMessages, isNotNull);
    expect(storeResponse.changedMessages, isNotEmpty);
    expect(storeResponse.changedMessages!.length, 3);
    expect(storeResponse.changedMessages![0].sequenceId, 1);
    expect(storeResponse.changedMessages![0].flags, [r'\Flagged', r'\Seen']);
    expect(storeResponse.changedMessages![1].sequenceId, 2);
    expect(storeResponse.changedMessages![1].flags,
        [r'\Deleted', r'\Flagged', r'\Seen']);
    expect(storeResponse.changedMessages![2].sequenceId, 3);
    expect(storeResponse.changedMessages![2].flags, [r'\Seen', r'\Flagged']);
  });

  test('ImapClient enable', () async {
    mockServer.response = '* ENABLED CONDSTORE QRESYNC\r\n'
        '<tag> OK Enabled Caps';
    final enabledCaps = await client.enable(['QRESYNC', 'CONDSTORE']);
    expect(enabledCaps, isNotEmpty);
    expect(enabledCaps.length, 2);
    expect(enabledCaps[0].name, 'CONDSTORE');
    expect(enabledCaps[1].name, 'QRESYNC');
  });

  test('ImapClient getmetadata 1', () async {
    mockServer.response =
        '* METADATA "INBOX" (/private/comment "My own comment")\r\n'
        '<tag> OK Metadata completed';
    final metaData = await client.getMetaData('/private/comment');
    expect(metaData, isNotNull);
    expect(metaData, isNotEmpty);
    expect(metaData[0].name, '/private/comment');
    expect(metaData[0].mailboxName, 'INBOX');
    expect(metaData[0].valueText, 'My own comment');
  });

  test('ImapClient getmetadata 2', () async {
    mockServer.response =
        '* METADATA "" (/private/vendor/vendor.dovecot/webpush/vapid {136}\r\n'
        '-----BEGIN PUBLIC KEY-----\r\n'
        'MDkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDIgACYHfTQ0biATut1VhK/AW2KmZespz+\r\n'
        'DEQ1yH3nvbayCuY=\r\n'
        '-----END PUBLIC KEY-----)\r\n'
        '<tag> OK Metadata completed';
    final metaData = await client.getMetaData('/private/comment');
    expect(metaData, isNotNull);
    expect(metaData, isNotEmpty);
    expect(metaData[0].name, '/private/vendor/vendor.dovecot/webpush/vapid');
    expect(metaData[0].mailboxName, '');
    expect(
        metaData[0].valueText,
        '-----BEGIN PUBLIC KEY-----\r\n'
        'MDkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDIgACYHfTQ0biATut1VhK/AW2KmZespz+\r\n'
        'DEQ1yH3nvbayCuY=\r\n'
        '-----END PUBLIC KEY-----');
  });

  test('ImapClient getmetadata with several entries', () async {
    mockServer.response =
        '* METADATA "" (/private/vendor/vendor.dovecot/coi/config/enabled {3}\r\n'
        'yes'
        ' /private/vendor/vendor.dovecot/coi/config/mailbox-root {3}\r\n'
        'COI'
        ' /private/vendor/vendor.dovecot/coi/config/message-filter {6}\r\n'
        'active'
        ')\r\n'
        '<tag> OK Metadata completed';
    final metaData = await client.getMetaData('/private/comment');
    expect(metaData, isNotNull);
    expect(metaData, isNotEmpty);
    expect(metaData.length, 3);
    expect(
        metaData[0].name, '/private/vendor/vendor.dovecot/coi/config/enabled');
    expect(metaData[0].mailboxName, '');
    expect(metaData[0].valueText, 'yes');
    expect(metaData[1].name,
        '/private/vendor/vendor.dovecot/coi/config/mailbox-root');
    expect(metaData[1].mailboxName, '');
    expect(metaData[1].valueText, 'COI');
    expect(metaData[2].name,
        '/private/vendor/vendor.dovecot/coi/config/message-filter');
    expect(metaData[2].mailboxName, '');
    expect(metaData[2].valueText, 'active');
  });

  test('ImapClient setmetadata', () async {
    mockServer.response = '<tag> OK Metadata completed';
    final entry = MetaDataEntry(name: '/private/comment');
    await client.setMetaData(entry);
  });

  test('ImapClient append', () async {
    await _selectInbox();
    final message = MessageBuilder.buildSimpleTextMessage(
        MailAddress('User Name', 'user.name@domain.com'),
        [MailAddress('Rita Recpient', 'rr@domain.com')],
        'Hey,\r\nhow are things today?\r\n\r\nAll the best!',
        subject: 'Appended draft message')!;
    mockServer.response = '+ OK\r\n'
        '<tag> OK [APPENDUID 1466002016 176] Append completed (0.068 + 0.059 + 0.051 secs).';
    final appendResponse =
        await client.appendMessage(message, flags: [r'\Draft', r'\Seen']);
    expect(appendResponse, isNotNull);
    expect(appendResponse.responseCode, isNotNull);
    expect(appendResponse.responseCode!.substring(0, 'APPENDUID'.length),
        'APPENDUID');
    final uidResponseCode = appendResponse.responseCodeAppendUid!;
    expect(uidResponseCode, isNotNull);
    expect(uidResponseCode.uidValidity, 1466002016);
    expect(uidResponseCode.targetSequence.toList().first, 176);
  });

  test('ImapClient idle', () async {
    final box = await _selectInbox();
    expungedMessages = [];
    mockServer.response = '+ OK IDLE started\r\n'
        '<tag> OK IDLE done';
    await client.idleStart();

    mockServer.fire(Duration(milliseconds: 100),
        '* 2 EXPUNGE\r\n* 17 EXPUNGE\r\n* ${box.messagesExists} EXISTS\r\n');
    await Future.delayed(Duration(milliseconds: 200));
    await client.idleDone();
    expect(expungedMessages.length, 2);
    expect(expungedMessages[0], 2);
    expect(expungedMessages[1], 17);
  });

  test('ImapClient setquota', () async {
    mockServer.response = '* QUOTA INBOX (STORAGE 0 120 MESSAGES 0 5000)\r\n'
        '<tag> OK Quota set';
    final quotaResult = await client.setQuota(
        quotaRoot: 'INBOX', resourceLimits: {'STORAGE': 120, 'MESSAGES': 5000});
    expect(quotaResult, isNotNull);
    expect(quotaResult.rootName, 'INBOX');
    expect(quotaResult.resourceLimits.length, 2);
    expect(quotaResult.resourceLimits[0].name, 'STORAGE');
    expect(quotaResult.resourceLimits[0].currentUsage, 0);
    expect(quotaResult.resourceLimits[0].usageLimit, 120);
    expect(quotaResult.resourceLimits[1].name, 'MESSAGES');
    expect(quotaResult.resourceLimits[1].currentUsage, 0);
    expect(quotaResult.resourceLimits[1].usageLimit, 5000);
  });

  test('ImapClient getquota', () async {
    mockServer.response = '* QUOTA INBOX (STORAGE 100 1000 TRASH 3 10)\r\n'
        '<tag> OK Quota set';
    final quotaResult = await client.getQuota(quotaRoot: 'INBOX');
    expect(quotaResult.rootName, 'INBOX');
    expect(quotaResult.resourceLimits.length, 2);
    expect(quotaResult.resourceLimits[0].name, 'STORAGE');
    expect(quotaResult.resourceLimits[0].currentUsage, 100);
    expect(quotaResult.resourceLimits[0].usageLimit, 1000);
    expect(quotaResult.resourceLimits[1].name, 'TRASH');
    expect(quotaResult.resourceLimits[1].currentUsage, 3);
    expect(quotaResult.resourceLimits[1].usageLimit, 10);
  });

  test('ImapClient getquotaroot', () async {
    mockServer.response = '* QUOTAROOT INBOX "User quota"\r\n'
        '* QUOTA "User quota" (STORAGE 232885 1048576)\r\n'
        '<tag> OK Quota set';
    final quotaRootResult = await client.getQuotaRoot(mailboxName: 'INBOX');
    expect(quotaRootResult.mailboxName, 'INBOX');
    expect(quotaRootResult.rootNames[0], 'User quota');
    expect(quotaRootResult.quotaRoots['User quota'], isNotNull);
    expect(
        quotaRootResult.quotaRoots['User quota']!.resourceLimits, isNotEmpty);
    expect(quotaRootResult.quotaRoots['User quota']!.resourceLimits[0].name,
        'STORAGE');
    expect(
        quotaRootResult.quotaRoots['User quota']!.resourceLimits[0].usageLimit,
        1048576);
  });

  test('ImapClient close', () async {
    mockServer.response = '<tag> OK bye';
    await client.closeMailbox();
  });

  test('ImapClient logout', () async {
    mockServer.response = '<tag> OK bye';
    await client.logout();
  });
}
