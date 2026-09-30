import '../../../smtp/smtp_client.dart';
import '../../../smtp/smtp_response.dart';
import '../smtp_command.dart';

/// Signs out of the service
class SmtpQuitCommand extends SmtpCommand {
  /// Creates a new QUIT command
  SmtpQuitCommand(this._client) : super('QUIT');
  final SmtpClient _client;

  @override
  String? nextCommand(SmtpResponse response) {
    // the server closes the connection after its reply, this is expected and
    // the client disconnects itself after the command has completed
    _client.isSocketClosingExpected = true;

    return null;
  }
}
