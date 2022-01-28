import 'dart:async';

import '../../imap/imap_client.dart';
import '../../imap/imap_events.dart';
import '../../imap/mailbox.dart';
import '../../imap/response.dart';
import 'imap_response.dart';
import 'response_parser.dart';

/// Retrieves the response code / prefix of a IMAP response,
///
/// eg `TRYCREATE` in the response `NO [TRYCREATE]`.
class GenericParser extends ResponseParser<GenericImapResult> {
  /// Creates a new parser
  GenericParser(this.imapClient, this.mailbox);

  /// The associated IMAP client
  final ImapClient imapClient;

  /// The currently active mailbox if any
  final Mailbox? mailbox;

  final GenericImapResult _result = GenericImapResult();
  @override
  GenericImapResult parse(
      ImapResponse imapResponse, Response<GenericImapResult> response) {
    final text = imapResponse.parseText;
    final startIndex = text.indexOf('[');
    if (startIndex != -1 && startIndex < text.length - 2) {
      final endIndex = text.indexOf(']', startIndex + 2);
      if (endIndex != -1) {
        _result
          ..responseCode = text.substring(startIndex + 1, endIndex)
          ..details = text.substring(endIndex + 1).trim();
      }
    }
    _result.details ??= text;
    return _result;
  }

  @override
  bool parseUntagged(
      ImapResponse imapResponse, Response<GenericImapResult>? response) {
    final text = imapResponse.parseText;
    if (text.startsWith('NO ')) {
      _result.warnings.add(ImapWarning('NO', text.substring('NO '.length)));
      return true;
    } else if (text.startsWith('BAD ')) {
      _result.warnings.add(ImapWarning('BAD', text.substring('BAD '.length)));
      return true;
    } else if (text.startsWith('OK [COPYUID')) {
      final endIndex = text.lastIndexOf(']');
      if (endIndex != -1) {
        _result.responseCode = text.substring('OK ['.length, endIndex);
      }
      return true;
    } else if (text.endsWith('EXPUNGE')) {
      // this is the expunge response for a MOVE operation, ignore
      //print('ignoring expunge: $text');
      return true;
    } else if (text.endsWith('EXISTS')) {
      // a message has been added to the current mailbox,
      // e.g. by a MOVE or APPEND operation:
      final box = mailbox;
      if (box != null) {
        final exists = parseInt(text, 0, ' ') ?? 0;
        final previous = box.messagesExists;
        box.messagesExists = exists;
        unawaited(
            _fireDelayed(ImapMessagesExistEvent(exists, previous, imapClient)));
      }
      return true;
    } else if (text.endsWith('RECENT')) {
      // a message has been added to the current mailbox,
      // e.g. by a MOVE or APPEND operation:
      final box = mailbox;
      if (box != null) {
        final recent = parseInt(text, 0, ' ') ?? 0;
        final previous = box.messagesRecent;
        box.messagesRecent = recent;
        unawaited(_fireDelayed(
            ImapMessagesRecentEvent(recent, previous, imapClient)));
      }
      return true;
    }
    return super.parseUntagged(imapResponse, response);
  }

  Future<void> _fireDelayed(ImapEvent event) async {
    await Future.delayed(const Duration(milliseconds: 100));
    imapClient.eventBus.fire(event);
  }
}
