import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/imap_response.dart';
import 'package:enough_mail/src/imap/imap_response_line.dart';
import 'package:enough_mail/src/imap/sort_parser.dart';
import 'package:test/test.dart';

void main() {
  test('Sort simple', () {
    var responseText = 'SORT 7 5 8 18 19 20 34 33 32 30 10';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = SortParser(false);
    var response = Response<SortImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var ids = parser.parse(details, response).matchingSequence.toList();
    expect(ids, isNotNull);
    expect(ids, isNotEmpty);
    expect(ids, [7, 5, 8, 18, 19, 20, 34, 33, 32, 30, 10]);
  });

  test('Sort empty', () {
    var responseText = 'SORT';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = SortParser(false);
    var response = Response<SortImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var ids = parser.parse(details, response).matchingSequence.toList();
    expect(ids, isNotNull);
    expect(ids, isEmpty);
  });

  test('Sort with mod sequence', () {
    var responseText = 'SORT 7 5 8 18 19 20 34 33 32 30 10 (MODSEQ 917162500)';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = SortParser(false);
    var response = Response<SortImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var result = parser.parse(details, response);
    var ids = parser.parse(details, response).matchingSequence.toList();
    expect(ids, isNotNull);
    expect(ids, isNotEmpty);
    expect(ids, [7, 5, 8, 18, 19, 20, 34, 33, 32, 30, 10]);
    expect(result.highestModSequence, 917162500);
  });

  test('Extended sort with MIN, MAX, COUNT', () {
    var responseText = 'ESEARCH (TAG "C1") MIN 2 MAX 47 COUNT 25';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = SortParser(false, true);
    var response = Response<SortImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var result = parser.parse(details, response);
    expect(result.isExtended, true);
    expect(result.tag, 'C1');
    expect(result.min, 2);
    expect(result.max, 47);
    expect(result.count, 25);
  });

  test('Extended sort with COUNT, ALL', () {
    var responseText =
        'ESEARCH (TAG "C2") ALL 7,5,8,18:20,34,33,32,30,10 COUNT 11';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = SortParser(false, true);
    var response = Response<SortImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var result = parser.parse(details, response);
    var ids = result.matchingSequence.toList();
    expect(result.isExtended, true);
    expect(result.tag, 'C2');
    expect(result.count, 11);
    expect(ids.length, result.count);
    expect(ids, [7, 5, 8, 18, 19, 20, 34, 33, 32, 30, 10]);
  });

  test('Extended sort with MIN, MAX, MODSEQ', () {
    var responseText = 'ESEARCH (TAG "C3") MIN 2 MAX 47 MODSEQ 123456';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = SortParser(false, true);
    var response = Response<SortImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var result = parser.parse(details, response);
    expect(result.isExtended, true);
    expect(result.tag, 'C3');
    expect(result.min, 2);
    expect(result.max, 47);
    expect(result.highestModSequence, 123456);
  });

  test('Extended sort with PARTIAL', () {
    var responseText = 'ESEARCH (TAG "C4") PARTIAL (1:10 3,9,7,5)';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = SortParser(false, true);
    var response = Response<SortImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var result = parser.parse(details, response);
    var ids = result.matchingSequence.toList();
    expect(result.isExtended, true);
    expect(result.tag, 'C4');
    expect(result.partialRange, '1:10');
    expect(ids, [3, 9, 7, 5]);
  });
}
