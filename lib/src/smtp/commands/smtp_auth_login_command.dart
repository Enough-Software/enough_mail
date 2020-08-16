import 'dart:convert';
import 'package:enough_mail/smtp/smtp_response.dart';

import '../smtp_command.dart';

class SmtpAuthLoginCommand extends SmtpCommand {
  final String _userName;
  final String _password;
  final Base64Codec _codec = Base64Codec();
  bool _userNameSent = false;
  bool _userPasswordSent = false;

  SmtpAuthLoginCommand(this._userName, this._password) : super('AUTH LOGIN');

  @override
  String getCommand() {
    return 'AUTH LOGIN';
  }

  @override
  String nextCommand(SmtpResponse response) {
    if (response.code != 334) {
      print('Invalid status code during AUTH LOGIN: ${response.code}.');
      return null;
    }
    if (!_userNameSent) {
      _userNameSent = true;
      return _codec.encode(_userName.codeUnits);
    } else if (!_userPasswordSent) {
      _userPasswordSent = true;
      return _codec.encode(_password.codeUnits);
    } else {
      return '<invalid state>';
    }
  }

  @override
  bool isCommandDone(SmtpResponse response) {
    return _userPasswordSent;
  }
}
