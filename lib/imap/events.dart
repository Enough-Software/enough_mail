/// Classification of IMAP events
///
/// Compare [ImapEvent]
enum ImapEventType { expunge, fetch, exists, recent }

/// Base class for any event that can be fired by the IMAP client at any time.
class ImapEvent {
  final ImapEventType eventType;
  ImapEvent(this.eventType);
}

/// Notifies about a message that has been deleted
class ImapExpungeEvent extends ImapEvent {
  int messageSequenceId;
  ImapExpungeEvent(this.messageSequenceId) : super(ImapEventType.expunge);
}

/// Notifies about a message that has changed its status
class ImapFetchEvent extends ImapEvent {
  int messageSequenceId;
  List<String> flags; // TODO change to List<MessageFlag>
  ImapFetchEvent(this.messageSequenceId, this.flags)
      : super(ImapEventType.fetch);
}

/// Notifies about new messages
class ImapMessagesExistEvent extends ImapEvent {
  int newMessagesExists;
  int oldMessagesExists;
  ImapMessagesExistEvent(this.newMessagesExists, this.oldMessagesExists)
      : super(ImapEventType.exists);
}

/// Notifies about new messages
class ImapMessagesRecentEvent extends ImapEvent {
  int newMessagesRecent;
  int oldMessagesRecent;
  ImapMessagesRecentEvent(this.newMessagesRecent, this.oldMessagesRecent)
      : super(ImapEventType.recent);
}
