enum PopEventType { connectionLost, unknown }

class PopEvent {
  PopEventType type;

  PopEvent(this.type);
}

class PopConnectionLostEvent extends PopEvent {
  PopConnectionLostEvent() : super(PopEventType.connectionLost);
}
