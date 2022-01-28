import '../../imap/mailbox.dart';
import '../../imap/response.dart';
import 'imap_response.dart';
import 'response_parser.dart';

/// Parses status responses
class StatusParser extends ResponseParser<Mailbox> {
  /// Creates a new parser
  StatusParser(this.box);

  /// The current mailbox
  Mailbox box;

  @override
  Mailbox? parse(ImapResponse imapResponse, Response<Mailbox> response) =>
      response.isOkStatus ? box : null;

  @override
  bool parseUntagged(ImapResponse imapResponse, Response<Mailbox>? response) {
    final details = imapResponse.parseText;
    if (details.startsWith('STATUS ')) {
      final startIndex = details.indexOf('(');
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
}
