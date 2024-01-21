import 'package:enough_mail/src/imap/response.dart';
import 'package:enough_mail/src/private/imap/all_parsers.dart';
import 'package:enough_mail/src/private/imap/imap_response.dart';
import 'package:enough_mail/src/private/imap/imap_response_line.dart';
import 'package:test/test.dart';
// cSpell:disable

void main() {
  test('Search simple', () {
    const responseText = 'SEARCH 2 5 6 7 11 12 18 19 20 23';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = SearchParser(isUidSearch: false);
    final response = Response<SearchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final ids = parser.parse(details, response)?.matchingSequence?.toList();
    expect(ids, isNotNull);
    expect(ids, isNotEmpty);
    expect(ids, [2, 5, 6, 7, 11, 12, 18, 19, 20, 23]);
  });

  test('Search empty', () {
    const responseText = 'SEARCH';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = SearchParser(isUidSearch: false);
    final response = Response<SearchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final ids = parser.parse(details, response)?.matchingSequence?.toList();
    expect(ids, isNotNull);
    expect(ids, isEmpty);
  });

  test('Search with mod sequence', () {
    const responseText = 'SEARCH 2 5 6 7 11 12 18 19 20 23 (MODSEQ 917162500)';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = SearchParser(isUidSearch: false);
    final response = Response<SearchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final result = parser.parse(details, response);
    final ids = result?.matchingSequence?.toList();
    expect(ids, isNotNull);
    expect(ids, isNotEmpty);
    expect(ids, [2, 5, 6, 7, 11, 12, 18, 19, 20, 23]);
    expect(result?.highestModSequence, 917162500);
  });

  test('Extended search with MIN, MAX, COUNT', () {
    const responseText = 'ESEARCH (TAG "C1") MIN 2 MAX 47 COUNT 25';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = SearchParser(isUidSearch: false, isExtended: true);
    final response = Response<SearchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final result = parser.parse(details, response);
    expect(result?.isExtended, true);
    expect(result?.min, 2);
    expect(result?.max, 47);
    expect(result?.count, 25);
    expect(result?.tag, 'C1');
  });

  test('Extended search with COUNT, ALL', () {
    const responseText = 'ESEARCH (TAG "C2") COUNT 25 ALL 2,4,10:18,24,25,26';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = SearchParser(isUidSearch: false, isExtended: true);
    final response = Response<SearchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final result = parser.parse(details, response);
    final ids = result?.matchingSequence?.toList();
    expect(result?.isExtended, true);
    expect(result?.count, 25);
    expect(result?.tag, 'C2');
    expect(ids, [2, 4, 10, 11, 12, 13, 14, 15, 16, 17, 18, 24, 25, 26]);
  });

  test('Extended search with MIN, MAX, MODSEQ', () {
    const responseText = 'ESEARCH (TAG "C3") MIN 1 MAX 18 MODSEQ 123456';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = SearchParser(isUidSearch: false, isExtended: true);
    final response = Response<SearchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final result = parser.parse(details, response);
    result?.matchingSequence?.toList();
    expect(result?.isExtended, true);
    expect(result?.min, 1);
    expect(result?.max, 18);
    expect(result?.tag, 'C3');
    expect(result?.highestModSequence, 123456);
  });

  test('Extended search with PARTIAL', () {
    const responseText = 'ESEARCH (TAG "C4") PARTIAL (1:10 3,5,7,9)';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = SearchParser(isUidSearch: false, isExtended: true);
    final response = Response<SearchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final result = parser.parse(details, response);
    final ids = result?.matchingSequence?.toList();
    expect(result?.isExtended, true);
    expect(result?.tag, 'C4');
    expect(result?.partialRange, '1:10');
    expect(ids, [3, 5, 7, 9]);
  });
}
