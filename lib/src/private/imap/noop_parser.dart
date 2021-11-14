import 'package:enough_mail/src/imap/imap_client.dart';
import 'package:enough_mail/src/imap/imap_events.dart';
import 'package:enough_mail/src/imap/mailbox.dart';
import 'package:enough_mail/src/imap/message_sequence.dart';
import 'package:enough_mail/src/imap/response.dart';
import 'package:enough_mail/src/private/imap/all_parsers.dart';
import 'package:enough_mail/src/private/imap/parser_helper.dart';
import 'package:enough_mail/src/private/imap/response_parser.dart';

import 'imap_response.dart';

class NoopParser extends ResponseParser<Mailbox?> {
  final ImapClient imapClient;
  final Mailbox? mailbox;
  final FetchParser _fetchParser = FetchParser(false);
  final Response<FetchImapResult> _fetchResponse = Response<FetchImapResult>();

  NoopParser(this.imapClient, this.mailbox);

  @override
  Mailbox? parse(ImapResponse details, Response<Mailbox?> response) {
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
  bool parseUntagged(ImapResponse imapResponse, Response<Mailbox?>? response) {
    final details = imapResponse.parseText;
    if (details.endsWith(' EXPUNGE')) {
      // example: 1234 EXPUNGE
      final id = parseInt(details, 0, ' ');
      imapClient.eventBus.fire(ImapExpungeEvent(id, imapClient));
    } else if (details.startsWith('VANISHED (EARLIER) ')) {
      handledVanished(details, 'VANISHED (EARLIER) ', isEarlier: true);
    } else if (details.startsWith('VANISHED ')) {
      handledVanished(details, 'VANISHED ');
    } else {
      var handled = false;
      final box = mailbox;
      if (box == null) {
        handled = super.parseUntagged(imapResponse, response);
      } else {
        final messagesExists = box.messagesExists;
        final messagesRecent = box.messagesRecent ?? 0;
        handled = SelectParser.parseUntaggedHelper(mailbox, imapResponse);

        if (handled) {
          if (box.messagesExists != messagesExists) {
            imapClient.eventBus.fire(ImapMessagesExistEvent(
                box.messagesExists, messagesExists, imapClient));
          } else if (box.messagesRecent != messagesRecent) {
            imapClient.eventBus.fire(ImapMessagesRecentEvent(
                box.messagesRecent ?? 1, messagesRecent, imapClient));
          }
          return true;
        } else {
          if (_fetchParser.parseUntagged(imapResponse, _fetchResponse)) {
            final mimeMessage = _fetchParser.lastParsedMessage;
            if (mimeMessage != null) {
              imapClient.eventBus.fire(ImapFetchEvent(mimeMessage, imapClient));
            } else if (_fetchParser.vanishedMessages != null) {
              imapClient.eventBus.fire(ImapVanishedEvent(
                _fetchParser.vanishedMessages,
                imapClient,
                isEarlier: true,
              ));
            }
            return true;
          }
        }
      }
      if (!handled && details.startsWith('OK ')) {
        // a common response in IDLE mode can be "* OK still here" or similar
        handled = true;
      }
      return handled;
    }
    return true;
  }

  /// Handles vanished response lines
  void handledVanished(String details, String start, {bool isEarlier = false}) {
    final vanishedText = details.substring(start.length);
    final vanished = MessageSequence.parse(vanishedText, isUidSequence: true);
    imapClient.eventBus.fire(ImapVanishedEvent(
      vanished,
      imapClient,
      isEarlier: isEarlier,
    ));
  }
}
