import 'package:enough_mail/imap/mailbox.dart';
import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/response_parser.dart';

import 'imap_response.dart';

/// Parses status responses
class StatusParser extends ResponseParser<Mailbox> {
  Mailbox box;

  StatusParser(this.box);

  @override
  Mailbox parse(ImapResponse details, Response<Mailbox> response) {
    return response.isOkStatus ? box : null;
  }

  @override
  bool parseUntagged(ImapResponse imapResponse, Response<Mailbox> response) {
    var details = imapResponse.parseText;
    if (details.startsWith('STATUS ')) {
      var listEntries = parseListEntries(details, details.indexOf('('), ')');
      for (var i = 0; i < listEntries.length; i += 2) {
        var entry = listEntries[i];
        var value = int.parse(listEntries[i + 1]);
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
            box.firstUnseenMessageSequenceId = value;
            break;
          default:
            print('unexpected STATUS: ' +
                entry +
                '=' +
                listEntries[i + 1] +
                '\nin ' +
                details);
        }
      }
      return true;
    } else {
      return super.parseUntagged(imapResponse, response);
    }
  }
}
