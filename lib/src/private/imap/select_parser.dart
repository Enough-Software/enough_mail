import 'package:enough_mail/src/imap/imap_client.dart';
import 'package:enough_mail/src/imap/imap_events.dart';
import 'package:enough_mail/src/imap/mailbox.dart';
import 'package:enough_mail/src/imap/response.dart';
import 'package:enough_mail/src/private/imap/all_parsers.dart';
import 'package:enough_mail/src/private/imap/parser_helper.dart';
import 'package:enough_mail/src/private/imap/response_parser.dart';

import 'imap_response.dart';

class SelectParser extends ResponseParser<Mailbox> {
  final Mailbox? mailbox;
  final ImapClient imapClient;
  final FetchParser _fetchParser = FetchParser(false);
  final Response<FetchImapResult> _fetchResponse = Response<FetchImapResult>();

  SelectParser(this.mailbox, this.imapClient);

  @override
  Mailbox? parse(ImapResponse details, Response<Mailbox> response) {
    final box = mailbox;
    if (box != null) {
      box.isReadWrite = details.parseText.startsWith('OK [READ-WRITE]');
      final highestModSequenceIndex =
          details.parseText.indexOf('[HIGHESTMODSEQ ');
      if (highestModSequenceIndex != -1) {
        box.highestModSequence = ParserHelper.parseInt(details.parseText,
            highestModSequenceIndex + '[HIGHESTMODSEQ '.length, ']');
      }
    }
    return response.isOkStatus ? mailbox : null;
  }

  @override
  bool parseUntagged(ImapResponse imapResponse, Response<Mailbox>? response) {
    final box = mailbox;
    if (box == null) {
      return super.parseUntagged(imapResponse, response);
    }
    if (parseUntaggedHelper(box, imapResponse)) {
      return true;
    } else if (_fetchParser.parseUntagged(imapResponse, _fetchResponse)) {
      var mimeMessage = _fetchParser.lastParsedMessage;
      if (mimeMessage != null) {
        imapClient.eventBus.fire(ImapFetchEvent(mimeMessage, imapClient));
      } else if (_fetchParser.vanishedMessages != null) {
        imapClient.eventBus.fire(
            ImapVanishedEvent(_fetchParser.vanishedMessages, true, imapClient));
      }
      return true;
    } else {
      return super.parseUntagged(imapResponse, response);
    }
  }

  static bool parseUntaggedHelper(Mailbox? mailbox, ImapResponse imapResponse) {
    final box = mailbox;
    if (box == null) {
      return false;
    }
    var details = imapResponse.parseText;
    if (details.startsWith('OK [UNSEEN ')) {
      box.firstUnseenMessageSequenceId =
          ParserHelper.parseInt(details, 'OK [UNSEEN '.length, ']');
      return true;
    } else if (details.startsWith('OK [UIDVALIDITY ')) {
      box.uidValidity =
          ParserHelper.parseInt(details, 'OK [UIDVALIDITY '.length, ']');
      return true;
    } else if (details.startsWith('OK [UIDNEXT ')) {
      box.uidNext = ParserHelper.parseInt(details, 'OK [UIDNEXT '.length, ']');
      return true;
    } else if (details.startsWith('OK [HIGHESTMODSEQ ')) {
      box.highestModSequence =
          ParserHelper.parseInt(details, 'OK [HIGHESTMODSEQ '.length, ']');
      box.hasModSequence = true;
      return true;
    } else if (details.startsWith('OK [NOMODSEQ]')) {
      box.hasModSequence = false;
      return true;
    } else if (details.startsWith('FLAGS (')) {
      box.messageFlags =
          ParserHelper.parseListEntries(details, 'FLAGS ('.length, ')');
      return true;
    } else if (details.startsWith('OK [PERMANENTFLAGS (')) {
      box.permanentMessageFlags = ParserHelper.parseListEntries(
          details, 'OK [PERMANENTFLAGS ('.length, ')');
      return true;
    } else if (details.endsWith(' EXISTS')) {
      box.messagesExists = ParserHelper.parseInt(details, 0, ' ') ?? 0;
      return true;
    } else if (details.endsWith(' RECENT')) {
      box.messagesRecent = ParserHelper.parseInt(details, 0, ' ');
      return true;
      // } else if (_fetchParser.parseUntagged(imapResponse, _fetchResponse)) {
      //   var mimeMessage = _fetchParser.lastParsedMessage;
      //   if (mimeMessage != null) {
      //     imapClient.eventBus.fire(ImapFetchEvent(mimeMessage, imapClient));
      //   } else if (_fetchParser.vanishedMessages != null) {
      //     imapClient.eventBus.fire(
      //         ImapVanishedEvent(_fetchParser.vanishedMessages, true, imapClient));
      //   }
      //   return true;
    } else {
      return false;
    }
  }
}
