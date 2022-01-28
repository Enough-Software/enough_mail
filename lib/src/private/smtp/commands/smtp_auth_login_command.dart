import 'dart:convert';

import '../../../smtp/smtp_response.dart';
import '../smtp_command.dart';

/// Signs in the SMTP user
class SmtpAuthLoginCommand extends SmtpCommand {
  /// Creates a new AUTH LOGIN command
  SmtpAuthLoginCommand(this._userName, this._password) : super('AUTH LOGIN');

  final String? _userName;
  final String? _password;
  final Base64Codec _codec = const Base64Codec();
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
          'userPasswordSent=$_userPasswordSent');
    }
    if (!_userNameSent) {
      _userNameSent = true;
      return _codec.encode(_userName!.codeUnits);
    } else if (!_userPasswordSent) {
      _userPasswordSent = true;
      return _codec.encode(_password!.codeUnits);
    } else {
      return null;
    }
  }

  @override
  bool isCommandDone(SmtpResponse response) => _userPasswordSent;

  @override
  String toString() => 'AUTH LOGIN <password scrambled>';
}
