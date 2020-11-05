import 'package:enough_mail/enough_mail.dart';

/// Classification of IMAP events
///
/// Compare [ImapEvent]
enum ImapEventType { connectionLost, expunge, fetch, exists, recent, vanished }

/// Base class for any event that can be fired by the IMAP client at any time.
/// Compare [ImapClient.eventBus]
class ImapEvent {
  final ImapEventType eventType;
  final ImapClient imapClient;
  ImapEvent(this.eventType, this.imapClient);
}

/// Notifies about a message that has been deleted
class ImapExpungeEvent extends ImapEvent {
  final int messageSequenceId;
  ImapExpungeEvent(this.messageSequenceId, ImapClient imapClient)
      : super(ImapEventType.expunge, imapClient);
}

/// Notifies about a sequence of messages that have been deleted.
/// This event can only be triggered if the server is QRESYNC compliant and after the client has enabled QRESYNC.
class ImapVanishedEvent extends ImapEvent {
  /// Message sequence of messages that have been expunged
  /// Check `vanishedMessages.isUid
  final MessageSequence vanishedMessages;

  /// true when the vanished messages do not lead to updated sequence IDs
  final bool isEarlier;
  ImapVanishedEvent(
      this.vanishedMessages, this.isEarlier, ImapClient imapClient)
      : super(ImapEventType.vanished, imapClient);
}

/// Notifies about a message that has changed its status
class ImapFetchEvent extends ImapEvent {
  final MimeMessage message;
  ImapFetchEvent(this.message, ImapClient imapClient)
      : super(ImapEventType.fetch, imapClient);
}

/// Notifies about new messages
class ImapMessagesExistEvent extends ImapEvent {
  final int newMessagesExists;
  final int oldMessagesExists;
  ImapMessagesExistEvent(
      this.newMessagesExists, this.oldMessagesExists, ImapClient imapClient)
      : super(ImapEventType.exists, imapClient);
}

/// Notifies about new messages
class ImapMessagesRecentEvent extends ImapEvent {
  final int newMessagesRecent;
  final int oldMessagesRecent;
  ImapMessagesRecentEvent(
      this.newMessagesRecent, this.oldMessagesRecent, ImapClient imapClient)
      : super(ImapEventType.recent, imapClient);
}

/// Notifies about a connection lost
class ImapConnectionLostEvent extends ImapEvent {
  ImapConnectionLostEvent(ImapClient imapClient)
      : super(ImapEventType.connectionLost, imapClient);
}
