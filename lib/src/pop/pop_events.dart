import 'pop_client.dart';

/// Common POP event types
enum PopEventType {
  /// Connection to remote service is lost ie due to a network error
  connectionLost,

  /// Unrecognized error
  unknown
}

/// Base event class
abstract class PopEvent {
  /// Creates a new event
  PopEvent(this.popClient, this.type);

  /// The type of the event
  final PopEventType type;

  /// The client triggering the event
  final PopClient popClient;
}

/// Informs about a lost connection
class PopConnectionLostEvent extends PopEvent {
  /// Creates a connection lost event
  PopConnectionLostEvent(PopClient popClient)
      : super(popClient, PopEventType.connectionLost);
}
