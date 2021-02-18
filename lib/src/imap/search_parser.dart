import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/response_parser.dart';

import 'imap_response.dart';

/// Parses search responses
class SearchParser extends ResponseParser<SearchImapResult> {
  final bool isUidSearch;
  List<int> ids = <int>[];
  int highestModSequence;

  SearchParser(this.isUidSearch);

  @override
  SearchImapResult parse(
      ImapResponse details, Response<SearchImapResult> response) {
    if (response.isOkStatus) {
      var result = SearchImapResult()
        // Force the sorting of the resulting sequence set
        ..matchingSequence =
            (MessageSequence.fromIds(ids, isUid: isUidSearch)..sorted())
        ..highestModSequence = highestModSequence;
      return result;
    }
    return null;
  }

  @override
  bool parseUntagged(
      ImapResponse imapResponse, Response<SearchImapResult> response) {
    var details = imapResponse.parseText;
    if (details.startsWith('SEARCH ')) {
      var listEntries = parseListEntries(details, 'SEARCH '.length, null);
      for (var i = 0; i < listEntries.length; i++) {
        var entry = listEntries[i];
        if (entry == '(MODSEQ') {
          i++;
          entry = listEntries[i];
          var modSeqText = entry.substring(0, entry.length - 1);
          highestModSequence = int.tryParse(modSeqText);
        } else {
          var id = int.tryParse(entry);
          if (id != null) {
            ids.add(id);
          }
        }
      }
      return true;
    } else if (details == 'SEARCH') {
      // this is an empty search result
      return true;
    } else {
      return super.parseUntagged(imapResponse, response);
    }
  }
}
