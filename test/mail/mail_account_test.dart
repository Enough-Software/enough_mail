import 'dart:convert';

import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';

void main() {
  void _compareAfterJsonSerialization(MailAccount original) {
    final text = jsonEncode(original.toJson());
    //print(text);
    final copy = MailAccount.fromJson(jsonDecode(text));
    //print('copy==original: ${copy == original}');
    expect(copy.incoming.serverConfig, original.incoming.serverConfig);
    expect(copy.incoming, original.incoming);
    expect(copy.outgoing, original.outgoing);
    expect(copy, original);
  }

  group('Serialization', () {
    test('Test ServerConfig', () async {
      const originalServerConfig = ServerConfig(
        type: ServerType.imap,
        hostname: 'imap.example.com',
        port: 993,
        socketType: SocketType.ssl,
        authentication: Authentication.passwordClearText,
        usernameType: UsernameType.emailAddress,
      );

      final restoredServerConfig = ServerConfig.fromJson(
        originalServerConfig.toJson(),
      );

      expect(
        originalServerConfig.toJson(),
        restoredServerConfig.toJson(),
      );
    });

    test('serialize account', () {
      const original = MailAccount(
        email: 'test@domain.com',
        name: 'A name with "quotes"',
        outgoingClientDomain: 'outgoing.com',
        userName: 'First Last',
        incoming: MailServerConfig(
          serverConfig: ServerConfig(
            type: ServerType.imap,
            hostname: 'imap.domain.com',
            port: 993,
            socketType: SocketType.ssl,
            authentication: Authentication.plain,
            usernameType: UsernameType.emailAddress,
          ),
          authentication: PlainAuthentication('user@domain.com', 'secret'),
          serverCapabilities: [Capability('IMAP4')],
          pathSeparator: '/',
        ),
        outgoing: MailServerConfig(
          serverConfig: ServerConfig(
            type: ServerType.smtp,
            hostname: 'smtp.domain.com',
            port: 993,
            socketType: SocketType.ssl,
            authentication: Authentication.plain,
            usernameType: UsernameType.emailAddress,
          ),
          authentication: PlainAuthentication('user@domain.com', 'secret'),
        ),
        supportsPlusAliases: true,
        aliases: [MailAddress('just tester', 'alias@domain.com')],
      );
      _compareAfterJsonSerialization(original);
    });

// cSpell:disable
    test('serialize OAuth account', () {
      const tokenText = '''{
"access_token": "ya29.asldkjsaklKJKLSD_LSKDJKLSDJllkjkljsd9_2n32j3h2jkj",
"expires_in": 3599,
"refresh_token": "1//09tw-sdkjskdSKJSDKF-L9Ir8GN-XJlyFkYRNLV_SKD,SDswekwl9wqekqmxsip2OS",
"scope": "https://mail.google.com/",
"token_type": "Bearer"
}''';
      final original = MailAccount(
        email: 'test@domain.com',
        userName: 'Andrea Ghez',
        name: 'A name with "quotes"',
        outgoingClientDomain: 'outgoing.com',
        incoming: MailServerConfig(
          serverConfig: const ServerConfig(
            type: ServerType.imap,
            hostname: 'imap.domain.com',
            port: 993,
            socketType: SocketType.ssl,
            authentication: Authentication.oauth2,
            usernameType: UsernameType.emailAddress,
          ),
          authentication: OauthAuthentication.from(
            'user@domain.com',
            tokenText,
            provider: 'gmail',
          ),
          serverCapabilities: [const Capability('IMAP4')],
          pathSeparator: '/',
        ),
        outgoing: MailServerConfig(
          serverConfig: const ServerConfig(
            type: ServerType.smtp,
            hostname: 'smtp.domain.com',
            port: 993,
            socketType: SocketType.ssl,
            authentication: Authentication.oauth2,
            usernameType: UsernameType.emailAddress,
          ),
          authentication: OauthAuthentication.from(
            'user@domain.com',
            tokenText,
            provider: 'gmail',
          ),
        ),
        supportsPlusAliases: true,
        aliases: [
          const MailAddress(
            'just tester',
            'alias@domain.com',
          ),
        ],
      );
      _compareAfterJsonSerialization(original);
    });

    test('deserialize oauth token', () {
      const tokenText = '''{
"access_token": "ya29.asldkjsaklKJKLSD_LSKDJKLSDJllkjkljsd9_2n32j3h2jkj",
"expires_in": 3599,
"refresh_token": "1//09tw-sdkjskdSKJSDKF-L9Ir8GN-XJlyFkYRNLV_SKD,SDswekwl9wqekqmxsip2OS",
"scope": "https://mail.google.com/",
"token_type": "Bearer"
}''';
      final token = OauthToken.fromText(tokenText);
      expect(
        token.accessToken,
        'ya29.asldkjsaklKJKLSD_LSKDJKLSDJllkjkljsd9_2n32j3h2jkj',
      );
      expect(token.expiresIn, 3599);
      expect(
        token.refreshToken,
        '1//09tw-sdkjskdSKJSDKF-L9Ir8GN-XJlyFkYRNLV_SKD,SDswekwl9wqekqmxsip2OS',
      );
      expect(token.scope, 'https://mail.google.com/');
      expect(token.tokenType, 'Bearer');
      expect(token.isExpired, isFalse);
      expect(token.isValid, isTrue);
    });

    test('serialize list of accounts', () {
      final accounts = [
        const MailAccount(
          email: 'test@domain.com',
          name: 'A name with "quotes"',
          userName: 'Andrea Ghez',
          outgoingClientDomain: 'outgoing.com',
          incoming: MailServerConfig(
            serverConfig: ServerConfig(
              type: ServerType.imap,
              hostname: 'imap.domain.com',
              port: 993,
              socketType: SocketType.ssl,
              authentication: Authentication.plain,
              usernameType: UsernameType.emailAddress,
            ),
            authentication: PlainAuthentication('user@domain.com', 'secret'),
            serverCapabilities: [Capability('IMAP4')],
            pathSeparator: '/',
          ),
          outgoing: MailServerConfig(
            serverConfig: ServerConfig(
              type: ServerType.smtp,
              hostname: 'smtp.domain.com',
              port: 993,
              socketType: SocketType.ssl,
              authentication: Authentication.plain,
              usernameType: UsernameType.emailAddress,
            ),
            authentication: PlainAuthentication('user@domain.com', 'secret'),
          ),
        ),
        const MailAccount(
          email: 'test2@domain2.com',
          name: 'my second account',
          userName: 'First Last',
          outgoingClientDomain: 'outdomain.com',
          incoming: MailServerConfig(
            serverConfig: ServerConfig(
              type: ServerType.imap,
              hostname: 'imap.domain2.com',
              port: 993,
              socketType: SocketType.ssl,
              authentication: Authentication.plain,
              usernameType: UsernameType.emailAddress,
            ),
            authentication:
                PlainAuthentication('user2@domain2.com', 'verysecret'),
            serverCapabilities: [Capability('IMAP4'), Capability('IDLE')],
            pathSeparator: '/',
          ),
          outgoing: MailServerConfig(
            serverConfig: ServerConfig(
              type: ServerType.smtp,
              hostname: 'smtp.domain2.com',
              port: 993,
              socketType: SocketType.ssl,
              authentication: Authentication.plain,
              usernameType: UsernameType.emailAddress,
            ),
            authentication:
                PlainAuthentication('user2@domain2.com', 'topsecret'),
          ),
        ),
      ];
      final jsonAccountsList =
          accounts.map((account) => account.toJson()).toList();
      final jsonText = jsonEncode(jsonAccountsList);
      final jsonList = jsonDecode(jsonText) as List;
      final parsedAccounts =
          // ignore: unnecessary_lambdas
          jsonList.map((json) => MailAccount.fromJson(json)).toList();
      expect(parsedAccounts.length, accounts.length);
      for (var i = 0; i < accounts.length; i++) {
        final original = accounts[i];
        final copy = parsedAccounts[i];
        expect(copy, original);
      }
    });
  });
}
