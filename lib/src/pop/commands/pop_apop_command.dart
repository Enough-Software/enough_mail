import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:enough_mail/src/pop/pop_command.dart';

class PopApopCommand extends PopCommand<String> {
  final String user;
  PopApopCommand(this.user, String pass, String serverTimestamp)
      : super('APOP $user ${toMd5(serverTimestamp + pass)}');

  static String toMd5(String input) {
    var inputBytes = utf8.encode(input);
    var digest = md5.convert(inputBytes);
    return digest.toString();
  }

  @override
  String toString() {
    return 'APOP $user <MD5 scrambled>';
  }
}
