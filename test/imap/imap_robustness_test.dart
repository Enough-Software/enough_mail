import 'dart:convert';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/imap/command.dart';
import 'package:enough_mail/src/private/imap/imap_response.dart';
import 'package:enough_mail/src/private/imap/imap_response_line.dart';
import 'package:enough_mail/src/private/imap/imap_response_reader.dart';
import 'package:enough_mail/src/private/imap/response_parser.dart';
import 'package:enough_mail/src/private/util/client_base.dart';
import 'package:test/test.dart';

import '../mock_socket.dart';
import 'mock_imap_server.dart';

class _ThrowingParser extends ResponseParser<String> {
  @override
  String? parse(ImapResponse imapResponse, Response<String> response) =>
      throw const FormatException('simulated parser bug');
}

late ImapClient client;
late MockImapServer mockServer;

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  setUp(() async {
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
      '* OK [CAPABILITY IMAP4rev1 UIDPLUS] IMAP server ready\r\n',
    );
    await Future.delayed(const Duration(milliseconds: 15));
    mockServer.response = '<tag> OK LOGIN completed';
    await client.login('testuser', 'testpassword');
    mockServer.response =
        '* LIST (\\HasNoChildren) "." "INBOX"\r\n<tag> OK LIST completed';
    await client.listMailboxes();
    mockServer.response =
        '* 42 EXISTS\r\n* OK [UIDVALIDITY 1] ok\r\n<tag> OK [READ-WRITE] done';
    await client.selectMailboxByPath('INBOX');
  });

  group('ImapResponseReader', () {
    test('a line that only ends with } is not a literal', () {
      final responses = <ImapResponse>[];
      ImapResponseReader(responses.add).onData(_bytes('12345}\r\n'));
      expect(responses, hasLength(1));
      expect(responses.first.parseText, '12345}');
      expect(ImapResponseLine('* OK {-5}').isWithLiteral, isFalse);
      expect(ImapResponseLine('* OK {-5}').line, '* OK {-5}');
      expect(ImapResponseLine('* OK {12}').literal, 12);
      expect(ImapResponseLine('* OK {12+}').literal, 12);
    });

    test('an empty literal does not swallow the rest of the line', () {
      final responses = <ImapResponse>[];
      ImapResponseReader(responses.add).onData(
        _bytes('* 1 FETCH (UID 5 BODY[TEXT] {0}\r\n FLAGS (\\Seen))\r\n'),
      );
      expect(responses, hasLength(1));
      final values = responses.first.iterate().values;
      final fetch = values.firstWhere((v) => v.value == 'FETCH');
      expect(fetch.children?.map((v) => v.value), contains('FLAGS'));
    });

    test('rejects literals above the size limit', () {
      final reader = ImapResponseReader((_) {}, maxLiteralSize: 1024);
      expect(
        () => reader.onData(_bytes('* 1 FETCH (BODY[] {9999999999}\r\n')),
        throwsFormatException,
      );
    });

    test('many literals in one response do not overflow the stack', () {
      final buffer = StringBuffer('* 1 FETCH (');
      for (var i = 0; i < 100000; i++) {
        buffer.write('X {1}\r\na ');
      }
      buffer.write('UID 1)\r\n');
      final responses = <ImapResponse>[];
      ImapResponseReader(responses.add).onData(_bytes(buffer.toString()));
      expect(responses, hasLength(1));
    });

    test('keeps token separation before a literal', () {
      final responses = <ImapResponse>[];
      ImapResponseReader(
        responses.add,
      ).onData(_bytes('* LIST (\\HasNoChildren) "." {9}\r\nINBOX.Foo\r\n'));
      expect(
        responses.first.parseText,
        '* LIST (\\HasNoChildren) "." INBOX.Foo',
      );
    });
  });

  group('ImapClient', () {
    test('malformed FETCH data fails the command instead of hanging', () async {
      mockServer.response =
          '* 1 FETCH (UID notanumber RFC822.SIZE x FLAGS (\\Seen ()))\r\n'
          '<tag> OK FETCH completed';
      final result = await client.fetchMessages(
        MessageSequence.fromId(1),
        '(UID RFC822.SIZE FLAGS)',
      );
      expect(result.messages, hasLength(1));
      expect(result.messages.first.uid, isNull);
      expect(result.messages.first.flags, ['\\Seen']);

      // malformed untagged data is skipped, the command still completes:
      mockServer.response =
          '* THREAD (a)\r\n'
          '<tag> OK THREAD completed';
      await client.threadMessages(method: 'REFERENCES', since: DateTime(2020));

      // a parser failing on the tagged response fails the command:
      mockServer.response = '<tag> OK NOOP completed';
      await expectLater(
        client.sendCommand(Command('NOOP'), _ThrowingParser()),
        throwsA(isA<ImapException>()),
      );

      // and the connection remains usable:
      mockServer.response = '<tag> OK NOOP completed';
      await client.noop();
    });

    test('escaped quotes and backslashes in an ENVELOPE', () async {
      mockServer.response =
          r'* 1 FETCH (ENVELOPE ("Fri, 25 Oct 2019 16:35:28 +0200" '
          r'"Path C:\\ and \"quoted\"" (("Me" NIL "me" "example.com")) '
          r'(("Me" NIL "me" "me.com")) (("Me" NIL "me" "me.com")) '
          r'(("You" NIL "you" "example.com")) NIL NIL NIL "<id@example.com>"))'
          '\r\n<tag> OK FETCH completed';
      final result = await client.fetchMessages(
        MessageSequence.fromId(1),
        '(ENVELOPE)',
      );
      final envelope = result.messages.first.envelope;
      expect(envelope, isNotNull);
      expect(envelope?.subject, r'Path C:\ and "quoted"');
      expect(envelope?.to?.first.email, 'you@example.com');
    });

    test('partial fetch responses are attributed to the right part', () async {
      mockServer.response =
          '* 1 FETCH (UID 7 BODY[1]<0> {5}\r\nhello)\r\n'
          '<tag> OK FETCH completed';
      final result = await client.fetchMessages(
        MessageSequence.fromId(1),
        '(UID BODY[1]<0.5>)',
      );
      final message = result.messages.first;
      expect(message.uid, 7);
      expect(message.getPart('1')?.decodeContentText(), 'hello');
    });

    test('literal mailbox names in LIST responses', () async {
      mockServer.response =
          '* LIST (\\HasNoChildren) "." {9}\r\nINBOX.Foo\r\n'
          '<tag> OK LIST completed';
      final boxes = await client.listMailboxes();
      expect(boxes, hasLength(1));
      expect(boxes.first.path, 'INBOX.Foo');
      expect(boxes.first.name, 'Foo');
    });

    test('huge VANISHED ranges are rejected without allocating them', () async {
      mockServer.response =
          '* VANISHED (EARLIER) 1:4294967295\r\n'
          '<tag> OK NOOP completed';
      await client.noop();
      expect(
        () => MessageSequence.parse('1:4294967296'),
        throwsA(isA<InvalidArgumentException>()),
      );
      expect(
        () => MessageSequence.parse('1:99999999'),
        throwsA(isA<InvalidArgumentException>()),
      );
      expect(MessageSequence.parse('1:1000000').length, 1000000);
    });

    test(
      'an oversized literal fails pending commands and disconnects',
      () async {
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
        connection.socketServer.write('* OK ready\r\n');
        await Future.delayed(const Duration(milliseconds: 15));
        mockServer.response =
            '* 1 FETCH (BODY[] {999999999999}\r\n<tag> OK FETCH completed';
        await expectLater(
          client.fetchMessages(MessageSequence.fromId(1), '(BODY[])'),
          throwsA(isA<ImapException>()),
        );
        await Future.delayed(const Duration(milliseconds: 50));
        expect(client.isConnected, isFalse);
      },
    );
  });
}
