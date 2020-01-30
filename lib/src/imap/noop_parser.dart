import 'package:enough_mail/imap/events.dart';
import 'package:enough_mail/imap/mailbox.dart';
import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/select_parser.dart';

import 'package:event_bus/event_bus.dart';

import 'imap_response.dart';

class NoopParser extends SelectParser {
  EventBus eventBus;

  NoopParser(this.eventBus, Mailbox box) : super(box);


  @override
  bool parseUntagged(ImapResponse imapResponse, Response<Mailbox> response) {
    var details = imapResponse.parseText;
    if (details.endsWith(' EXPUNGE')) {
      // example: 1234 EXPUNGE
      var id = parseInt(details, 0, ' ');
      eventBus.fire(ImapExpungeEvent(id));
    } else if (details.contains(' FETCH ')) {
      // example: 14 FETCH (FLAGS (\Seen \Deleted))
      var id = parseInt(details, 0, ' ');
      var startIndex = details.indexOf('FLAGS');
      if (startIndex == -1) {
        print('Unexpected/invalid FETCH response: ' + details);
        return super.parseUntagged(imapResponse, response);
      }
      startIndex = details.indexOf("(", startIndex + "FLAGS".length);
      if (startIndex == -1) {
        print('Unexpected/invalid FETCH response: ' + details);
        return super.parseUntagged(imapResponse, response);
      }
      var flags = parseListEntries(details, startIndex + 1, ")");
      eventBus.fire(ImapFetchEvent(id, flags));
    } else {
      var messagesExists = box.messagesExists;
      var messagesRecent = box.messagesRecent;
      var handled = super.parseUntagged(imapResponse, response);
      if (handled) {
        if (box.messagesExists != messagesExists) {
          eventBus.fire(ImapMessagesExistEvent( box.messagesExists, messagesExists));
        } else if (box.messagesRecent != messagesRecent) {
          eventBus.fire(ImapMessagesRecentEvent( box.messagesRecent, messagesRecent));
        }
      }
      return handled;
    }
    return true;
  }
}
