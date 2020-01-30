import 'package:enough_mail/src/imap/imap_response.dart';
import 'package:enough_mail/src/imap/imap_response_line.dart';
import 'package:test/test.dart';

void main() {
  test('ImapResponse.iterate() with simple response', () {
    var input = 'A001 OK FLAGS "seen" "new flag" DONE';
    var response = ImapResponse();
    var line = ImapResponseLine(input);
    response.add(line);
    var parsed = response.iterate();
    expect(parsed != null, true);
    expect(parsed.values != null, true);
    //print(parsed.values);
    expect(parsed.values.length, 6);
    expect(parsed.values[0].value, 'A001');
    expect(parsed.values[1].value, 'OK');
    expect(parsed.values[2].value, 'FLAGS');
    expect(parsed.values[3].value, 'seen');
    expect(parsed.values[4].value, 'new flag');
    expect(parsed.values[5].value, 'DONE');
  }); // test end

  test('ImapResponse.iterate() with complex response', () {
    var response = ImapResponse();
    response.add(ImapResponseLine('A001 OK FLAGS {10}'));
    response.add(ImapResponseLine('1"2 3 \r\n90'));
    response.add(ImapResponseLine('"DONE"'));
    var parsed = response.iterate();
    expect(parsed != null, true);
    expect(parsed.values != null, true);
    //print(parsed.values);
    expect(parsed.values.length, 5);
    expect(parsed.values[0].value, 'A001');
    expect(parsed.values[1].value, 'OK');
    expect(parsed.values[2].value, 'FLAGS');
    expect(parsed.values[3].value, '1"2 3 \r\n90');
    expect(parsed.values[4].value, 'DONE');
  }); // test end

  test('ImapResponse.iterate() with simple response and parentheses', () {
    var input = 'A001 OK FLAGS ("seen" "new flag")';
    var response = ImapResponse();
    var line = ImapResponseLine(input);
    response.add(line);
    var parsed = response.iterate();
    expect(parsed != null, true);
    expect(parsed.values != null, true);
    //print(parsed.values);
    expect(parsed.values.length, 3);
    expect(parsed.values[0].value, 'A001');
    expect(parsed.values[1].value, 'OK');
    expect(parsed.values[2].value, 'FLAGS');
    expect(parsed.values[2].children != null, true);
    expect(parsed.values[2].children.length, 2);
    expect(parsed.values[2].children[0].value, 'seen');
    expect(parsed.values[2].children[1].value, 'new flag');

    input = 'A001 OK FLAGS (seen new)';
    response = ImapResponse();
    line = ImapResponseLine(input);
    response.add(line);
    parsed = response.iterate();
    expect(parsed != null, true);
    expect(parsed.values != null, true);
    //print(parsed.values);
    expect(parsed.values.length, 3);
    expect(parsed.values[0].value, 'A001');
    expect(parsed.values[1].value, 'OK');
    expect(parsed.values[2].value, 'FLAGS');
    expect(parsed.values[2].children != null, true);
    expect(parsed.values[2].children.length, 2);
    expect(parsed.values[2].children[0].value, 'seen');
    expect(parsed.values[2].children[1].value, 'new');
  }); // test end

  test('ImapResponse.iterate() with simple response and empty parentheses', () {
    var input = 'A001 OK FLAGS () INTERNALDATE';
    var response = ImapResponse();
    var line = ImapResponseLine(input);
    response.add(line);
    var parsed = response.iterate();
    expect(parsed != null, true);
    expect(parsed.values != null, true);
    //print(parsed.values);
    expect(parsed.values.length, 4);
    expect(parsed.values[0].value, 'A001');
    expect(parsed.values[1].value, 'OK');
    expect(parsed.values[2].value, 'FLAGS');
    expect(parsed.values[2].children != null, true);
    expect(parsed.values[2].children.length, 0);
    expect(parsed.values[3].value, 'INTERNALDATE');

    input = 'A001 OK FLAGS ()';
    response = ImapResponse();
    line = ImapResponseLine(input);
    response.add(line);
    parsed = response.iterate();
    expect(parsed != null, true);
    expect(parsed.values != null, true);
    //print(parsed.values);
    expect(parsed.values.length, 3);
    expect(parsed.values[0].value, 'A001');
    expect(parsed.values[1].value, 'OK');
    expect(parsed.values[2].value, 'FLAGS');
    expect(parsed.values[2].children != null, true);
    expect(parsed.values[2].children.length, 0);
  }); // test end

  test('ImapResponse.iterate() with complex response and parentheses', () {
    var response = ImapResponse();
    response.add(ImapResponseLine('A001 OK FLAGS ({10}'));
    response.add(ImapResponseLine('1"2 3 \r\n90'));
    response.add(ImapResponseLine('seen)'));
    var parsed = response.iterate();
    expect(parsed != null, true);
    expect(parsed.values != null, true);
    //print(parsed.values);
    expect(parsed.values.length, 3);
    expect(parsed.values[0].value, 'A001');
    expect(parsed.values[1].value, 'OK');
    expect(parsed.values[2].value, 'FLAGS');
    expect(parsed.values[2].children != null, true);
    expect(parsed.values[2].children.length, 2);
    expect(parsed.values[2].children[0].value, '1"2 3 \r\n90');
    expect(parsed.values[2].children[1].value, 'seen');
  });

  test('ImapResponse.iterate() with simple response and double parentheses [1]',
      () {
    var input = 'A001 OK FLAGS (("seen" "new flag"))';
    var response = ImapResponse();
    var line = ImapResponseLine(input);
    response.add(line);
    var parsed = response.iterate();
    expect(parsed != null, true);
    expect(parsed.values != null, true);
    //print(parsed.values);
    expect(parsed.values.length, 3);
    expect(parsed.values[0].value, 'A001');
    expect(parsed.values[1].value, 'OK');
    expect(parsed.values[2].value, 'FLAGS');
    expect(parsed.values[2].children != null, true);
    expect(parsed.values[2].children[0].children.length, 2);
    expect(parsed.values[2].children[0].children[0].value, 'seen');
    expect(parsed.values[2].children[0].children[1].value, 'new flag');
  });
  test('ImapResponse.iterate() with simple response and double parentheses [2]',
      () {
    var input = 'A001 OK FLAGS ((seen new))';
    var response = ImapResponse();
    var line = ImapResponseLine(input);
    response.add(line);
    var parsed = response.iterate();
    expect(parsed != null, true);
    expect(parsed.values != null, true);
    //print(parsed.values);
    expect(parsed.values.length, 3);
    expect(parsed.values[0].value, 'A001');
    expect(parsed.values[1].value, 'OK');
    expect(parsed.values[2].value, 'FLAGS');
    expect(parsed.values[2].children != null, true);
    expect(parsed.values[2].children.length, 1);
    expect(parsed.values[2].children[0].children.length, 2);
    expect(parsed.values[2].children[0].children[0].value, 'seen');
    expect(parsed.values[2].children[0].children[1].value, 'new');
  }); // test end

  test(
      'ImapResponse.iterate() with simple response and emtpty Flags parentheses',
      () {
    var input = 'A001 OK FLAGS () INTERNALDATE';
    var response = ImapResponse();
    var line = ImapResponseLine(input);
    response.add(line);
    var parsed = response.iterate();
    expect(parsed != null, true);
    expect(parsed.values != null, true);
    //print(parsed.values);
    expect(parsed.values.length, 4);
    expect(parsed.values[0].value, 'A001');
    expect(parsed.values[1].value, 'OK');
    expect(parsed.values[2].value, 'FLAGS');
    expect(parsed.values[2].children != null, true);
    expect(parsed.values[2].children.length, 0);
    expect(parsed.values[3].value, 'INTERNALDATE');
  }); // test end

  test('ImapResponse.iterate() with complex real world response', () {
    var response = ImapResponse();
    response.add(ImapResponseLine(
        '* 123 FETCH (FLAGS () INTERNALDATE "25-Oct-2019 16:35:31 +0200" '
        'RFC822.SIZE 15320 ENVELOPE ("Fri, 25 Oct 2019 16:35:28 +0200 (CEST)" {61}'));
    expect(response.first.literal, 61);
    response.add(ImapResponseLine(
        'New appointment: SoW (x2) for rebranding of App & Mobile Apps'));
    response.add(ImapResponseLine(
        '(("=?UTF-8?Q?Sch=C3=B6n=2C_Rob?=" NIL "rob.schoen" "domain.com")) (("=?UTF-8?Q?Sch=C3=B6n=2C_'
        'Rob?=" NIL "rob.schoen" "domain.com")) (("=?UTF-8?Q?Sch=C3=B6n=2C_Rob?=" NIL "rob.schoen" '
        '"domain.com")) (("Alice Dev" NIL "alice.dev" "domain.com")) NIL NIL "<Appointment.59b0d625-afaf-4fc6'
        '-b845-4b0fce126730@domain.com>" "<130499090.797.1572014128349@product-gw2.domain.com>") BODY (("text" "plain" '
        '("charset" "UTF-8") NIL NIL "quoted-printable" 1289 53)("text" "html" ("charset" "UTF-8") NIL NIL "quoted-printable" '
        '7496 302) "alternative"))'));
    var parsed = response.iterate();
    expect(parsed != null, true);
    expect(parsed.values != null, true);
    //print(parsed.values);
    expect(parsed.values.length, 3);
    expect(parsed.values[0].value, '*');
    expect(parsed.values[1].value, '123');
    expect(parsed.values[2].value, 'FETCH');
    var values = parsed.values[2].children;
    expect(values != null, true);
    expect(values[0].value, 'FLAGS');
    expect(values[0].children != null, true);
    expect(values[0].children.length, 0);
    expect(values[1].value, 'INTERNALDATE');
    expect(values[2].value, '25-Oct-2019 16:35:31 +0200');
    expect(values[3].value, 'RFC822.SIZE');
    expect(values[4].value, '15320');
    expect(values[5].value, 'ENVELOPE');
    values = values[5].children;
    expect(values != null, true);
    expect(values[0].value, 'Fri, 25 Oct 2019 16:35:28 +0200 (CEST)');
    expect(values[1].value,
        'New appointment: SoW (x2) for rebranding of App & Mobile Apps');
    expect(values[2].value, null);
    expect(values[2].children != null, true);
    expect(values[2].children.length, 1);
    expect(values[2].children[0].children.length, 4);
    expect(values[2].children[0].children[0].value,
        '=?UTF-8?Q?Sch=C3=B6n=2C_Rob?=');
    expect(values[2].children[0].children[1].value, 'NIL');
    expect(values[2].children[0].children[2].value, 'rob.schoen');
    expect(values[2].children[0].children[3].value, 'domain.com');

    expect(values[3].value, null);
    expect(values[3].children != null, true);
    expect(values[3].children.length, 1);
    expect(values[3].children[0].children.length, 4);
    expect(values[3].children[0].children[0].value,
        '=?UTF-8?Q?Sch=C3=B6n=2C_Rob?=');
    expect(values[3].children[0].children[1].value, 'NIL');
    expect(values[3].children[0].children[2].value, 'rob.schoen');
    expect(values[3].children[0].children[3].value, 'domain.com');

    expect(values[4].value, null);
    expect(values[4].children != null, true);
    expect(values[4].children.length, 1);
    expect(values[4].children[0].children.length, 4);
    expect(values[4].children[0].children[0].value,
        '=?UTF-8?Q?Sch=C3=B6n=2C_Rob?=');
    expect(values[4].children[0].children[1].value, 'NIL');
    expect(values[4].children[0].children[2].value, 'rob.schoen');
    expect(values[4].children[0].children[3].value, 'domain.com');

    expect(values[5].value, null);
    expect(values[5].children != null, true);
    expect(values[5].children[0].children.length, 4);
    expect(values[5].children[0].children[0].value, 'Alice Dev');
    expect(values[5].children[0].children[1].value, 'NIL');
    expect(values[5].children[0].children[2].value, 'alice.dev');
    expect(values[5].children[0].children[3].value, 'domain.com');

    expect(values[6].value, 'NIL');
    expect(values[7].value, 'NIL');

    expect(values[8].value,
        '<Appointment.59b0d625-afaf-4fc6-b845-4b0fce126730@domain.com>');
    expect(values[9].value,
        '<130499090.797.1572014128349@product-gw2.domain.com>');

    values = parsed.values[2].children;
    expect(values[6].value, 'BODY');
    expect(values[6].children != null, true);
    expect(values[6].children.length, 3);
    var value = values[6].children[0];
    expect(value.value, null);
    expect(value.children != null, true);
    expect(value.children.length, 8);
    expect(value.children[0].value, 'text');
    expect(value.children[1].value, 'plain');
    expect(value.children[2].children != null, true);
    expect(value.children[2].children[0].value, 'charset');
    expect(value.children[2].children[1].value, 'UTF-8');
    expect(value.children[3].value, 'NIL');
    expect(value.children[4].value, 'NIL');
    expect(value.children[5].value, 'quoted-printable');
    expect(value.children[6].value, '1289');
    expect(value.children[7].value, '53');

    value = values[6].children[1];
    expect(value.value, null);
    expect(value.children != null, true);
    expect(value.children.length, 8);
    expect(value.children[0].value, 'text');
    expect(value.children[1].value, 'html');
    expect(value.children[2].children != null, true);
    expect(value.children[2].children[0].value, 'charset');
    expect(value.children[2].children[1].value, 'UTF-8');
    expect(value.children[3].value, 'NIL');
    expect(value.children[4].value, 'NIL');
    expect(value.children[5].value, 'quoted-printable');
    expect(value.children[6].value, '7496');
    expect(value.children[7].value, '302');

    expect(values[6].children[2].value, 'alternative');
  }); // test end

  test('ImapResponse.iterate() with HEADER.FIELDS response', () {
    var response = ImapResponse();
    response.add(
        ImapResponseLine('16 FETCH (BODY[HEADER.FIELDS (REFERENCES)] {50}'));
    response.add(
        ImapResponseLine(r'References: <chat$1579598212023314@russyl.com>'));
    response.add(ImapResponseLine(')'));
    var parsed = response.iterate();
    expect(parsed != null, true);
    expect(parsed.values != null, true);
    //print(parsed.values);
    expect(parsed.values.length, 2);
    expect(parsed.values[0].value, '16');
    expect(parsed.values[1].value, 'FETCH');
    expect(parsed.values[1].children != null, true);
    expect(parsed.values[1].children.length, 2);
    expect(
        parsed.values[1].children[0].value, 'BODY[HEADER.FIELDS (REFERENCES)]');
    expect(parsed.values[1].children[1].value,
        r'References: <chat$1579598212023314@russyl.com>');
  }); // test end

  test('ImapResponse.iterate() with HEADER.FIELDS empty response', () {
    var response = ImapResponse();
    response.add(
        ImapResponseLine('16 FETCH (BODY[HEADER.FIELDS (REFERENCES)] {2}'));
    response.add(ImapResponseLine('\r\n'));
    response.add(ImapResponseLine(')'));
    var parsed = response.iterate();
    expect(parsed != null, true);
    expect(parsed.values != null, true);
    //print(parsed.values);
    expect(parsed.values.length, 2);
    expect(parsed.values[0].value, '16');
    expect(parsed.values[1].value, 'FETCH');
    expect(parsed.values[1].children != null, true);
    expect(parsed.values[1].children.length, 2);
    expect(
        parsed.values[1].children[0].value, 'BODY[HEADER.FIELDS (REFERENCES)]');
    expect(parsed.values[1].children[1].value, '\r\n');
  }); // test end

  test('ImapResponse.iterate() with HEADER.FIELDS.NOT response', () {
    var response = ImapResponse();
    response.add(ImapResponseLine(
        '16 FETCH (BODY[HEADER.FIELDS.NOT (REFERENCES)] {42}'));
    response
        .add(ImapResponseLine('From: Shirley <Shirley.Jackson@domain.com>'));
    response.add(ImapResponseLine(')'));
    var parsed = response.iterate();
    expect(parsed != null, true);
    expect(parsed.values != null, true);
    //print(parsed.values);
    expect(parsed.values.length, 2);
    expect(parsed.values[0].value, '16');
    expect(parsed.values[1].value, 'FETCH');
    expect(parsed.values[1].children != null, true);
    expect(parsed.values[1].children.length, 2);
    expect(parsed.values[1].children[0].value,
        'BODY[HEADER.FIELDS.NOT (REFERENCES)]');
    expect(parsed.values[1].children[1].value,
        'From: Shirley <Shirley.Jackson@domain.com>');
  }); // test end

  test('ImapResponse.iterate() with HEADER.FIELDS.NOT empty response', () {
    var response = ImapResponse();
    response.add(ImapResponseLine(
        '16 FETCH (BODY[HEADER.FIELDS.NOT (REFERENCES DATE FROM)] {2}'));
    response.add(ImapResponseLine('\r\n'));
    response.add(ImapResponseLine(')'));
    var parsed = response.iterate();
    expect(parsed != null, true);
    expect(parsed.values != null, true);
    //print(parsed.values);
    expect(parsed.values.length, 2);
    expect(parsed.values[0].value, '16');
    expect(parsed.values[1].value, 'FETCH');
    expect(parsed.values[1].children != null, true);
    expect(parsed.values[1].children.length, 2);
    expect(parsed.values[1].children[0].value,
        'BODY[HEADER.FIELDS.NOT (REFERENCES DATE FROM)]');
    expect(parsed.values[1].children[1].value, '\r\n');
  }); // test end

  test('ImapResponse.iterate() with TO Envelope part', () {
    var response = ImapResponse();
    response.add(ImapResponseLine(
        'ENVELOPE ("TEST" (("Jared" NIL "jared" "domain.com")) (("Ina" NIL "ina" "domain1.com")("Todd" NIL "todd" "domain2.com")("Dom" NIL "dom" "domain3.com")) NIL NIL NIL "<1526109049.228971.1564473376037@my.domain.com>")'));
    var parsed = response.iterate();
    expect(parsed != null, true);
    expect(parsed.values != null, true);
    //print(parsed.values);
    expect(parsed.values.length, 1);
    expect(parsed.values[0].value, 'ENVELOPE');
    expect(parsed.values[0].children != null, true);
    expect(parsed.values[0].children.length, 7);
    expect(parsed.values[0].children[0].value, 'TEST');
    expect(parsed.values[0].children[1].value, null);
    expect(parsed.values[0].children[1].children != null, true);
    expect(parsed.values[0].children[1].children.length, 1);
    expect(parsed.values[0].children[1].children[0].children != null, true);
    expect(parsed.values[0].children[1].children[0].children.length, 4);
    expect(parsed.values[0].children[1].children[0].children[0].value, 'Jared');
    expect(parsed.values[0].children[1].children[0].children[1].value, 'NIL');
    expect(parsed.values[0].children[1].children[0].children[2].value, 'jared');
    expect(parsed.values[0].children[1].children[0].children[3].value,
        'domain.com');
    expect(parsed.values[0].children[2].value, null);
    expect(parsed.values[0].children[2].children != null, true);
    expect(parsed.values[0].children[2].children.length, 3);
    expect(parsed.values[0].children[2].children[0].children != null, true);
    expect(parsed.values[0].children[2].children[0].children.length, 4);
    expect(parsed.values[0].children[2].children[0].children[0].value, 'Ina');
    expect(parsed.values[0].children[2].children[0].children[1].value, 'NIL');
    expect(parsed.values[0].children[2].children[0].children[2].value, 'ina');
    expect(parsed.values[0].children[2].children[0].children[3].value,
        'domain1.com');
    expect(parsed.values[0].children[2].children[1].children != null, true);
    expect(parsed.values[0].children[2].children[1].children.length, 4);
    expect(parsed.values[0].children[2].children[1].children[0].value, 'Todd');
    expect(parsed.values[0].children[2].children[1].children[1].value, 'NIL');
    expect(parsed.values[0].children[2].children[1].children[2].value, 'todd');
    expect(parsed.values[0].children[2].children[1].children[3].value,
        'domain2.com');
  }); // test end

  test('ImapResponse.iterate() with nested BODY part', () {
    var response = ImapResponse();
    response.add(ImapResponseLine(
        'BODY (("TEXT" "PLAIN" ("CHARSET" "US-ASCII") NIL NIL "7BIT" 1152 23)("TEXT" "PLAIN" ("CHARSET" "US-ASCII" "NAME" "cc.diff") "<960723163407.20117h@cac.washington.edu>" "Compiler diff" "BASE64" 4554 73) "MIXED")'));
    var parsed = response.iterate();
    expect(parsed != null, true);
    expect(parsed.values != null, true);
    expect(parsed.values.length, 1);
    expect(parsed.values[0].children.length, 3);
    expect(parsed.values[0].children[0].children.length, 8);
    expect(parsed.values[0].children[0].children[0].value, 'TEXT');
    expect(parsed.values[0].children[0].children[1].value, 'PLAIN');
    expect(parsed.values[0].children[0].children[2].children.length, 2);
    expect(
        parsed.values[0].children[0].children[2].children[0].value, 'CHARSET');
    expect(
        parsed.values[0].children[0].children[2].children[1].value, 'US-ASCII');
    expect(parsed.values[0].children[0].children[3].value, 'NIL');
    expect(parsed.values[0].children[0].children[4].value, 'NIL');
    expect(parsed.values[0].children[0].children[5].value, '7BIT');
    expect(parsed.values[0].children[0].children[6].value, '1152');
    expect(parsed.values[0].children[0].children[7].value, '23');
    expect(parsed.values[0].children[1].children.length, 8);
    expect(parsed.values[0].children[1].children[0].value, 'TEXT');
    expect(parsed.values[0].children[1].children[1].value, 'PLAIN');
    expect(parsed.values[0].children[1].children[2].children.length, 4);
    expect(
        parsed.values[0].children[1].children[2].children[0].value, 'CHARSET');
    expect(
        parsed.values[0].children[1].children[2].children[1].value, 'US-ASCII');
    expect(parsed.values[0].children[1].children[2].children[2].value, 'NAME');
    expect(
        parsed.values[0].children[1].children[2].children[3].value, 'cc.diff');
    expect(parsed.values[0].children[1].children[3].value,
        '<960723163407.20117h@cac.washington.edu>');
    expect(parsed.values[0].children[1].children[4].value, 'Compiler diff');
    expect(parsed.values[0].children[1].children[5].value, 'BASE64');
    expect(parsed.values[0].children[1].children[6].value, '4554');
    expect(parsed.values[0].children[1].children[7].value, '73');

    expect(parsed.values[0].children[2].value, 'MIXED');
  });
}
