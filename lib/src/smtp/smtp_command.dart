import 'dart:async';
import 'package:enough_mail/smtp/smtp_response.dart';

class SmtpCommand {
  final String _command;
  String get command => getCommand();

  final Completer<SmtpResponse> completer = Completer<SmtpResponse>();

  SmtpCommand(this._command);

  String getCommand() {
    return _command;
  }

  SmtpCommandData next(SmtpResponse response) {
    final text = nextCommand(response);
    if (text != null) {
      return SmtpCommandData(text, null);
    }
    final data = nextCommandData(response);
    if (data != null) {
      return SmtpCommandData(null, data);
    }
    return null;
  }

  String nextCommand(SmtpResponse response) {
    return null;
  }

  List<int> nextCommandData(SmtpResponse response) {
    return null;
  }

  bool isCommandDone(SmtpResponse response) {
    return true;
  }

  @override
  String toString() {
    return command;
  }
}

class SmtpCommandData {
  final String text;
  final List<int> data;
  SmtpCommandData(this.text, this.data);
}
