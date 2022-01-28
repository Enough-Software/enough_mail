import 'dart:convert';

import '../../../smtp/smtp_response.dart';
import '../smtp_command.dart';

/// Signs in the user with OAUTH 2
class SmtpAuthXOauth2Command extends SmtpCommand {
  /// Creates a new AUTH XOAUTH2 command
  SmtpAuthXOauth2Command(this._userName, this._accessToken)
      : super('AUTH XOAUTH2');

  final String? _userName;
  final String? _accessToken;
  bool _authSent = false;

  @override
  String get command => 'AUTH XOAUTH2';

  @override
  String? nextCommand(SmtpResponse response) {
    if (response.code != 334 && response.code != 235) {
      print('Warning: Unexpected status code during AUTH XOAUTH2: '
          '${response.code}. Expected: 334 or 235. \nauthSent=$_authSent');
    }
    if (!_authSent) {
      _authSent = true;
      return getBase64EncodedData();
    } else {
      return null;
    }
  }

  /// Retrieve the base64 data for the request
  String getBase64EncodedData() {
    final authText =
        'user=$_userName\u{0001}auth=Bearer $_accessToken\u{0001}\u{0001}';
    final authBase64Text = base64.encode(utf8.encode(authText));
    return authBase64Text;
  }

  @override
  bool isCommandDone(SmtpResponse response) => _authSent;

  @override
  String toString() => 'AUTH XOAUTH2 <base64 scrambled>';
}
