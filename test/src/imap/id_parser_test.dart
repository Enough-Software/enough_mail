import 'package:enough_mail/src/imap/id.dart';
import 'package:enough_mail/src/imap/response.dart';
import 'package:enough_mail/src/private/imap/id_parser.dart';
import 'package:enough_mail/src/private/imap/imap_response.dart';
import 'package:enough_mail/src/private/imap/imap_response_line.dart';
import 'package:test/test.dart';

void main() {
  test('NIL', () {
    final responseText = '* ID NIL';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = IdParser();
    final response = Response<Id>()..status = ResponseStatus.OK;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final id = parser.parse(details, response);
    expect(id, isNull);
  });

  test('Cyrus', () {
    final responseText =
        '* ID ("name" "Cyrus" "version" "1.5" "os" "sunos" "os-version" "5.5" "support-url" "mailto:cyrus-bugs+@andrew.cmu.edu")';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = IdParser();
    final response = Response<Id>()..status = ResponseStatus.OK;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final id = parser.parse(details, response);
    expect(id, isNotNull);
    expect(id!.name, 'Cyrus');
    expect(id.version, '1.5');
    expect(id.os, 'sunos');
    expect(id.osVersion, '5.5');
    expect(id.supportUrl, 'mailto:cyrus-bugs+@andrew.cmu.edu');
    expect(id.nonStandardFields, isEmpty);
  });

  test('Cyrus with Date', () {
    final responseText =
        '* ID ("name" "Cyrus" "version" "1.5" "os" "sunos" "os-version" "5.5" "support-url" "mailto:cyrus-bugs+@andrew.cmu.edu" "date" "Sun, 15 Aug 2021 22:45 +0000")';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = IdParser();
    final response = Response<Id>()..status = ResponseStatus.OK;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final id = parser.parse(details, response);
    expect(id, isNotNull);
    expect(id!.name, 'Cyrus');
    expect(id.version, '1.5');
    expect(id.os, 'sunos');
    expect(id.osVersion, '5.5');
    expect(id.supportUrl, 'mailto:cyrus-bugs+@andrew.cmu.edu');
    expect(id.nonStandardFields, isEmpty);
    expect(id.date?.toUtc(), DateTime.utc(2021, 08, 15, 22, 45));
  });
}
