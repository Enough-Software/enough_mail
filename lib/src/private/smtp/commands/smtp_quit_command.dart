import 'package:enough_mail/src/smtp/smtp_client.dart';
import 'package:enough_mail/src/smtp/smtp_response.dart';
import '../smtp_command.dart';

/// Signs out of the service
class SmtpQuitCommand extends SmtpCommand {
  /// Creates a new QUIT command
  SmtpQuitCommand(this._client) : super('QUIT');
  final SmtpClient _client;

  @override
  String? nextCommand(SmtpResponse response) {
    _client.disconnect();
    return null;
  }
}
