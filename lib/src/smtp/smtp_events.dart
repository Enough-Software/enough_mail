import 'smtp_client.dart';

/// Types of SMTP events
enum SmtpEventType {
  /// Connection is lost, ie because of a network error
  connectionLost,

  /// Unsupported event type
  unknown
}

/// Base SMTP event
abstract class SmtpEvent {
  /// Creates a new SMTP event
  SmtpEvent(this.type, this.client);

  /// The type of the event
  final SmtpEventType type;

  /// The client from which the event originates
  final SmtpClient client;
}

/// Event signalling a lost connection
class SmtpConnectionLostEvent extends SmtpEvent {
  /// Creates a new connection lost event
  SmtpConnectionLostEvent(SmtpClient client)
      : super(SmtpEventType.connectionLost, client);
}
