import 'package:enough_mail/imap/events.dart';
import 'package:enough_mail/imap/mailbox.dart';
import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/all_parsers.dart';
import 'package:enough_mail/src/imap/parser_helper.dart';
import 'package:enough_mail/src/imap/response_parser.dart';
import 'package:event_bus/event_bus.dart';

import 'imap_response.dart';

class SelectParser extends ResponseParser<Mailbox> {
  final Mailbox box;
  final EventBus eventBus;
  final FetchParser _fetchParser = FetchParser();
  final Response<FetchImapResult> _fetchResponse = Response<FetchImapResult>();

  SelectParser(this.box, this.eventBus);

  @override
  Mailbox parse(ImapResponse details, Response<Mailbox> response) {
    if (box != null) {
      box.isReadWrite = details.parseText.startsWith('OK [READ-WRITE]');
      final highestModSequenceIndex =
          details.parseText.indexOf('[HIGHESTMODSEQ ');
      if (highestModSequenceIndex != -1) {
        box.highestModSequence = ParserHelper.parseInt(details.parseText,
            highestModSequenceIndex + '[HIGHESTMODSEQ '.length, ']');
      }
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
      box.hasModSequence = true;
    } else if (details.startsWith('OK [NOMODSEQ]')) {
      box.hasModSequence = false;
    } else if (details.startsWith('FLAGS (')) {
      box.messageFlags = parseListEntries(details, 'FLAGS ('.length, ')');
    } else if (details.startsWith('OK [PERMANENTFLAGS (')) {
      box.permanentMessageFlags =
          parseListEntries(details, 'OK [PERMANENTFLAGS ('.length, ')');
    } else if (details.endsWith(' EXISTS')) {
      box.messagesExists = parseInt(details, 0, ' ');
    } else if (details.endsWith(' RECENT')) {
      box.messagesRecent = parseInt(details, 0, ' ');
    } else if (_fetchParser.parseUntagged(imapResponse, _fetchResponse)) {
      var mimeMessage = _fetchParser.lastParsedMessage;
      if (mimeMessage != null) {
        eventBus.fire(ImapFetchEvent(mimeMessage));
      } else if (_fetchParser.vanishedMessages != null) {
        eventBus.fire(ImapVanishedEvent(_fetchParser.vanishedMessages, true));
      }
    } else {
      return super.parseUntagged(imapResponse, response);
    }
    return true;
  }
}
