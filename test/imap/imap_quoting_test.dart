import 'dart:convert';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/util/client_base.dart';
import 'package:test/test.dart';

import '../mock_socket.dart';
import 'mock_imap_server.dart';

late ImapClient client;
late MockImapServer mockServer;

Future<void> setUpClient({
  bool login = true,
  String capabilities = 'IMAP4rev1 UIDPLUS',
}) async {
  client = ImapClient();
  final connection = MockConnection();
  client.connect(
    connection.socketClient,
    connectionInformation: const ConnectionInfo(
      'imaptest.enough.de',
      993,
      isSecure: true,
    ),
  );
  mockServer = MockImapServer(connection.socketServer);
  connection.socketServer.write(
    '* OK [CAPABILITY $capabilities] IMAP server ready\r\n',
  );
  await Future.delayed(const Duration(milliseconds: 15));
  if (login) {
    mockServer.response = '<tag> OK LOGIN completed';
    await client.login('user', 'secret');
    mockServer.response =
        '* LIST (\\HasNoChildren) "/" "INBOX"\r\n<tag> OK LIST completed';
    await client.listMailboxes();
    mockServer.requests.clear();
  }
}

void main() {
  group('LOGIN', () {
    test('escapes quotes and backslashes', () async {
      await setUpClient(login: false);
      mockServer.response = '<tag> OK LOGIN completed';
      await client.login('us"er', r'pa"ss\word');
      expect(
        mockServer.requests.single,
        'a0 LOGIN "us\\"er" "pa\\"ss\\\\word"\r\n',
      );
    });

    test('sends non-ASCII credentials as literals', () async {
      await setUpClient(login: false);
      mockServer.response = '+ go on\r\n<tag> OK LOGIN completed';
      await client.login('user', 'pässwörd');
      // the mock server records the raw bytes as Latin-1 text:
      final literal = String.fromCharCodes(utf8.encode('pässwörd'));
      expect(mockServer.requests, ['a0 LOGIN "user" {10}\r\n', '$literal\r\n']);
    });

    test('line breaks in credentials cannot inject commands', () async {
      await setUpClient(login: false);
      mockServer.response = '+ go on\r\n<tag> OK LOGIN completed';
      await client.login('user', 'x\r\na1 DELETE INBOX');
      expect(mockServer.requests.first, 'a0 LOGIN "user" {18}\r\n');
      expect(mockServer.requests, hasLength(2));
    });
  });

  test('mailbox names are quoted and escaped', () async {
    await setUpClient();
    mockServer.response = '* 1 EXISTS\r\n<tag> OK [READ-WRITE] done';
    await client.selectMailboxByPath(r'Foo"Bar\Baz (1)');
    expect(mockServer.requests.single, 'a2 SELECT "Foo\\"Bar\\\\Baz (1)"\r\n');
    expect(
      () => client.selectMailboxByPath('INBOX\r\na3 DELETE INBOX'),
      throwsArgumentError,
    );
  });

  group('selectMailboxByPath', () {
    test('encodes the whole path in modified UTF-7', () async {
      await setUpClient();
      mockServer.response = '* 1 EXISTS\r\n<tag> OK [READ-WRITE] done';
      final box = await client.selectMailboxByPath('Entwürfe/Müll');
      expect(
        mockServer.requests.single,
        'a2 SELECT "Entw&APw-rfe/M&APw-ll"\r\n',
      );
      expect(box.path, 'Entwürfe/Müll');
      expect(box.name, 'Müll');
    });

    test('escapes an ampersand', () async {
      await setUpClient();
      mockServer.response = '* 1 EXISTS\r\n<tag> OK [READ-WRITE] done';
      final box = await client.selectMailboxByPath('R&D');
      expect(mockServer.requests.single, 'a2 SELECT "R&-D"\r\n');
      expect(box.path, 'R&D');
    });
  });

  group('UTF8=ACCEPT', () {
    const capabilities = 'IMAP4rev1 ENABLE UIDPLUS UTF8=ACCEPT';

    Future<void> selectAndAppend() async {
      mockServer.response = '* 1 EXISTS\r\n<tag> OK [READ-WRITE] done';
      await client.selectMailboxByPath('Entwürfe');
      mockServer.response = '+ go on\r\n<tag> OK APPEND completed';
      await client.appendMessageText(
        'Subject: x\r\n\r\nbody',
        targetMailboxPath: 'Entwürfe',
      );
    }

    test('is not used while it is only advertised', () async {
      await setUpClient(capabilities: capabilities);
      expect(client.serverInfo.supportsUtf8, isTrue);
      await selectAndAppend();
      expect(mockServer.requests.take(2), [
        'a2 SELECT "Entw&APw-rfe"\r\n',
        'a3 APPEND Entw&APw-rfe {18}\r\n',
      ]);
    });

    test('is used once it is enabled', () async {
      await setUpClient(capabilities: capabilities);
      mockServer.response = '* ENABLED UTF8=ACCEPT\r\n<tag> OK ENABLE done';
      await client.enable([ImapServerInfo.capabilityUtf8Accept]);
      mockServer.requests.clear();
      await selectAndAppend();
      // the mock server records the raw bytes as Latin-1 text:
      String wire(String line) => String.fromCharCodes(utf8.encode(line));
      expect(mockServer.requests.take(2), [
        wire('a3 SELECT "Entwürfe"\r\n'),
        wire('a4 APPEND "Entwürfe" {18}\r\n'),
      ]);
    });
  });

  group('SEARCH', () {
    test('quoted search values escape backslashes and quotes', () {
      final query = SearchQueryBuilder.from(r'a\b"c', SearchQueryType.subject);
      expect(query.toString(), 'SUBJECT "a\\\\b\\"c"');
    });

    test('control characters force a literal', () {
      final query = SearchQueryBuilder.from(
        'line\r\nbreak',
        SearchQueryType.subject,
      );
      expect(query.toString(), 'CHARSET "UTF-8" SUBJECT {11}\nline\r\nbreak');
    });

    test('literals with line feeds are sent as one continuation', () async {
      await setUpClient();
      mockServer.response = '+ go on\r\n* SEARCH 1\r\n<tag> OK SEARCH done';
      final result = await client.searchMessages(
        searchCriteria: 'SUBJECT {5}\nab\ncd FROM "x"',
      );
      expect(result.matchingSequence?.toList(), [1]);
      expect(mockServer.requests, [
        'a2 SEARCH SUBJECT {5}\r\n',
        'ab\ncd FROM "x"\r\n',
      ]);
    });
  });
}
