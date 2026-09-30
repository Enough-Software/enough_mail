import 'dart:convert';

import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';

import 'imap_loopback_server.dart';

OauthToken _token(String access, String refresh, {required bool expired}) =>
    OauthToken(
      accessToken: access,
      expiresIn: 3600,
      refreshToken: refresh,
      scope: 'mail',
      tokenType: 'Bearer',
      created: expired
          ? DateTime.now().toUtc().subtract(const Duration(hours: 2))
          : DateTime.now().toUtc(),
    );

void main() {
  late ImapLoopbackServer server;

  setUp(() async {
    server = await ImapLoopbackServer.start();
  });

  tearDown(() => server.close());

  test('a rotated refresh token is kept after refreshing', () async {
    final account = MailAccount.fromManualSettingsWithAuth(
      name: 'test',
      email: 'user@example.com',
      incomingHost: server.host,
      incomingPort: server.port,
      incomingSocketType: SocketType.plainNoStartTls,
      outgoingHost: server.host,
      auth: OauthAuthentication(
        'user@example.com',
        _token('old-access', 'old-refresh', expired: true),
      ),
    );
    var refreshCalls = 0;
    MailAccount? changedAccount;
    final mailClient = MailClient(
      account,
      refresh: (client, expiredToken) async {
        refreshCalls++;
        expect(expiredToken.refreshToken, 'old-refresh');

        return _token('new-access', 'new-refresh', expired: false);
      },
      onConfigChanged: (account) async => changedAccount = account,
    );
    await mailClient.connect();
    expect(refreshCalls, 1);
    final auth = mailClient.account.incoming.authentication;
    expect(auth, isA<OauthAuthentication>());
    final token = (auth as OauthAuthentication).token;
    expect(token.accessToken, 'new-access');
    expect(token.refreshToken, 'new-refresh');
    expect(changedAccount, isNotNull);
    final authenticate = server.requests.firstWhere(
      (r) => r.contains('AUTHENTICATE XOAUTH2'),
    );
    final payload = utf8.decode(base64.decode(authenticate.split(' ').last));
    expect(payload, contains('Bearer new-access'));
    await mailClient.disconnect();
  });

  test('OauthToken and authentications have consistent equality', () {
    final a = _token('access', 'refresh', expired: false);
    final b = OauthToken.fromJson(a.toJson());
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(
      OauthAuthentication('u', a).hashCode,
      OauthAuthentication('u', b).hashCode,
    );
    expect(
      const PlainAuthentication('u', 'p').hashCode,
      const PlainAuthentication('u', 'p').hashCode,
    );
    expect(
      const PlainAuthentication('u', 'p').hashCode,
      isNot(const PlainAuthentication('p', 'u').hashCode),
    );
  });
}
