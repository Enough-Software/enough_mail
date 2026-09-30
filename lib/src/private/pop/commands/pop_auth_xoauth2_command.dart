import 'dart:convert';

import '../../../pop/pop_response.dart';
import '../pop_command.dart';

/// Signs in the user with the `AUTH XOAUTH2` SASL mechanism
///
/// Compare https://developers.google.com/gmail/imap/xoauth2-protocol
class PopAuthXOAuth2Command extends PopCommand<String> {
  /// Creates a new `AUTH XOAUTH2` command
  PopAuthXOAuth2Command(String user, String accessToken)
    : super('AUTH XOAUTH2 ${_encode(user, accessToken)}');

  static String _encode(String user, String accessToken) => base64.encode(
    utf8.encode('user=$user\u{0001}auth=Bearer $accessToken\u{0001}\u{0001}'),
  );

  bool _errorDetailsRequested = false;

  @override
  String? nextCommand(PopResponse response) {
    // On failure the server sends a `+ <base64>` continuation with the error
    // details; an empty client response then yields the final `-ERR`.
    final result = response.result;
    if (!_errorDetailsRequested &&
        !response.isOkStatus &&
        result is String &&
        result.startsWith('+')) {
      _errorDetailsRequested = true;

      return '';
    }

    return null;
  }

  @override
  String toString() => 'AUTH XOAUTH2 <base64 scrambled>';
}
