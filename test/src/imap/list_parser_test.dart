import 'package:enough_mail/imap/imap_client.dart';
import 'package:enough_mail/imap/mailbox.dart';
import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/imap_response.dart';
import 'package:enough_mail/src/imap/imap_response_line.dart';
import 'package:enough_mail/src/imap/list_parser.dart';
import 'package:enough_mail/src/util/client_base.dart';
import 'package:test/test.dart';

void main() {
  final serverInfo = ImapServerInfo(ConnectionInfo('localhost', 993, true));

  Response<List<Mailbox>> _parseListResponse(ListParser parser, sourceData) {
    var response = Response<List<Mailbox>>()..status = ResponseStatus.OK;
    sourceData.forEach((details) => parser.parseUntagged(details, response));
    return response;
  }

  test('List all mailboxes', () {
    final lines = [
      'LIST (\\Marked \\NoInferiors) "/" "inbox"',
      'LIST () "/" "Fruit"',
      'LIST () "/" "Fruit/Apple"',
      'LIST () "/" "Fruit/Banana"',
      'LIST () "/" "Tofu"',
      'LIST () "/" "Vegetable"',
      'LIST () "/" "Vegetable/Broccoli"',
      'LIST () "/" "Vegetable/Corn"',
    ];
    var details = <ImapResponse>[];
    lines.forEach(
        (raw) => details.add(ImapResponse()..add(ImapResponseLine(raw))));
    var parser = ListParser(serverInfo);
    var response = _parseListResponse(parser, details);
    var mboxes = parser.parse(null, response);
    expect(mboxes.length, 8);
    expect(mboxes[0].isInbox, true);
    expect(mboxes[0].hasFlag(MailboxFlag.marked), true);
    expect(mboxes[0].hasFlag(MailboxFlag.noInferior), true);
    expect(mboxes[4].path, 'Tofu');
    expect(mboxes[6].path, 'Vegetable/Broccoli');
    expect(serverInfo.pathSeparator, '/');
    expect(parser.info.pathSeparator, '/');
  });

  test('List extended: SUBSCRIBED response', () {
    final lines = [
      r'LIST (\Marked \NoInferiors \Subscribed) "/" "inbox"',
      r'LIST (\Subscribed) "/" "Fruit/Banana"',
      r'LIST (\Subscribed \NonExistent) "/" "Fruit/Peach"',
      r'LIST (\Subscribed) "/" "Vegetable"',
      r'LIST (\Subscribed) "/" "Vegetable/Broccoli"',
    ];
    var details = <ImapResponse>[];
    lines.forEach(
        (raw) => details.add(ImapResponse()..add(ImapResponseLine(raw))));
    var parser = ListParser(serverInfo, isExtended: true);
    var response = _parseListResponse(parser, details);
    var mboxes = parser.parse(null, response);
    expect(mboxes.length, 5);
    expect(mboxes[0].hasFlag(MailboxFlag.subscribed), true);
    expect(mboxes[2].hasFlag(MailboxFlag.nonExistent), true);
    expect(mboxes[4].path, 'Vegetable/Broccoli');
  });

  test('List extended: return CHILDREN response', () {
    final lines = [
      r'LIST (\Marked \NoInferiors) "/" "inbox"',
      r'LIST (\HasChildren) "/" "Fruit"',
      r'LIST (\HasNoChildren) "/" "Tofu"',
      r'LIST (\HasChildren) "/" "Vegetable"',
    ];
    var details = <ImapResponse>[];
    lines.forEach(
        (raw) => details.add(ImapResponse()..add(ImapResponseLine(raw))));
    var parser =
        ListParser(serverInfo, isExtended: true, hasReturnOptions: true);
    var response = _parseListResponse(parser, details);
    var mboxes = parser.parse(null, response);
    expect(mboxes.length, 4);
    expect(mboxes[0].hasFlag(MailboxFlag.noInferior), true);
    expect(mboxes[2].hasFlag(MailboxFlag.hasNoChildren), true);
  });

  test('List extended: REMOTE, return CHILDREN response', () {
    final lines = [
      r'LIST (\Marked \NoInferiors) "/" "inbox"',
      r'LIST (\HasChildren) "/" "Fruit"',
      r'LIST (\HasNoChildren) "/" "Tofu"',
      r'LIST (\HasChildren) "/" "Vegetable"',
      r'LIST (\Remote) "/" "Bread"',
      r'LIST (\HasChildren \Remote) "/" "Meat"',
    ];
    var details = <ImapResponse>[];
    lines.forEach(
        (raw) => details.add(ImapResponse()..add(ImapResponseLine(raw))));
    var parser =
        ListParser(serverInfo, isExtended: true, hasReturnOptions: true);
    var response = _parseListResponse(parser, details);
    var mboxes = parser.parse(null, response);
    expect(mboxes.length, 6);
    expect(mboxes[4].hasFlag(MailboxFlag.remote), true);
    expect(mboxes[5].hasFlag(MailboxFlag.remote), true);
    expect(mboxes[5].hasFlag(MailboxFlag.hasChildren), true);
  });

  test('List extended: SUBSCRIBED RECURSIVEMATCH response', () {
    final lines = [
      r'LIST () "/" "Foo" ("CHILDINFO" ("SUBSCRIBED"))',
    ];
    var details = <ImapResponse>[];
    lines.forEach(
        (raw) => details.add(ImapResponse()..add(ImapResponseLine(raw))));
    var parser = ListParser(serverInfo, isExtended: true);
    var response = _parseListResponse(parser, details);
    var mboxes = parser.parse(null, response);
    expect(mboxes.length, 1);
    expect(mboxes[0].name, 'Foo');
    expect(mboxes[0].extendedData, contains('CHILDINFO'));
    expect(mboxes[0].extendedData['CHILDINFO'], contains('SUBSCRIBED'));
  });

  test('List with return STATUS response', () {
    final lines = [
      r'LIST () "."  "INBOX"',
      r'STATUS "INBOX" (MESSAGES 17 UNSEEN 16)',
      r'LIST () "." "foo"',
      r'STATUS "foo" (MESSAGES 30 UNSEEN 29)',
      r'LIST (\NoSelect) "." "bar"',
    ];
    var details = <ImapResponse>[];
    lines.forEach(
        (raw) => details.add(ImapResponse()..add(ImapResponseLine(raw))));
    var parser =
        ListParser(serverInfo, isExtended: true, hasReturnOptions: true);
    var response = _parseListResponse(parser, details);
    var mboxes = parser.parse(null, response);
    expect(mboxes.length, 3);
    expect(mboxes[0].messagesExists, 17);
    expect(mboxes[0].messagesUnseen, 16);
    expect(mboxes[1].messagesExists, 30);
    expect(mboxes[1].messagesUnseen, 29);
    expect(mboxes[2].flags, contains(MailboxFlag.noSelect));
  });
}
