import 'package:enough_mail/enough_mail.dart';

/// Classification of IMAP events
///
/// Compare [ImapEvent]
enum ImapEventType { connectionLost, expunge, fetch, exists, recent, vanished }

/// Base class for any event that can be fired by the IMAP client at any time.
/// Compare [ImapClient.eventBus]
class ImapEvent {
  final ImapEventType eventType;
  ImapEvent(this.eventType);
}

/// Notifies about a message that has been deleted
class ImapExpungeEvent extends ImapEvent {
  final int messageSequenceId;
  ImapExpungeEvent(this.messageSequenceId) : super(ImapEventType.expunge);
}

/// Notifies about a sequence of messages that have been deleted.
/// This event can only be triggered if the server is QRESYNC compliant and after the client has enabled QRESYNC.
class ImapVanishedEvent extends ImapEvent {
  final MessageSequence vanishedMessages;
  final bool isEarlier;
  ImapVanishedEvent(this.vanishedMessages, this.isEarlier)
      : super(ImapEventType.vanished);
}

/// Notifies about a message that has changed its status
class ImapFetchEvent extends ImapEvent {
  final MimeMessage message;
  ImapFetchEvent(this.message) : super(ImapEventType.fetch);
}

/// Notifies about new messages
class ImapMessagesExistEvent extends ImapEvent {
  final int newMessagesExists;
  final int oldMessagesExists;
  ImapMessagesExistEvent(this.newMessagesExists, this.oldMessagesExists)
      : super(ImapEventType.exists);
}

/// Notifies about new messages
class ImapMessagesRecentEvent extends ImapEvent {
  final int newMessagesRecent;
  final int oldMessagesRecent;
  ImapMessagesRecentEvent(this.newMessagesRecent, this.oldMessagesRecent)
      : super(ImapEventType.recent);
}

/// Notifies about a connection lost
class ImapConnectionLostEvent extends ImapEvent {
  ImapConnectionLostEvent() : super(ImapEventType.connectionLost);
}
