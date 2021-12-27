import 'dart:convert';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/smtp/commands/all_commands.dart';
import 'package:test/test.dart';

void main() {
  group('CRAM MD5 Tests', () {
    test('Stackoverflow 1', () {
      // source: https://stackoverflow.com/questions/186827/smtp-with-cram-md5-in-java
      final cramAuth = SmtpAuthCramMd5Command('user@example.com', 'password');
      expect(cramAuth.command, 'AUTH CRAM-MD5');
      final serverResponse = SmtpResponse(
          ['334 PDQ1MDMuMTIyMzU1Nzg2MkBtYWlsMDEuZXhhbXBsZS5jb20+']);
      expect(serverResponse.message,
          'PDQ1MDMuMTIyMzU1Nzg2MkBtYWlsMDEuZXhhbXBsZS5jb20+');
      expect(
          cramAuth.nextCommand(serverResponse),
          'dXNlckBleGFtcGxlLmNvbSA4YjdjODA5YzQ0NTNjZTVhYTA5N'
          '2VhNWM4OTlmNGY4Nw==');
    });

    test('Stackoverflow 2', () {
      // source: https://stackoverflow.com/questions/44785181/different-hashes-during-cram-md5-authentication
      final cramAuth = SmtpAuthCramMd5Command('alice', 'wonderland');
      expect(cramAuth.command, 'AUTH CRAM-MD5');
      final serverResponse = SmtpResponse([
        '334 ${base64.encode(utf8.encode('<17893.1320679123@tesse'
            'ract.susam.in>'))}'
      ]);
      expect(cramAuth.nextCommand(serverResponse),
          'YWxpY2UgNjRiMmE0M2MxZjZlZDY4MDZhOTgwOTE0ZTIzZTc1ZjA=');
    });

    test('RFC2195 Example', () {
      // source: https://tools.ietf.org/html/rfc2195
      final cramAuth = SmtpAuthCramMd5Command('tim', 'tanstaaftanstaaf');
      expect(cramAuth.command, 'AUTH CRAM-MD5');
      final serverResponse = SmtpResponse(
          ['334 PDE4OTYuNjk3MTcwOTUyQHBvc3RvZmZpY2UucmVzdG9uLm1jaS5uZXQ+']);
      expect(serverResponse.message,
          'PDE4OTYuNjk3MTcwOTUyQHBvc3RvZmZpY2UucmVzdG9uLm1jaS5uZXQ+');
      expect(cramAuth.nextCommand(serverResponse),
          'dGltIGI5MTNhNjAyYzdlZGE3YTQ5NWI0ZTZlNzMzNGQzODkw');
    });
  });
}
