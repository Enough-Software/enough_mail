import 'dart:convert';
import 'package:enough_mail/src/smtp/smtp_response.dart';

import '../smtp_command.dart';

class SmtpAuthLoginCommand extends SmtpCommand {
  final String? _userName;
  final String? _password;
  final Base64Codec _codec = Base64Codec();
  bool _userNameSent = false;
  bool _userPasswordSent = false;

  SmtpAuthLoginCommand(this._userName, this._password) : super('AUTH LOGIN');

  @override
  String getCommand() {
    return 'AUTH LOGIN';
  }

  @override
  String? nextCommand(SmtpResponse response) {
    if (response.code != 334 && response.code != 235) {
      print(
          'Warning: Unexpected status code during AUTH LOGIN: ${response.code}. Expected: 334 or 235. \nuserNameSent=$_userNameSent, userPasswordSent=$_userPasswordSent');
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
  bool isCommandDone(SmtpResponse response) {
    return _userPasswordSent;
  }

  @override
  String toString() {
    return 'AUTH LOGIN <password scrambled>';
  }
}
