import 'package:enough_mail/enough_mail.dart';

/// Classification of IMAP events
///
/// Compare [ImapEvent]
enum ImapEventType {
  /// The connection to the server has been lost. Try to reconnect.
  /// Compare [ImapConnectionLostEvent].
  connectionLost,

  /// A message has been removed. Also see the vanished event.
  /// Compare [ImapExpungeEvent].
  expunge,

  /// The status flags of a message have been updated.
  /// Compare [ImapFetchEvent].
  fetch,

  /// The currently selected mailbox has a new number of messages.
  /// Compare [ImapMessagesExistEvent].
  exists,

  /// Similar to the exists event, the number of messages deemed as recent have changed.
  /// Compare [ImapMessagesRecentEvent].
  recent,

  /// A number of messages have been deleted.
  /// This event can only be triggered if the server is QRESYNC compliant and after the client has enabled QRESYNC.
  /// Compare [ImapVanishedEvent].
  vanished,
}

/// Base class for any event that can be fired by the IMAP client at any time.
/// Compare [ImapClient.eventBus]
class ImapEvent {
  /// The type of the event.
  final ImapEventType eventType;

  /// The associated ImapClient.
  final ImapClient imapClient;

  ImapEvent(this.eventType, this.imapClient);
}

/// Notifies about a message that has been deleted
class ImapExpungeEvent extends ImapEvent {
  /// The message sequence id (index) of the message that has been removed.
  final int? messageSequenceId;

  ImapExpungeEvent(this.messageSequenceId, ImapClient imapClient)
      : super(ImapEventType.expunge, imapClient);
}

/// Notifies about a sequence of messages that have been deleted.
/// This event can only be triggered if the server is QRESYNC compliant and after the client has enabled QRESYNC.
class ImapVanishedEvent extends ImapEvent {
  /// Message sequence of messages that have been expunged
  /// Check `vanishedMessages.isUid` to see if the message sequence contains IDs or UIDs.
  final MessageSequence? vanishedMessages;

  /// true when the vanished messages do not lead to updated sequence IDs
  final bool isEarlier;
  ImapVanishedEvent(
      this.vanishedMessages, this.isEarlier, ImapClient imapClient)
      : super(ImapEventType.vanished, imapClient);
}

/// Notifies about a message that has changed its status / flags
class ImapFetchEvent extends ImapEvent {
  /// The message with the updated flags.
  final MimeMessage message;
  ImapFetchEvent(this.message, ImapClient imapClient)
      : super(ImapEventType.fetch, imapClient);
}

/// Notifies about new messages
class ImapMessagesExistEvent extends ImapEvent {
  /// The current number of existing messages
  final int newMessagesExists;

  /// The previous number of existing messages
  final int oldMessagesExists;
  ImapMessagesExistEvent(
      this.newMessagesExists, this.oldMessagesExists, ImapClient imapClient)
      : super(ImapEventType.exists, imapClient);
}

/// Notifies about new messages
class ImapMessagesRecentEvent extends ImapEvent {
  /// The current number of recent messages
  final int newMessagesRecent;

  /// The previous number of recent messages
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
