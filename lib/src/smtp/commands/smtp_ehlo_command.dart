import 'package:enough_mail/smtp/smtp_response.dart';

import '../smtp_command.dart';

class SmtpEhloCommand extends SmtpCommand {
  final String? _clientName;

  SmtpEhloCommand([this._clientName]) : super('EHLO');

  @override
  String getCommand() {
    if (_clientName != null) {
      return '${super.getCommand()} $_clientName';
    }
    return super.getCommand();
  }

  @override
  bool isCommandDone(SmtpResponse response) {
    return (response.type != SmtpResponseType.success) ||
        (response.responseLines.length > 1);
  }
}
