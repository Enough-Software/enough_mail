import 'package:enough_mail/src/imap/response.dart';
import 'package:enough_mail/src/private/imap/imap_response.dart';
import 'package:enough_mail/src/private/imap/imap_response_line.dart';
import 'package:enough_mail/src/private/imap/sort_parser.dart';
import 'package:test/test.dart';
// cSpell:disable

void main() {
  test('Sort simple', () {
    const responseText = 'SORT 7 5 8 18 19 20 34 33 32 30 10';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = SortParser(isUidSort: false);
    final response = Response<SortImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final ids = parser.parse(details, response)?.matchingSequence?.toList();
    expect(ids, isNotNull);
    expect(ids, isNotEmpty);
    expect(ids, [7, 5, 8, 18, 19, 20, 34, 33, 32, 30, 10]);
  });

  test('Sort empty', () {
    const responseText = 'SORT';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = SortParser(isUidSort: false);
    final response = Response<SortImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final ids = parser.parse(details, response)?.matchingSequence?.toList();
    expect(ids, isNotNull);
    expect(ids, isEmpty);
  });

  test('Sort with mod sequence', () {
    const responseText =
        'SORT 7 5 8 18 19 20 34 33 32 30 10 (MODSEQ 917162500)';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = SortParser(isUidSort: false);
    final response = Response<SortImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final result = parser.parse(details, response);
    final ids = parser.parse(details, response)?.matchingSequence?.toList();
    expect(ids, isNotNull);
    expect(ids, isNotEmpty);
    expect(ids, [7, 5, 8, 18, 19, 20, 34, 33, 32, 30, 10]);
    expect(result?.highestModSequence, 917162500);
  });

  test('Extended sort with MIN, MAX, COUNT', () {
    const responseText = 'ESEARCH (TAG "C1") MIN 2 MAX 47 COUNT 25';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = SortParser(isUidSort: false, isExtended: true);
    final response = Response<SortImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final result = parser.parse(details, response);
    expect(result?.isExtended, true);
    expect(result?.tag, 'C1');
    expect(result?.min, 2);
    expect(result?.max, 47);
    expect(result?.count, 25);
  });

  test('Extended sort with COUNT, ALL', () {
    const responseText =
        'ESEARCH (TAG "C2") ALL 7,5,8,18:20,34,33,32,30,10 COUNT 11';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = SortParser(isUidSort: false, isExtended: true);
    final response = Response<SortImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final result = parser.parse(details, response);
    final ids = result?.matchingSequence?.toList();
    expect(result?.isExtended, true);
    expect(result?.tag, 'C2');
    expect(result?.count, 11);
    expect(ids?.length, result?.count);
    expect(ids, [7, 5, 8, 18, 19, 20, 34, 33, 32, 30, 10]);
  });

  test('Extended sort with MIN, MAX, MODSEQ', () {
    const responseText = 'ESEARCH (TAG "C3") MIN 2 MAX 47 MODSEQ 123456';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = SortParser(isUidSort: false, isExtended: true);
    final response = Response<SortImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final result = parser.parse(details, response);
    expect(result?.isExtended, true);
    expect(result?.tag, 'C3');
    expect(result?.min, 2);
    expect(result?.max, 47);
    expect(result?.highestModSequence, 123456);
  });

  test('Extended sort with PARTIAL', () {
    const responseText = 'ESEARCH (TAG "C4") PARTIAL (1:10 3,9,7,5)';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = SortParser(isUidSort: false, isExtended: true);
    final response = Response<SortImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final result = parser.parse(details, response);
    final ids = result?.matchingSequence?.toList();
    expect(result?.isExtended, true);
    expect(result?.tag, 'C4');
    expect(result?.partialRange, '1:10');
    expect(ids, [3, 9, 7, 5]);
  });
}
