import 'dart:convert';
import 'package:enough_mail/smtp/smtp_response.dart';

import '../smtp_command.dart';

class SmtpAuthXOauth2Command extends SmtpCommand {
  final String _userName;
  final String _accessToken;
  bool _authSent = false;

  SmtpAuthXOauth2Command(this._userName, this._accessToken)
      : super('AUTH XOAUTH2');

  @override
  String getCommand() {
    return 'AUTH XOAUTH2';
  }

  @override
  String nextCommand(SmtpResponse response) {
    if (response.code != 334 && response.code != 235) {
      print(
          'Warning: Unexpected status code during AUTH XOAUTH2: ${response.code}. Expected: 334 or 235. \nauthSent=$_authSent');
    }
    if (!_authSent) {
      _authSent = true;
      return getBase64EncodedData();
    } else {
      return null;
    }
  }

  String getBase64EncodedData() {
    var authText =
        'user=$_userName\u{0001}auth=Bearer $_accessToken\u{0001}\u{0001}';
    var authBase64Text = base64.encode(utf8.encode(authText));
    return authBase64Text;
  }

  @override
  bool isCommandDone(SmtpResponse response) {
    return _authSent;
  }

  @override
  String toString() {
    return 'AUTH XOAUTH2 <base64 scrambled>';
  }
}
