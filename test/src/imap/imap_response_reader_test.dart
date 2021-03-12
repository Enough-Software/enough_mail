import 'package:enough_mail/src/imap/imap_response.dart';
import 'package:enough_mail/src/imap/imap_response_reader.dart';
import 'package:test/test.dart';
import 'dart:typed_data';

ImapResponse? _lastResponse;
void _onImapResponse(ImapResponse response) {
  _lastResponse = response;
}

List<ImapResponse> _lastResponses = <ImapResponse>[];
void _onMultipleImapResponse(ImapResponse response) {
  _lastResponses.add(response);
}

Uint8List _toUint8List(String text) {
  return Uint8List.fromList(text.codeUnits);
}

void main() {
  test('ImapResponseReader.oneOnDataCall()', () {
    var reader = ImapResponseReader(_onImapResponse);
    var text =
        r'1232 FETCH (FLAGS () INTERNALDATE "25-Oct-2019 16:35:31 +0200" '
        'RFC822.SIZE 15320 ENVELOPE ("Fri, 25 Oct 2019 16:35:28 +0200 (CEST)" {61}\r\n'
        'New appointment: SoW (x2) for rebranding of App & Mobile Apps'
        ' (("=?UTF-8?Q?Sch=C3=B6n=2C_Rob?=" NIL "rob.schoen" "domain.com")) (("=?UTF-8?Q?Sch=C3=B6n=2C_'
        'Rob?=" NIL "rob.schoen" "domain.com")) (("=?UTF-8?Q?Sch=C3=B6n=2C_Rob?=" NIL "rob.schoen" '
        '"domain.com")) (("Alice Dev" NIL "alice.dev" "domain.com")) NIL NIL "<Appointment.59b0d625-afaf-4fc6'
        '-b845-4b0fce126730@domain.com>" "<130499090.797.1572014128349@product-gw2.domain.com>") BODY (("text" "plain" '
        '("charset" "UTF-8") NIL NIL "quoted-printable" 1289 53)("text" "html" ("charset" "UTF-8") NIL NIL "quoted-printable" '
        '7496 302) "alternative"))\r\n';
    reader.onData(_toUint8List(text));
    expect(_lastResponse, isNotNull, reason: 'response expected');
    expect(_lastResponse!.isSimple, false);
    expect(_lastResponse!.lines, isNotEmpty);
    expect(_lastResponse!.lines.length, 3);
    expect(_lastResponse!.lines[0].isWithLiteral, true);
    expect(_lastResponse!.lines[0].literal, 61);
    expect(_lastResponse!.lines[0].line,
        '1232 FETCH (FLAGS () INTERNALDATE "25-Oct-2019 16:35:31 +0200" RFC822.SIZE 15320 ENVELOPE ("Fri, 25 Oct 2019 16:35:28 +0200 (CEST)"');
    expect(_lastResponse!.lines[1].isWithLiteral, false);
    expect(_lastResponse!.lines[1].line,
        'New appointment: SoW (x2) for rebranding of App & Mobile Apps');
    expect(_lastResponse!.lines[2].isWithLiteral, false);
    _lastResponse = null;
  }); // test end

  test('ImapResponseReader - simple response', () {
    var reader = ImapResponseReader(_onImapResponse);
    var text =
        '1232 FETCH (FLAGS () INTERNALDATE "25-Oct-2019 16:35:31 +0200")\r\n';
    reader.onData(_toUint8List(text));
    expect(_lastResponse != null, true, reason: 'response expected');
    expect(_lastResponse!.isSimple, true);
    expect(_lastResponse!.lines.length, 1);
    expect(_lastResponse!.first, _lastResponse!.lines[0]);
    expect(_lastResponse!.lines[0].isWithLiteral, false);
    expect(_lastResponse!.lines[0].rawLine,
        '1232 FETCH (FLAGS () INTERNALDATE "25-Oct-2019 16:35:31 +0200")');
    expect(_lastResponse!.lines[0].line,
        '1232 FETCH (FLAGS () INTERNALDATE "25-Oct-2019 16:35:31 +0200")');
    _lastResponse = null;
  }); // test end

  test('ImapResponseReader - test simple response delivered in 2 packages', () {
    var reader = ImapResponseReader(_onImapResponse);
    var text = '1232 FETCH (FLAGS () INTERNALDATE';
    reader.onData(_toUint8List(text));
    expect(_lastResponse, null);
    text = ' "25-Oct-2019 16:35:31 +0200")\r\n';
    reader.onData(_toUint8List(text));
    expect(_lastResponse != null, true, reason: 'response expected');
    expect(_lastResponse!.isSimple, true);
    expect(_lastResponse!.lines.length, 1);
    expect(_lastResponse!.first, _lastResponse!.lines[0]);
    expect(_lastResponse!.lines[0].isWithLiteral, false);
    expect(_lastResponse!.lines[0].rawLine,
        '1232 FETCH (FLAGS () INTERNALDATE "25-Oct-2019 16:35:31 +0200")');
    expect(_lastResponse!.lines[0].line,
        '1232 FETCH (FLAGS () INTERNALDATE "25-Oct-2019 16:35:31 +0200")');
    _lastResponse = null;
  });

  test('ImapResponseReader - response in several parts', () {
    var reader = ImapResponseReader(_onImapResponse);
    var text = 'A001 LOGIN {11+}\r\n';
    reader.onData(_toUint8List(text));
    expect(_lastResponse, null);
    text = 'FRED FOOBAR {7+}\r\n';
    reader.onData(_toUint8List(text));
    expect(_lastResponse, null);
    text = 'fat man\r\n';
    reader.onData(_toUint8List(text));
    expect(_lastResponse != null, true);
    expect(_lastResponse!.isSimple, false);
    expect(_lastResponse!.lines.length, 3);
    expect(_lastResponse!.lines[0].isWithLiteral, true);
    expect(_lastResponse!.lines[0].literal, 11);
    expect(_lastResponse!.lines[0].rawLine, 'A001 LOGIN {11+}');
    expect(_lastResponse!.lines[0].line, 'A001 LOGIN');
    expect(_lastResponse!.lines[1].isWithLiteral, true);
    expect(_lastResponse!.lines[1].line, 'FRED FOOBAR');
    expect(_lastResponse!.lines[1].literal, 7);
    expect(_lastResponse!.lines[2].isWithLiteral, false);
    expect(_lastResponse!.lines[2].line, 'fat man');
    _lastResponse = null;
  }); // test end

  test('ImapResponseReader - response in one go', () {
    _lastResponses.clear();
    var reader = ImapResponseReader(_onMultipleImapResponse);
    var text =
        r'* FLAGS (\Answered \Flagged \Deleted \Seen \Draft $Forwarded $social $promotion $HasAttachment $HasNoAttachment $HasChat $MDNSent)'
        '\r\n'
        r'* OK [PERMANENTFLAGS (\Seen \Flagged)] Flags permitted'
        '\r\n'
        '* 512 EXISTS\r\n'
        '* OK [UNSEEN 12] First unseen.\r\n'
        '* OK [UIDVALIDITY 292] UIDs valid\r\n'
        '* 10 RECENT\r\n'
        '* OK [UIDNEXT 513] Predicted next UID\r\n'
        '* OK [HIGHESTMODSEQ 1299] Highest\r\n'
        'a4 OK [READ-WRITE] Select completed (0.088 + 0.000 + 0.087 secs).\r\n';
    reader.onData(_toUint8List(text));
    for (var response in _lastResponses) {
      expect(response.isSimple, true);
      expect(response.lines[0].isWithLiteral, false);
      expect(response.lines[0].literal, null);
      expect(response.first.line!.isNotEmpty, true);
    }
    var last = _lastResponses.last;
    expect(last.lines[0].line,
        'a4 OK [READ-WRITE] Select completed (0.088 + 0.000 + 0.087 secs).');
    // expect(_lastResponse.lines[0].line, r'* FLAGS (\Answered \Flagged \Deleted \Seen \Draft $Forwarded $social $promotion $HasAttachment $HasNoAttachment $HasChat $MDNSent)');
    // expect(_lastResponse.lines[1] != null, true);
    // expect(_lastResponse.lines[1].line, r"* OK [PERMANENTFLAGS (\Seen \Flagged)] Flags permitted");
    // expect(_lastResponse.lines[2] != null, true);
    // expect(_lastResponse.lines[2].isWithLiteral, false);
    // expect(_lastResponse.lines[2].line, '* 512 EXISTS');
  }); // test end

  test('ImapResponseReader - 2 responses in one delivery', () {
    _lastResponses.clear();
    var reader = ImapResponseReader(_onMultipleImapResponse);
    var text = '* 123 FETCH (FLAGS (){10}\r\n'
        '0123456789'
        ')\r\na002 OK Fetch completed\r\n';
    reader.onData(_toUint8List(text));
    expect(_lastResponses.length, 2);
    expect(_lastResponses[0].lines.length, 3);
    expect(_lastResponses[0].lines[1].line, '0123456789');
    expect(_lastResponses[1].isSimple, true);
    expect(_lastResponses[1].parseText, 'a002 OK Fetch completed');
  }); // test end

  test('ImapResponseReader - 2 responses in 3 deliveries', () {
    _lastResponses.clear();
    var reader = ImapResponseReader(_onMultipleImapResponse);
    var text = '* 123 FETCH (FLAGS (){10}\r\n'
        '012345';
    reader.onData(_toUint8List(text));
    expect(_lastResponses.length, 0);
    text = '6789 INTERNALDATE "2020-12-23 14:23")\r\na002 OK F';
    reader.onData(_toUint8List(text));
    reader.onData(_toUint8List('etch completed\r\n'));
    expect(_lastResponses.isNotEmpty, true);
    expect(_lastResponses[0].lines.length, 3);
    expect(_lastResponses[0].lines[1].line, '0123456789');
    expect(_lastResponses.length, 2);
    expect(_lastResponses[1].isSimple, true);
    expect(_lastResponses[1].parseText, 'a002 OK Fetch completed');
  }); // test end

  test('ImapResponseReader - 2 responses in 1 delivery', () {
    var input = '''* 3 FETCH (BODY[TEXT] {6}\r
Hi\r
\r
 BODY[HEADER.FIELDS (DATE)] {47}\r
Date: Tue, 21 Jan 2020 11:59:55 +0100 (CET)\r
\r
)\r
a3 OK Fetch completed (0.020 + 0.000 + 0.019 secs).\r
''';
    _lastResponses.clear();
    var reader = ImapResponseReader(_onMultipleImapResponse);
    reader.onData(_toUint8List(input));
    expect(_lastResponses.length, 2);
    expect(_lastResponses[0].lines[0].rawLine, '* 3 FETCH (BODY[TEXT] {6}');
    expect(_lastResponses[0].lines[1].line, 'Hi\r\n\r\n');
    expect(
        _lastResponses[0].lines[2].rawLine, ' BODY[HEADER.FIELDS (DATE)] {47}');
    expect(_lastResponses[0].lines[3].line,
        'Date: Tue, 21 Jan 2020 11:59:55 +0100 (CET)\r\n\r\n');
    expect(_lastResponses[0].lines[4].rawLine, ')');
    expect(_lastResponses[0].lines.length, 5);
    expect(_lastResponses[1].isSimple, true);
    expect(_lastResponses[1].parseText,
        'a3 OK Fetch completed (0.020 + 0.000 + 0.019 secs).');
  });

  test('ImapResponseReader - 2 responses in 1 delivery with 3 literals', () {
    var input = '''* 3 FETCH (BODY[TEXT] {6}\r
Hi\r
\r
 BODY[HEADER.FIELDS (DATE)] {47}\r
Date: Tue, 21 Jan 2020 11:59:55 +0100 (CET)\r
\r
 BODY[HEADER.FIELDS (MESSAGE-ID)] {36}\r
Message-ID: <3049329.2-302-12-2>\r
\r
)\r
a3 OK Fetch completed (0.020 + 0.000 + 0.019 secs).\r
''';
    _lastResponses.clear();
    var reader = ImapResponseReader(_onMultipleImapResponse);
    reader.onData(_toUint8List(input));
    expect(_lastResponses.length, 2);
    expect(_lastResponses[0].lines[0].rawLine, '* 3 FETCH (BODY[TEXT] {6}');
    expect(_lastResponses[0].lines[1].line, 'Hi\r\n\r\n');
    expect(
        _lastResponses[0].lines[2].rawLine, ' BODY[HEADER.FIELDS (DATE)] {47}');
    expect(_lastResponses[0].lines[3].line,
        'Date: Tue, 21 Jan 2020 11:59:55 +0100 (CET)\r\n\r\n');
    expect(_lastResponses[0].lines[4].rawLine,
        ' BODY[HEADER.FIELDS (MESSAGE-ID)] {36}');
    expect(_lastResponses[0].lines[5].line,
        'Message-ID: <3049329.2-302-12-2>\r\n\r\n');
    expect(_lastResponses[0].lines[6].rawLine, ')');
    expect(_lastResponses[0].lines.length, 7);
    expect(_lastResponses[1].isSimple, true);
    expect(_lastResponses[1].parseText,
        'a3 OK Fetch completed (0.020 + 0.000 + 0.019 secs).');
  });
}
