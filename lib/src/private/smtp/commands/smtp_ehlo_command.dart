import '../../../smtp/smtp_response.dart';
import '../smtp_command.dart';

/// Says hello to the remote service
class SmtpEhloCommand extends SmtpCommand {
  /// Creates a new EHLO command
  SmtpEhloCommand([this._clientName]) : super('EHLO');
  final String? _clientName;

  @override
  String get command {
    if (_clientName != null) {
      return '${super.command} $_clientName';
    }
    return super.command;
  }

  @override
  bool isCommandDone(SmtpResponse response) =>
      (response.type != SmtpResponseType.success) ||
      (response.responseLines.length > 1);
}
