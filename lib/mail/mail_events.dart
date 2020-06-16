import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/mime_message.dart';

/// Classification of Mail events
///
/// Compare [MailEvent]
enum MailEventType { newMail, vanished }

/// Base class for any event that can be fired by the MailClient at any time.
/// Compare [MailClient.eventBus]
class MailEvent {
  final MailEventType eventType;
  MailEvent(this.eventType);
}

/// Notifies about a message that has been deleted
class MailLoadEvent extends MailEvent {
  final MimeMessage message;
  MailLoadEvent(this.message) : super(MailEventType.newMail);
}

/// Notifies about the UIDs of removed messages
class MailVanishedEvent extends MailEvent {
  /// UID sequence of messages that have been expunged
  final MessageSequence sequence;

  /// true when the vanished messages do not lead to updated sequence IDs
  final bool isEarlier;
  MailVanishedEvent(this.sequence, this.isEarlier)
      : super(MailEventType.vanished);
}
