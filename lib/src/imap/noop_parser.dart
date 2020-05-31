import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/imap/events.dart';
import 'package:enough_mail/imap/mailbox.dart';
import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/select_parser.dart';

import 'package:event_bus/event_bus.dart';

import 'imap_response.dart';

class NoopParser extends SelectParser {
  NoopParser(EventBus eventBus, Mailbox box) : super(box, eventBus);

  @override
  bool parseUntagged(ImapResponse imapResponse, Response<Mailbox> response) {
    var details = imapResponse.parseText;
    if (details.endsWith(' EXPUNGE')) {
      // example: 1234 EXPUNGE
      var id = parseInt(details, 0, ' ');
      eventBus.fire(ImapExpungeEvent(id));
    } else if (details.startsWith('VANISHED (EARLIER) ')) {
      handledVanished(details, 'VANISHED (EARLIER) ', true);
    } else if (details.startsWith('VANISHED ')) {
      handledVanished(details, 'VANISHED ');
    } else {
      var messagesExists = box.messagesExists;
      var messagesRecent = box.messagesRecent;
      var handled = super.parseUntagged(imapResponse, response);
      if (handled) {
        if (box.messagesExists != messagesExists) {
          eventBus
              .fire(ImapMessagesExistEvent(box.messagesExists, messagesExists));
        } else if (box.messagesRecent != messagesRecent) {
          eventBus.fire(
              ImapMessagesRecentEvent(box.messagesRecent, messagesRecent));
        }
      } else if (details.startsWith('OK ')) {
        // a common response in IDLE mode can be "* OK still here" or similar
        handled = true;
      }
      return handled;
    }
    return true;
  }

  void handledVanished(String details, String start, [bool isEarlier = false]) {
    var vanishedText = details.substring(start.length);
    var vanished = MessageSequence.parse(vanishedText);
    eventBus.fire(ImapVanishedEvent(vanished, isEarlier));
  }
}
