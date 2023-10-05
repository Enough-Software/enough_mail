import '../../imap/mailbox.dart';
import '../../imap/response.dart';
import 'imap_response.dart';
import 'response_parser.dart';

/// Parses status responses
class StatusParser extends ResponseParser<Mailbox> {
  /// Creates a new parser
  StatusParser(this.box) : _regex = RegExp(r'(STATUS "[^"]+?" )(.*)');

  /// The current mailbox
  Mailbox box;

  final RegExp _regex;

  @override
  Mailbox? parse(ImapResponse imapResponse, Response<Mailbox> response) =>
      response.isOkStatus ? box : null;

  @override
  bool parseUntagged(ImapResponse imapResponse, Response<Mailbox>? response) {
    final details = imapResponse.parseText;
    if (details.startsWith('STATUS ')) {
      final startIndex = _findStartIndex(details);
      if (startIndex == -1) {
        return false;
      }
      final listEntries = parseListEntries(details, startIndex + 1, ')');
      if (listEntries == null) {
        return false;
      }
      for (var i = 0; i < listEntries.length; i += 2) {
        final entry = listEntries[i];
        final value = int.parse(listEntries[i + 1]);
        switch (entry) {
          case 'MESSAGES':
            box.messagesExists = value;
            break;
          case 'RECENT':
            box.messagesRecent = value;
            break;
          case 'UIDNEXT':
            box.uidNext = value;
            break;
          case 'UIDVALIDITY':
            box.uidValidity = value;
            break;
          case 'UNSEEN':
            box.messagesUnseen = value;
            break;
          default:
            print(
                'unexpected STATUS: $entry=${listEntries[i + 1]}\nin $details');
        }
      }
      return true;
    } else {
      return super.parseUntagged(imapResponse, response);
    }
  }

  int _findStartIndex(String details) {
    final matches = _regex.allMatches(details);
    if (matches.isNotEmpty && matches.first.groupCount == 2) {
      return matches.first.group(1)!.length;
    }
    return -1;
  }
}
