import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:enough_mail/src/private/pop/pop_command.dart';

/// The APOP command signs in the user
class PopApopCommand extends PopCommand<String> {
  /// Creates a new APOP command
  PopApopCommand(this.user, String pass, String serverTimestamp)
      : super('APOP $user ${toMd5(serverTimestamp + pass)}');

  /// The user ID
  final String user;

  /// Generates the MD5 hash from the [input]
  static String toMd5(String input) {
    final inputBytes = utf8.encode(input);
    final digest = md5.convert(inputBytes);
    return digest.toString();
  }

  @override
  String toString() => 'APOP $user <MD5 scrambled>';
}
