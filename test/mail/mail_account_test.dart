import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/discover/client_config.dart';
import 'package:enough_mail/src/mail/mail_authentication.dart';
import 'package:enough_serialization/enough_serialization.dart';
import 'package:test/test.dart';
import 'package:enough_mail/src/mail/mail_account.dart';

void main() {
  void _compareAfterJsonSerialization(MailAccount original) {
    final text = Serializer().serialize(original);
    //print(text);
    final copy = MailAccount();
    Serializer().deserialize(text, copy);
    //print('copy==original: ${copy == original}');
    expect(copy.incoming?.serverConfig, original.incoming?.serverConfig);
    expect(copy.incoming, original.incoming);
    expect(copy.outgoing, original.outgoing);
    expect(copy, original);
  }

  group('Serialize', () {
    test('serialize account 1', () {
      final original = MailAccount()..email = 'test@domain.com';
      _compareAfterJsonSerialization(original);
    });

    test('serialize account 2', () {
      final original = MailAccount()
        ..email = 'test@domain.com'
        ..name = 'A name with "quotes"'
        ..outgoingClientDomain = 'outgoing.com'
        ..supportsPlusAliases = true;
      _compareAfterJsonSerialization(original);
    });

    test('serialize account 3', () {
      final original = MailAccount()
        ..email = 'test@domain.com'
        ..userName = 'tester test'
        ..name = 'A name with "quotes"'
        ..outgoingClientDomain = 'outgoing.com'
        ..incoming = MailServerConfig(
            serverConfig: ServerConfig(
                type: ServerType.imap,
                hostname: 'imap.domain.com',
                port: 993,
                socketType: SocketType.ssl,
                authentication: Authentication.plain,
                usernameType: UsernameType.emailAddress),
            authentication: PlainAuthentication('user@domain.com', 'secret'),
            serverCapabilities: [Capability('IMAP4')],
            pathSeparator: '/')
        ..outgoing = MailServerConfig(
            serverConfig: ServerConfig(
                type: ServerType.smtp,
                hostname: 'smtp.domain.com',
                port: 993,
                socketType: SocketType.ssl,
                authentication: Authentication.plain,
                usernameType: UsernameType.emailAddress),
            authentication: PlainAuthentication('user@domain.com', 'secret'))
        ..supportsPlusAliases = true
        ..aliases = [MailAddress('just tester', 'alias@domain.com')];
      _compareAfterJsonSerialization(original);
    });

    test('serialize OAuth account', () {
      final tokenText = '''{
"access_token": "ya29.asldkjsaklKJKLSD_LSKDJKLSDJllkjkljsd9_2n32j3h2jkj",
"expires_in": 3599,
"refresh_token": "1//09tw-sdkjskdSKJSDKF-L9Ir8GN-XJlyFkYRNLV_SKD,SDswekwl9wqekqmxsip2OS",
"scope": "https://mail.google.com/",
"token_type": "Bearer"
}''';
      final original = MailAccount()
        ..email = 'test@domain.com'
        ..userName = 'tester test'
        ..name = 'A name with "quotes"'
        ..outgoingClientDomain = 'outgoing.com'
        ..incoming = MailServerConfig(
          serverConfig: ServerConfig(
            type: ServerType.imap,
            hostname: 'imap.domain.com',
            port: 993,
            socketType: SocketType.ssl,
            authentication: Authentication.oauth2,
            usernameType: UsernameType.emailAddress,
          ),
          authentication: OauthAuthentication.from('user@domain.com', tokenText,
              provider: 'gmail'),
          serverCapabilities: [Capability('IMAP4')],
          pathSeparator: '/',
        )
        ..outgoing = MailServerConfig(
          serverConfig: ServerConfig(
              type: ServerType.smtp,
              hostname: 'smtp.domain.com',
              port: 993,
              socketType: SocketType.ssl,
              authentication: Authentication.oauth2,
              usernameType: UsernameType.emailAddress),
          authentication: OauthAuthentication.from('user@domain.com', tokenText,
              provider: 'gmail'),
        )
        ..supportsPlusAliases = true
        ..aliases = [
          MailAddress(
            'just tester',
            'alias@domain.com',
          ),
        ];
      _compareAfterJsonSerialization(original);
    });

    test('deserialize oauth token', () {
      final tokenText = '''{
"access_token": "ya29.asldkjsaklKJKLSD_LSKDJKLSDJllkjkljsd9_2n32j3h2jkj",
"expires_in": 3599,
"refresh_token": "1//09tw-sdkjskdSKJSDKF-L9Ir8GN-XJlyFkYRNLV_SKD,SDswekwl9wqekqmxsip2OS",
"scope": "https://mail.google.com/",
"token_type": "Bearer"
}''';
      final token = OauthToken.fromText(tokenText);
      expect(token.accessToken,
          'ya29.asldkjsaklKJKLSD_LSKDJKLSDJllkjkljsd9_2n32j3h2jkj');
      expect(token.expiresIn, 3599);
      expect(token.refreshToken,
          '1//09tw-sdkjskdSKJSDKF-L9Ir8GN-XJlyFkYRNLV_SKD,SDswekwl9wqekqmxsip2OS');
      expect(token.scope, 'https://mail.google.com/');
      expect(token.tokenType, 'Bearer');
      expect(token.isExpired, isFalse);
      expect(token.isValid, isTrue);
    });

    test('serialize list of accounts', () {
      var accounts = [
        MailAccount()
          ..email = 'test@domain.com'
          ..name = 'A name with "quotes"'
          ..outgoingClientDomain = 'outgoing.com'
          ..incoming = MailServerConfig(
              serverConfig: ServerConfig(
                  type: ServerType.imap,
                  hostname: 'imap.domain.com',
                  port: 993,
                  socketType: SocketType.ssl,
                  authentication: Authentication.plain,
                  usernameType: UsernameType.emailAddress),
              authentication: PlainAuthentication('user@domain.com', 'secret'),
              serverCapabilities: [Capability('IMAP4')],
              pathSeparator: '/')
          ..outgoing = MailServerConfig(
              serverConfig: ServerConfig(
                  type: ServerType.smtp,
                  hostname: 'smtp.domain.com',
                  port: 993,
                  socketType: SocketType.ssl,
                  authentication: Authentication.plain,
                  usernameType: UsernameType.emailAddress),
              authentication: PlainAuthentication('user@domain.com', 'secret')),
        MailAccount()
          ..email = 'test2@domain2.com'
          ..name = 'my second account'
          ..outgoingClientDomain = 'outdomain.com'
          ..incoming = MailServerConfig(
              serverConfig: ServerConfig(
                  type: ServerType.imap,
                  hostname: 'imap.domain2.com',
                  port: 993,
                  socketType: SocketType.ssl,
                  authentication: Authentication.plain,
                  usernameType: UsernameType.emailAddress),
              authentication:
                  PlainAuthentication('user2@domain2.com', 'verysecret'),
              serverCapabilities: [Capability('IMAP4'), Capability('IDLE')],
              pathSeparator: '/')
          ..outgoing = MailServerConfig(
              serverConfig: ServerConfig(
                  type: ServerType.smtp,
                  hostname: 'smtp.domain2.com',
                  port: 993,
                  socketType: SocketType.ssl,
                  authentication: Authentication.plain,
                  usernameType: UsernameType.emailAddress),
              authentication:
                  PlainAuthentication('user2@domain2.com', 'topsecret')),
      ];
      final serializer = Serializer();
      var jsonText = serializer.serializeList(accounts);
      var parsedAccounts = <MailAccount>[];
      serializer.deserializeList(
          jsonText, parsedAccounts, (map) => MailAccount());

      expect(parsedAccounts.length, accounts.length);
      for (var i = 0; i < accounts.length; i++) {
        final original = accounts[i];
        final copy = parsedAccounts[i];
        expect(copy, original);
      }
    });
  });
}
