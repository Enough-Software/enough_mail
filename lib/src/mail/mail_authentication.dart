import 'package:enough_mail/src/discover/client_config.dart';
import 'package:enough_mail/src/imap/imap_client.dart';
import 'package:enough_mail/src/pop/pop_client.dart';
import 'package:enough_mail/src/smtp/smtp_client.dart';
import 'package:enough_serialization/enough_serialization.dart';

/// Contains an authentication for a mail service
/// Compare [PlainAuthentication] and [OauthAuthentication] for implementations.
abstract class MailAuthentication extends SerializableObject {
  /// Creates a new authentication with the given [typeName]
  MailAuthentication(String typeName) {
    this.typeName = typeName;
  }

  static const String _typePlain = 'plain';
  static const String _typeOauth = 'oauth';

  /// The name of this authentication type, e.g. `plain` or `oauth`
  String? get typeName => attributes['typeName'];
  set typeName(String? value) => attributes['typeName'] = value;

  /// Authenticates with the specified mail service
  Future<void> authenticate(ServerConfig serverConfig,
      {ImapClient? imap, PopClient? pop, SmtpClient? smtp});

  /// Factory to create a new mailauthentication depending on the type
  static MailAuthentication createType(String typeName) {
    switch (typeName) {
      case _typePlain:
        return PlainAuthentication(null, null);
      case _typeOauth:
        return OauthAuthentication(null, null);
    }
    throw StateError('unsupported MailAuthentication type [$typeName]');
  }
}

/// Base class for authentications with user-names
abstract class UserNameBasedAuthentication extends MailAuthentication {
  /// Creates a new user name based auth
  UserNameBasedAuthentication(String? userName, String typeName)
      : super(typeName) {
    if (userName != null) {
      this.userName = userName;
    }
  }

  /// The user name
  String get userName => attributes['userName'];
  set userName(String value) => attributes['userName'] = value;
}

/// Provides a simple username-password authentication
class PlainAuthentication extends UserNameBasedAuthentication {
  /// Creates a new plain authentication
  /// with the given [userName] and [password].
  PlainAuthentication(String? userName, String? password)
      : super(userName, MailAuthentication._typePlain) {
    if (password != null) {
      this.password = password;
    }
  }

  /// The password
  String get password => attributes['password'];
  set password(String value) => attributes['password'] = value;

  @override
  Future<void> authenticate(ServerConfig serverConfig,
      {ImapClient? imap, PopClient? pop, SmtpClient? smtp}) async {
    final name = userName;
    final pwd = password;
    switch (serverConfig.type) {
      case ServerType.imap:
        await imap!.login(name, pwd);
        break;
      case ServerType.pop:
        await pop!.login(name, pwd);
        break;
      case ServerType.smtp:
        final authMechanism = smtp!.serverInfo.supportsAuth(AuthMechanism.plain)
            ? AuthMechanism.plain
            : smtp.serverInfo.supportsAuth(AuthMechanism.login)
                ? AuthMechanism.login
                : AuthMechanism.cramMd5;
        await smtp.authenticate(name, pwd, authMechanism);
        break;
      default:
        throw StateError('Unknown server type ${serverConfig.typeName}');
    }
  }

  @override
  bool operator ==(Object o) =>
      o is PlainAuthentication &&
      o.userName == userName &&
      o.password == password;

  @override
  int get hashCode => userName.hashCode | password.hashCode;
}

/// Contains an OAuth compliant token
class OauthToken extends SerializableObject {
  /// Creates a new token
  OauthToken({
    String? accessToken,
    int? expiresIn,
    String? refreshToken,
    String? scope,
    String? tokenType,
    String? provider,
  }) {
    created = DateTime.now().toUtc();
    if (accessToken != null) {
      this.accessToken = accessToken;
    }
    if (expiresIn != null) {
      this.expiresIn = expiresIn;
    }
    if (refreshToken != null) {
      this.refreshToken = refreshToken;
    }
    if (scope != null) {
      this.scope = scope;
    }
    if (tokenType != null) {
      this.tokenType = tokenType;
    }
    if (provider != null) {
      this.provider = provider;
    }
  }

  /// Parses a new token from the given [text].
  OauthToken.fromText(String text, {String? provider}) {
    Serializer().deserialize(text, this);
    if (provider != null) {
      this.provider = provider;
    }
  }

  /// Token for API access
  String get accessToken => attributes['access_token'];
  set accessToken(String value) => attributes['access_token'] = value;

  /// Expiration in seconds from [created] time
  int get expiresIn => attributes['expires_in'];
  set expiresIn(int value) => attributes['expires_in'] = value;

  /// Token for refreshing the [accessToken]
  String get refreshToken => attributes['refresh_token'];
  set refreshToken(String value) => attributes['refresh_token'] = value;

  /// Granted scope(s) for access
  String get scope => attributes['scope'];
  set scope(String value) => attributes['scope'] = value;

  /// Type of the token
  String get tokenType => attributes['token_type'];
  set tokenType(String value) => attributes['token_type'] = value;

  /// UTC time of creation of this token
  DateTime get created =>
      DateTime.fromMillisecondsSinceEpoch(attributes['created'], isUtc: true);
  set created(DateTime value) =>
      attributes['created'] = value.millisecondsSinceEpoch;

  /// Optional, implementation-specific provider
  String? get provider => attributes['provider'];
  set provider(String? value) => attributes['provider'] = value;

  /// Checks if this token is expired
  bool get isExpired => expiresDateTime.isBefore(DateTime.now().toUtc());

  /// Retrieves the expiry date time
  DateTime get expiresDateTime => created.add(Duration(seconds: expiresIn));

  /// Checks if this token is still valid, ie not expired
  bool get isValid => !isExpired;

  /// Refreshes this token with the new [accessToken] and [expiresIn].
  OauthToken copyWith(String accessToken, int expiresIn) => OauthToken(
        accessToken: accessToken,
        expiresIn: expiresIn,
        refreshToken: refreshToken,
        scope: scope,
        tokenType: tokenType,
        provider: provider,
      );

  @override
  String toString() => Serializer().serialize(this);
}

/// Provides an OAuth-compliant authentication
class OauthAuthentication extends UserNameBasedAuthentication {
  /// Creates a new authentication
  OauthAuthentication(String? userName, OauthToken? token)
      : super(userName, MailAuthentication._typeOauth) {
    if (token != null) {
      this.token = token;
    }
    objectCreators['token'] = (map) => OauthToken();
  }

  /// Creates an OauthAuthentication from the given [userName]
  /// and [oauthTokenText] in JSON.
  ///
  /// Optionally specify the [provider] for identifying tokens later.
  OauthAuthentication.from(String userName, String oauthTokenText,
      {String? provider})
      : super(userName, MailAuthentication._typeOauth) {
    final token = OauthToken.fromText(oauthTokenText);
    if (provider != null) {
      token.provider = provider;
    }
    this.token = token;
  }

  /// Token for the access
  OauthToken get token => attributes['token'];
  set token(OauthToken value) => attributes['token'] = value;

  @override
  Future<void> authenticate(ServerConfig serverConfig,
      {ImapClient? imap, PopClient? pop, SmtpClient? smtp}) async {
    final name = userName;
    final tkn = token;
    final accessToken = tkn.accessToken;
    switch (serverConfig.type) {
      case ServerType.imap:
        await imap!.authenticateWithOAuth2(name, accessToken);
        break;
      case ServerType.pop:
        await pop!.login(name, accessToken);
        break;
      case ServerType.smtp:
        await smtp!.authenticate(name, accessToken, AuthMechanism.xoauth2);
        break;
      default:
        throw StateError('Unknown server type ${serverConfig.typeName}');
    }
  }

  @override
  bool operator ==(Object o) =>
      o is OauthAuthentication &&
      o.userName == userName &&
      o.token.accessToken == token.accessToken;

  @override
  int get hashCode => userName.hashCode | token.hashCode;
}
