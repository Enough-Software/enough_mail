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

  String nextCommand(SmtpResponse response) {
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
