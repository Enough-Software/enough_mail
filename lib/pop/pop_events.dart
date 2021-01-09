import 'pop_client.dart';

enum PopEventType { connectionLost, unknown }

class PopEvent {
  final PopEventType type;
  final PopClient popClient;

  PopEvent(this.popClient, this.type);
}

class PopConnectionLostEvent extends PopEvent {
  PopConnectionLostEvent(PopClient popClient)
      : super(popClient, PopEventType.connectionLost);
}
