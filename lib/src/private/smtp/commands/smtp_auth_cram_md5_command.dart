import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../../../smtp/smtp_response.dart';
import '../smtp_command.dart';

/// CRAM-MD5 Authentication
///
/// Compare https://tools.ietf.org/html/rfc2195 and https://tools.ietf.org/html/rfc4954 for details.
class SmtpAuthCramMd5Command extends SmtpCommand {
  /// Creates a new AUTH CRAM-MD5 command
  SmtpAuthCramMd5Command(this._userName, this._password)
      : super('AUTH CRAM-MD5');

  final String? _userName;
  final String? _password;
  bool _authSent = false;

  @override
  String get command => 'AUTH CRAM-MD5';

  @override
  String? nextCommand(SmtpResponse response) {
    /* Example flow:
C: AUTH CRAM-MD5
S: 334 BASE64(NONCE)
C: BASE64(USERNAME, " ", MD5((SECRET XOR opad),MD5((SECRET XOR ipad), NONCE)))
S: 235 Authentication succeeded
    */
    if (response.code != 334 && response.code != 235) {
      print('Warning: Unexpected status code during AUTH XOAUTH2: '
          '${response.code}. Expected: 334 or 235. \nauthSent=$_authSent');
    }
    if (!_authSent) {
      _authSent = true;
      final base64Nonce = response.message!;
      return getBase64EncodedData(base64Nonce);
    } else {
      return null;
    }
  }

  /// Converts the password using the [base64Nonce] to base64
  String getBase64EncodedData(String base64Nonce) {
    // BASE64(USERNAME, " ",
    //        MD5((SECRET XOR opad),MD5((SECRET XOR ipad), NONCE)))
    var password = utf8.encode(_password!);
    if (password.length > 64) {
      final passwordDigest = md5.convert(password);
      password = passwordDigest.bytes;
    }
    final nonce = base64.decode(base64Nonce);
    final hmac = Hmac(md5, password);
    final hmacNonce = hmac.convert(nonce);
    final input = '$_userName $hmacNonce';
    final complete = utf8.encode(input);
    final authBase64Text = base64.encode(complete);
    return authBase64Text;
  }

  @override
  bool isCommandDone(SmtpResponse response) => _authSent;

  @override
  String toString() => 'AUTH XOAUTH2 <base64 scrambled>';
}
