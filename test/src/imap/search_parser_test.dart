import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/imap/all_parsers.dart';
import 'package:enough_mail/src/imap/imap_response_line.dart';
import 'package:enough_mail/src/imap/imap_response.dart';
import 'package:test/test.dart';

void main() {
  test('Search simple', () {
    var responseText = 'SEARCH 2 5 6 7 11 12 18 19 20 23';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = SearchParser();
    var response = Response<SearchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var ids = parser.parse(details, response).ids;
    expect(ids, isNotNull);
    expect(ids, isNotEmpty);
    expect(ids, [2, 5, 6, 7, 11, 12, 18, 19, 20, 23]);
  });

  test('Search empty', () {
    var responseText = 'SEARCH';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = SearchParser();
    var response = Response<SearchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var ids = parser.parse(details, response).ids;
    expect(ids, isNotNull);
    expect(ids, isEmpty);
  });

  test('Search with mod sequence', () {
    var responseText = 'SEARCH 2 5 6 7 11 12 18 19 20 23 (MODSEQ 917162500)';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = SearchParser();
    var response = Response<SearchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var result = parser.parse(details, response);
    var ids = result.ids;
    expect(ids, isNotNull);
    expect(ids, isNotEmpty);
    expect(ids, [2, 5, 6, 7, 11, 12, 18, 19, 20, 23]);
    expect(result.highestModSequence, 917162500);
  });
}
