import 'package:enough_mail/imap/mailbox.dart';
import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/response_parser.dart';

import 'imap_response.dart';

class SelectParser extends ResponseParser<Mailbox> {
  Mailbox box;

  SelectParser(this.box);

  @override
  Mailbox parse(ImapResponse details, Response<Mailbox> response) {
    if (box != null) {
      box.isReadWrite = details.parseText.startsWith('OK [READ-WRITE]');
    }
    return response.isOkStatus ? box : null;
  }

  @override
  bool parseUntagged(ImapResponse imapResponse, Response<Mailbox> response) {
    if (box == null) {
      return super.parseUntagged(imapResponse, response);
    }
    var details = imapResponse.parseText;
    if (details.startsWith('OK [UNSEEN ')) {
      box.firstUnseenMessageSequenceId =
          parseInt(details, 'OK [UNSEEN '.length, ']');
    } else if (details.startsWith('OK [UIDVALIDITY ')) {
      box.uidValidity = parseInt(details, 'OK [UIDVALIDITY '.length, ']');
    } else if (details.startsWith('OK [UIDNEXT ')) {
      box.uidNext = parseInt(details, 'OK [UIDNEXT '.length, ']');
    } else if (details.startsWith('OK [HIGHESTMODSEQ ')) {
      box.highestModSequence =
          parseInt(details, 'OK [HIGHESTMODSEQ '.length, ']');
    } else if (details.startsWith('FLAGS (')) {
      box.messageFlags = parseListEntries(details, 'FLAGS ('.length, ')');
    } else if (details.startsWith('OK [PERMANENTFLAGS (')) {
      box.permanentMessageFlags =
          parseListEntries(details, 'OK [PERMANENTFLAGS ('.length, ')');
    } else if (details.endsWith(' EXISTS')) {
      box.messagesExists = parseInt(details, 0, ' ');
    } else if (details.endsWith(' RECENT')) {
      box.messagesRecent = parseInt(details, 0, ' ');
    } else {
      return super.parseUntagged(imapResponse, response);
    }
    return true;
  }
}
