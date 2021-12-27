import 'dart:convert';
import '../smtp_command.dart';

/// Authenticates the SMTP user
class SmtpAuthPlainCommand extends SmtpCommand {
  /// Creates a new AUTH PLAIN command
  SmtpAuthPlainCommand(this.userName, this.password) : super('AUTH PLAIN');

  /// The user name
  final String userName;

  /// The password
  final String password;

  @override
  String get command {
    final combined = '$userName\u{0000}$userName\u{0000}$password';
    const codec = Base64Codec();
    final encoded = codec.encode(combined.codeUnits);
    return 'AUTH PLAIN $encoded';
  }

  @override
  String toString() => 'AUTH PLAIN <password scrambled>';
}
