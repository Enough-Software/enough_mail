import 'package:enough_mail/src/smtp/smtp_client.dart';
import 'package:enough_mail/src/smtp/smtp_response.dart';
import '../smtp_command.dart';

class SmtpQuitCommand extends SmtpCommand {
  final SmtpClient _client;
  SmtpQuitCommand(this._client) : super('QUIT');

  @override
  String? nextCommand(SmtpResponse response) {
    _client.disconnect();
    return null;
  }
}
