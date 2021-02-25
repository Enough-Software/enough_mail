import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/response_parser.dart';

import 'imap_response.dart';

/// Parses search responses
class SearchParser extends ResponseParser<SearchImapResult> {
  final bool isUidSearch;
  List<int> ids = <int>[];
  int highestModSequence;

  final bool isExtended;
  // Reference tag for the current extended search untagged response
  String tag;
  int min;
  int max;
  int count;

  String partialRange;

  SearchParser(this.isUidSearch, [this.isExtended = false]);

  @override
  SearchImapResult parse(
      ImapResponse details, Response<SearchImapResult> response) {
    if (response.isOkStatus) {
      var result = SearchImapResult()
        // Force the sorting of the resulting sequence set
        ..matchingSequence =
            (MessageSequence.fromIds(ids, isUid: isUidSearch)..sorted())
        ..highestModSequence = highestModSequence
        ..isExtended = isExtended
        ..tag = tag
        ..min = min
        ..max = max
        ..count = count
        ..partialRange = partialRange;
      return result;
    }
    return null;
  }

  @override
  bool parseUntagged(
      ImapResponse imapResponse, Response<SearchImapResult> response) {
    var details = imapResponse.parseText;
    if (details.startsWith('SEARCH ')) {
      return _parseSimpleDetails(details);
    } else if (details.startsWith('ESEARCH ')) {
      return _parseExtendedDetails(details);
    } else if (details == 'SEARCH' || details == 'ESEARCH') {
      // this is an empty search result
      return true;
    } else {
      return super.parseUntagged(imapResponse, response);
    }
  }

  bool _parseSimpleDetails(String details) {
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
  }

  bool _parseExtendedDetails(String details) {
    var listEntries = parseListEntries(details, 'ESEARCH '.length, null);
    for (var i = 0; i < listEntries.length; i++) {
      var entry = listEntries[i];
      if (entry == '(TAG') {
        i++;
        entry = listEntries[i];
        tag = entry.substring(1, entry.length - 2);
      } else if (entry == 'UID') {
        // Included for completeness.
      } else if (entry == 'MIN') {
        i++;
        min = int.tryParse(listEntries[i]);
      } else if (entry == 'MAX') {
        i++;
        max = int.tryParse(listEntries[i]);
      } else if (entry == 'COUNT') {
        i++;
        count = int.tryParse(listEntries[i]);
      } else if (entry == 'ALL') {
        i++;
        // The result is always sequence-set.
        var seq =
            MessageSequence.parse(listEntries[i], isUidSequence: isUidSearch);
        if (seq.isNil) {
          ids = seq.toList();
        }
      } else if (entry == 'MODSEQ') {
        i++;
        highestModSequence = int.tryParse(listEntries[i]);
      } else if (entry == 'PARTIAL') {
        i++;
        partialRange = listEntries[i];
        i++;
        var seq =
            MessageSequence.parse(listEntries[i], isUidSequence: isUidSearch);
        if (seq.isNil) {
          ids = seq.toList();
        }
      }
    }
    return true;
  }
}
