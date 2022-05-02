import '../../imap/imap_client.dart';
import '../../imap/imap_events.dart';
import '../../imap/mailbox.dart';
import '../../imap/message_sequence.dart';
import '../../imap/response.dart';
import 'all_parsers.dart';
import 'imap_response.dart';
import 'parser_helper.dart';
import 'response_parser.dart';

/// Parses responses to a NOOP (no operation) IMAP request
class NoopParser extends ResponseParser<Mailbox?> {
  /// Create a new parser
  NoopParser(this.imapClient, this.mailbox);

  /// The imap client initiating the request
  final ImapClient imapClient;

  /// The associated mailbox
  final Mailbox? mailbox;

  final FetchParser _fetchParser = FetchParser(isUidFetch: false);
  final Response<FetchImapResult> _fetchResponse = Response<FetchImapResult>();

  @override
  Mailbox? parse(ImapResponse imapResponse, Response<Mailbox?> response) {
    final box = mailbox;
    if (box != null) {
      box.isReadWrite = imapResponse.parseText.startsWith('OK [READ-WRITE]');
      final highestModSequenceIndex =
          imapResponse.parseText.indexOf('[HIGHESTMODSEQ ');
      if (highestModSequenceIndex != -1) {
        box.highestModSequence = ParserHelper.parseInt(imapResponse.parseText,
            highestModSequenceIndex + '[HIGHESTMODSEQ '.length, ']');
      }
    }
    return response.isOkStatus ? box : null;
  }

  @override
  bool parseUntagged(ImapResponse imapResponse, Response<Mailbox?>? response) {
    final details = imapResponse.parseText;
    if (details.endsWith(' EXPUNGE')) {
      // example: 1234 EXPUNGE
      final id = parseInt(details, 0, ' ');
      if (id != null) {
        imapClient.eventBus.fire(ImapExpungeEvent(id, imapClient));
      }
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
        final messagesRecent = box.messagesRecent;
        handled = SelectParser.parseUntaggedResponse(box, imapResponse);

        if (handled) {
          if (box.messagesExists != messagesExists) {
            imapClient.eventBus.fire(ImapMessagesExistEvent(
                box.messagesExists, messagesExists, imapClient));
          } else if (box.messagesRecent != messagesRecent) {
            imapClient.eventBus.fire(ImapMessagesRecentEvent(
                box.messagesRecent, messagesRecent, imapClient));
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
