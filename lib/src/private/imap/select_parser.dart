import '../../imap/imap_client.dart';
import '../../imap/imap_events.dart';
import '../../imap/mailbox.dart';
import '../../imap/response.dart';
import 'all_parsers.dart';
import 'imap_response.dart';
import 'parser_helper.dart';
import 'response_parser.dart';

/// Parses responses to a mailbox selection command
class SelectParser extends ResponseParser<Mailbox> {
  /// Creates a new select parser
  SelectParser(this.mailbox, this.imapClient);

  /// The mailbox that should be selected
  final Mailbox mailbox;

  /// The originating imap client
  final ImapClient imapClient;
  final FetchParser _fetchParser = FetchParser(isUidFetch: false);
  final Response<FetchImapResult> _fetchResponse = Response<FetchImapResult>();

  @override
  Mailbox? parse(ImapResponse imapResponse, Response<Mailbox> response) {
    mailbox.isReadWrite = imapResponse.parseText.startsWith('OK [READ-WRITE]');
    final highestModSequenceIndex =
        imapResponse.parseText.indexOf('[HIGHESTMODSEQ ');
    if (highestModSequenceIndex != -1) {
      mailbox.highestModSequence = ParserHelper.parseInt(imapResponse.parseText,
          highestModSequenceIndex + '[HIGHESTMODSEQ '.length, ']');
    }
    return response.isOkStatus ? mailbox : null;
  }

  @override
  bool parseUntagged(ImapResponse imapResponse, Response<Mailbox>? response) {
    if (parseUntaggedResponse(mailbox, imapResponse)) {
      return true;
    } else if (_fetchParser.parseUntagged(imapResponse, _fetchResponse)) {
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
    } else {
      return super.parseUntagged(imapResponse, response);
    }
  }

  /// Helps with parsing untagged responses
  static bool parseUntaggedResponse(
      Mailbox mailbox, ImapResponse imapResponse) {
    final box = mailbox;
    final details = imapResponse.parseText;
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
      return true;
    } else if (details.startsWith('OK [NOMODSEQ]')) {
      box.highestModSequence = null;
      return true;
    } else if (details.endsWith(' EXISTS')) {
      box.messagesExists = ParserHelper.parseInt(details, 0, ' ') ?? 0;
      return true;
    } else if (details.endsWith(' RECENT')) {
      box.messagesRecent = ParserHelper.parseInt(details, 0, ' ') ?? 0;
      return true;
    } else if (details.startsWith('FLAGS (')) {
      box.messageFlags =
          ParserHelper.parseListEntries(details, 'FLAGS ('.length, ')') ?? [];
      return true;
    } else if (details.startsWith('OK [PERMANENTFLAGS (')) {
      box.permanentMessageFlags = ParserHelper.parseListEntries(
              details, 'OK [PERMANENTFLAGS ('.length, ')') ??
          [];
      return true;
    } else {
      return false;
    }
  }
}
