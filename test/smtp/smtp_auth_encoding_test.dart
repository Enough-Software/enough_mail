import 'dart:convert';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/smtp/commands/smtp_auth_login_command.dart';
import 'package:enough_mail/src/private/smtp/commands/smtp_auth_plain_command.dart';
import 'package:test/test.dart';

void main() {
  const user = 'jörg@example.com';
  const password = 'pässwörd€😀';

  test('AUTH PLAIN encodes the credentials as UTF-8', () {
    final command = SmtpAuthPlainCommand(user, password);
    final expected = base64.encode(
      utf8.encode('$user\u0000$user\u0000$password'),
    );
    expect(command.command, 'AUTH PLAIN $expected');
  });

  test('AUTH LOGIN encodes the credentials as UTF-8', () {
    final command = SmtpAuthLoginCommand(user, password);
    expect(
      command.nextCommand(SmtpResponse(['334 VXNlcm5hbWU6'])),
      base64.encode(utf8.encode(user)),
    );
    expect(
      command.nextCommand(SmtpResponse(['334 UGFzc3dvcmQ6'])),
      base64.encode(utf8.encode(password)),
    );
    expect(command.isCommandDone(SmtpResponse(['235 ok'])), isTrue);
  });
}
