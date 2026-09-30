import 'dart:convert';

import '../../../smtp/smtp_response.dart';
import '../smtp_command.dart';

/// Signs in the SMTP user
class SmtpAuthLoginCommand extends SmtpCommand {
  /// Creates a new AUTH LOGIN command
  SmtpAuthLoginCommand(this._userName, this._password) : super('AUTH LOGIN');

  final String _userName;
  final String _password;
  bool _userNameSent = false;
  bool _userPasswordSent = false;

  @override
  String get command => 'AUTH LOGIN';

  @override
  String? nextCommand(SmtpResponse response) {
    if (response.code != 334 && response.code != 235) {
      print(
        'Warning: Unexpected status code during AUTH LOGIN: ${response.code}.'
        'Expected: 334 or 235. \nuserNameSent=$_userNameSent, '
        'userPasswordSent=$_userPasswordSent',
      );
    }
    // the credentials are UTF-8 encoded, `String.codeUnits` would send
    // Latin-1 for e.g. umlauts and fail for any other non-ASCII character
    if (!_userNameSent) {
      _userNameSent = true;

      return base64.encode(utf8.encode(_userName));
    } else if (!_userPasswordSent) {
      _userPasswordSent = true;

      return base64.encode(utf8.encode(_password));
    } else {
      return null;
    }
  }

  @override
  bool isCommandDone(SmtpResponse response) => _userPasswordSent;

  @override
  String toString() => 'AUTH LOGIN <password scrambled>';
}
