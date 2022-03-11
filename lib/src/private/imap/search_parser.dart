import '../../imap/message_sequence.dart';
import '../../imap/response.dart';
import 'imap_response.dart';
import 'response_parser.dart';

/// Parses search responses
class SearchParser extends ResponseParser<SearchImapResult> {
  /// Creates a new search parser
  SearchParser({required this.isUidSearch, this.isExtended = false});

  /// Is this a UID-based search?
  final bool isUidSearch;

  /// The IDs
  List<int> ids = <int>[];

  /// The highest modification sequence
  int? highestModSequence;

  /// Is an extended response expected?
  final bool isExtended;

  /// Reference tag for the current extended search untagged response
  String? tag;

  /// minimum search ID
  int? min;

  /// maximum search ID
  int? max;

  /// number of search results
  int? count;

  /// Partial range
  String? partialRange;

  @override
  SearchImapResult? parse(
      ImapResponse imapResponse, Response<SearchImapResult> response) {
    if (response.isOkStatus) {
      final result = SearchImapResult()
        // Force the sorting of the resulting sequence set
        ..matchingSequence =
            (MessageSequence.fromIds(ids, isUid: isUidSearch)..sort())
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
      ImapResponse imapResponse, Response<SearchImapResult>? response) {
    final details = imapResponse.parseText;
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
    final listEntries = parseListEntries(details, 'SEARCH '.length, null);
    if (listEntries == null) {
      return false;
    }
    for (var i = 0; i < listEntries.length; i++) {
      final entry = listEntries[i];
      if (entry == '(MODSEQ') {
        i++;
        final seqEntry = listEntries[i];
        final modSeqText = seqEntry.substring(0, seqEntry.length - 1);
        highestModSequence = int.tryParse(modSeqText);
      } else {
        final id = int.tryParse(entry);
        if (id != null) {
          ids.add(id);
        }
      }
    }
    return true;
  }

  bool _parseExtendedDetails(String details) {
    final listEntries = parseListEntries(details, 'ESEARCH '.length, null);
    if (listEntries == null) {
      return false;
    }
    for (var i = 0; i < listEntries.length; i++) {
      final entry = listEntries[i];
      if (entry == '(TAG') {
        i++;
        tag = listEntries[i].substring(1, listEntries[i].length - 2);
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
        final seq =
            MessageSequence.parse(listEntries[i], isUidSequence: isUidSearch);
        if (!seq.isNil) {
          ids = seq.toList();
        }
      } else if (entry == 'MODSEQ') {
        i++;
        highestModSequence = int.tryParse(listEntries[i]);
      } else if (entry == 'PARTIAL') {
        i++;
        partialRange = listEntries[i].substring(1);
        i++;
        final seq = MessageSequence.parse(
            listEntries[i].substring(0, listEntries[i].length - 1),
            isUidSequence: isUidSearch);
        if (!seq.isNil) {
          ids = seq.toList();
        }
      }
    }
    return true;
  }
}
