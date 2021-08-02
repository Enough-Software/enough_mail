import 'dart:convert';
import '../smtp_command.dart';

class SmtpAuthPlainCommand extends SmtpCommand {
  final String userName;
  final String password;

  SmtpAuthPlainCommand(this.userName, this.password) : super('AUTH PLAIN');

  @override
  String getCommand() {
    final combined = userName + '\u{0000}' + userName + '\u{0000}' + password;
    final codec = Base64Codec();
    final encoded = codec.encode(combined.codeUnits);
    return 'AUTH PLAIN ' + encoded;
  }

  @override
  String toString() {
    return 'AUTH PLAIN <password scrambled>';
  }
}
