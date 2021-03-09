import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/all_parsers.dart';
import 'package:enough_mail/src/imap/imap_response_line.dart';
import 'package:enough_mail/src/imap/imap_response.dart';
import 'package:test/test.dart';

void main() {
  test('Search simple', () {
    var responseText = 'SEARCH 2 5 6 7 11 12 18 19 20 23';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = SearchParser(false);
    var response = Response<SearchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var ids = parser.parse(details, response).matchingSequence.toList();
    expect(ids, isNotNull);
    expect(ids, isNotEmpty);
    expect(ids, [2, 5, 6, 7, 11, 12, 18, 19, 20, 23]);
  });

  test('Search empty', () {
    var responseText = 'SEARCH';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = SearchParser(false);
    var response = Response<SearchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var ids = parser.parse(details, response).matchingSequence.toList();
    expect(ids, isNotNull);
    expect(ids, isEmpty);
  });

  test('Search with mod sequence', () {
    var responseText = 'SEARCH 2 5 6 7 11 12 18 19 20 23 (MODSEQ 917162500)';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = SearchParser(false);
    var response = Response<SearchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var result = parser.parse(details, response);
    var ids = result.matchingSequence.toList();
    expect(ids, isNotNull);
    expect(ids, isNotEmpty);
    expect(ids, [2, 5, 6, 7, 11, 12, 18, 19, 20, 23]);
    expect(result.highestModSequence, 917162500);
  });

  test('Extended search with MIN, MAX, COUNT', () {
    var responseText = 'ESEARCH (TAG "C1") MIN 2 MAX 47 COUNT 25';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = SearchParser(false, true);
    var response = Response<SearchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var result = parser.parse(details, response);
    expect(result.isExtended, true);
    expect(result.min, 2);
    expect(result.max, 47);
    expect(result.count, 25);
    expect(result.tag, 'C1');
  });

  test('Extended search with COUNT, ALL', () {
    var responseText = 'ESEARCH (TAG "C2") COUNT 25 ALL 2,4,10:18,24,25,26';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = SearchParser(false, true);
    var response = Response<SearchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var result = parser.parse(details, response);
    var ids = result.matchingSequence.toList();
    expect(result.isExtended, true);
    expect(result.count, 25);
    expect(result.tag, 'C2');
    expect(ids, [2, 4, 10, 11, 12, 13, 14, 15, 16, 17, 18, 24, 25, 26]);
  });

  test('Extended search with MIN, MAX, MODSEQ', () {
    var responseText = 'ESEARCH (TAG "C3") MIN 1 MAX 18 MODSEQ 123456';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = SearchParser(false, true);
    var response = Response<SearchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var result = parser.parse(details, response);
    result.matchingSequence.toList();
    expect(result.isExtended, true);
    expect(result.min, 1);
    expect(result.max, 18);
    expect(result.tag, 'C3');
    expect(result.highestModSequence, 123456);
  });

  test('Extended search with PARTIAL', () {
    var responseText = 'ESEARCH (TAG "C4") PARTIAL (1:10 3,5,7,9)';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = SearchParser(false, true);
    var response = Response<SearchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var result = parser.parse(details, response);
    var ids = result.matchingSequence.toList();
    expect(result.isExtended, true);
    expect(result.tag, 'C4');
    expect(result.partialRange, '1:10');
    expect(ids, [3, 5, 7, 9]);
  });
}
