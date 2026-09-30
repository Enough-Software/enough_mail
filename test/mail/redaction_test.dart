import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';

void main() {
  const password = 'S3cr3t-Pa55word';
  const accessToken = 'ya29.access-token-value';
  const refreshToken = '1//refresh-token-value';

  test('MailAccount.toString() does not contain the password', () {
    final account = MailAccount.fromManualSettings(
      name: 'test',
      email: 'user@example.com',
      password: password,
      incomingHost: 'imap.example.com',
      outgoingHost: 'smtp.example.com',
    );
    expect('$account', isNot(contains(password)));
    expect('${account.incoming}', isNot(contains(password)));
    expect('$account', contains('user@example.com'));
    // persisting still works:
    expect(account.toJson().toString(), contains(password));
    expect(MailAccount.fromJson(account.toJson()), account);
  });

  test('OauthToken and OauthAuthentication do not print tokens', () {
    final token = OauthToken(
      accessToken: accessToken,
      expiresIn: 3600,
      refreshToken: refreshToken,
      scope: 'mail',
      tokenType: 'Bearer',
      created: DateTime.now().toUtc(),
    );
    expect('$token', isNot(contains(accessToken)));
    expect('$token', isNot(contains(refreshToken)));
    expect('$token', contains('Bearer'));
    final account = MailAccount.fromManualSettingsWithAuth(
      name: 'test',
      email: 'user@example.com',
      incomingHost: 'imap.example.com',
      outgoingHost: 'smtp.example.com',
      auth: OauthAuthentication('user@example.com', token),
    );
    expect('$account', isNot(contains(accessToken)));
    expect('$account', isNot(contains(refreshToken)));
    expect(account.toJson().toString(), contains(refreshToken));
  });
}
