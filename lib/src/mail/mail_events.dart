import 'package:enough_mail/src/imap/message_sequence.dart';
import 'package:enough_mail/src/mail/mail_client.dart';
import 'package:enough_mail/src/mime_message.dart';

/// Classification of Mail events
///
/// Compare [MailEvent]
enum MailEventType {
  /// a new mail arrived
  newMail,

  /// one or several mails have been deleted / moved to trash
  vanished,

  /// one or several mail flags have been updated
  updateMail,

  /// the connection to the server has been lost
  connectionLost,

  /// the connection to the server has been regained
  connectionReEstablished
}

/// Base class for any event that can be fired by the MailClient at any time.
/// Compare [MailClient.eventBus]
class MailEvent {
  /// Creates a new mail event
  const MailEvent(this.eventType, this.mailClient);

  /// The type of the event
  final MailEventType eventType;

  /// The mail client that fired this event
  final MailClient mailClient;
}

/// Notifies about a message that has been deleted
class MailLoadEvent extends MailEvent {
  /// Creates a new mail event
  const MailLoadEvent(this.message, MailClient mailClient)
      : super(MailEventType.newMail, mailClient);

  /// The message that has been loaded
  final MimeMessage message;
}

/// Notifies about the removal of messages
class MailVanishedEvent extends MailEvent {
  /// Creates a new mail event
  const MailVanishedEvent(
    this.sequence,
    MailClient mailClient, {
    required this.isEarlier,
  }) : super(MailEventType.vanished, mailClient);

  /// Sequence of messages that have been expunged,
  /// Use this code to check if the sequence consists of UIDs:
  /// `if (sequence.isUidSequence) { ... }`
  final MessageSequence? sequence;

  /// true when the vanished messages do not lead to updated sequence IDs
  final bool isEarlier;
}

/// Notifies about an mail flags update
class MailUpdateEvent extends MailEvent {
  /// Creates a new mail event
  const MailUpdateEvent(this.message, MailClient mailClient)
      : super(MailEventType.updateMail, mailClient);

  /// The message for which the flags have been updated
  final MimeMessage message;
}

/// Notifies about a lost connection
class MailConnectionLostEvent extends MailEvent {
  /// Creates a new mail event
  const MailConnectionLostEvent(MailClient mailClient)
      : super(MailEventType.connectionLost, mailClient);
}

/// Notifies about a connection that has been re-established
class MailConnectionReEstablishedEvent extends MailEvent {
  /// Creates a new mail event
  const MailConnectionReEstablishedEvent(
    MailClient mailClient, {
    required this.isManualSynchronizationRequired,
  }) : super(MailEventType.connectionReEstablished, mailClient);

  /// Is `true` when the server does not support quick resync (`QRSYNC`)
  /// or a similar method.
  final bool isManualSynchronizationRequired;
}
