import 'package:enough_mail/smtp/smtp_client.dart';
import 'package:enough_mail/smtp/smtp_response.dart';
import '../smtp_command.dart';

class SmtpQuitCommand extends SmtpCommand {
  final SmtpClient _client;
  SmtpQuitCommand(this._client) : super('QUIT');

  @override
  String nextCommand(SmtpResponse response) {
    _client.close();
    return null;
  }
}