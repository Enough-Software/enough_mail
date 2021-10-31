import 'package:enough_mail/src/imap/message_sequence.dart';
import 'package:enough_mail/src/mail/mail_client.dart';
import 'package:enough_mail/src/mime_message.dart';

/// Classification of Mail events
///
/// Compare [MailEvent]
enum MailEventType {
  newMail,
  vanished,
  updateMail,
  connectionLost,
  connectionReEstablished
}

/// Base class for any event that can be fired by the MailClient at any time.
/// Compare [MailClient.eventBus]
class MailEvent {
  const MailEvent(this.eventType, this.mailClient);
  final MailEventType eventType;
  final MailClient mailClient;
}

/// Notifies about a message that has been deleted
class MailLoadEvent extends MailEvent {
  const MailLoadEvent(this.message, MailClient mailClient)
      : super(MailEventType.newMail, mailClient);
  final MimeMessage message;
}

/// Notifies about the removal of messages
class MailVanishedEvent extends MailEvent {
  const MailVanishedEvent(this.sequence, this.isEarlier, MailClient mailClient)
      : super(MailEventType.vanished, mailClient);

  /// Sequence of messages that have been expunged,
  /// Use this code to check if the sequence consists of UIDs:
  /// `if (sequence.isUidSequence) { ... }`
  final MessageSequence? sequence;

  /// true when the vanished messages do not lead to updated sequence IDs
  final bool isEarlier;
}

/// Notifies about an mail flags update
class MailUpdateEvent extends MailEvent {
  const MailUpdateEvent(this.message, MailClient mailClient)
      : super(MailEventType.updateMail, mailClient);
  final MimeMessage message;
}

/// Notifies about a lost connection
class MailConnectionLostEvent extends MailEvent {
  const MailConnectionLostEvent(MailClient mailClient)
      : super(MailEventType.connectionLost, mailClient);
}

/// Notifies about a connection that has been re-established
class MailConnectionReEstablishedEvent extends MailEvent {
  const MailConnectionReEstablishedEvent(
      this.isManualSynchronizationRequired, MailClient mailClient)
      : super(MailEventType.connectionReEstablished, mailClient);

  /// Is `true` when the server does not support quick resync (`QRSYNC`) or a similar method.
  final bool isManualSynchronizationRequired;
}
