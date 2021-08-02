enum SmtpEventType { connectionLost, unknown }

class SmtpEvent {
  SmtpEventType type;

  SmtpEvent(this.type);
}

class SmtpConnectionLostEvent extends SmtpEvent {
  SmtpConnectionLostEvent() : super(SmtpEventType.connectionLost);
}
