import 'package:enough_mail/src/discover/client_config.dart';
import 'package:enough_mail/src/imap/imap_client.dart';
import 'package:enough_mail/src/pop/pop_client.dart';
import 'package:enough_mail/src/smtp/smtp_client.dart';
import 'package:enough_serialization/enough_serialization.dart';

/// Contains an authentication for a mail service
/// Compare [PlainAuthentication] and [OauthAuthentication] for implementations.
abstract class MailAuthentication extends SerializableObject {
  static const String _typePlain = 'plain';
  static const String _typeOauth = 'oauth';
  String? get typeName => attributes['typeName'];
  set typeName(String? value) => attributes['typeName'] = value;

  MailAuthentication(String typeName) {
    this.typeName = typeName;
  }

  /// Authenticates with the specified mail service
  Future<void> authenticate(ServerConfig serverConfig,
      {ImapClient? imap, PopClient? pop, SmtpClient? smtp});

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
  /// Gets the user name
  String get userName => attributes['userName'];

  /// Sets the user name
  set userName(String value) => attributes['userName'] = value;

  UserNameBasedAuthentication(String? userName, String typeName)
      : super(typeName) {
    if (userName != null) {
      this.userName = userName;
    }
  }
}

/// Provides a simple username-password authentication
class PlainAuthentication extends UserNameBasedAuthentication {
  /// gets the password
  String get password => attributes['password'];

  /// sets the password
  set password(String value) => attributes['password'] = value;

  /// Creates a new plain authentication with the given [userName] and [password].
  PlainAuthentication(String? userName, String? password)
      : super(userName, MailAuthentication._typePlain) {
    if (password != null) {
      this.password = password;
    }
  }

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
  bool operator ==(o) =>
      o is PlainAuthentication &&
      o.userName == userName &&
      o.password == password;
}

/// Contains an OAuth compliant token
class OauthToken extends SerializableObject {
  /// Gets the token for API access
  String get accessToken => attributes['access_token'];

  /// Sets the token for API access
  set accessToken(String value) => attributes['access_token'] = value;

  /// Gets the expiration in seconds from [created] time
  int get expiresIn => attributes['expires_in'];

  /// Sets the expiration in seconds from [created] time
  set expiresIn(int value) => attributes['expires_in'] = value;

  /// Gets the token for refreshing the [accessToken]
  String get refreshToken => attributes['refresh_token'];

  /// Sets the token for refreshing the [accessToken]
  set refreshToken(String value) => attributes['refresh_token'] = value;

  /// Gets the granted scope(s) for access
  String get scope => attributes['scope'];

  /// Sets the granted scope(s) for access
  set scope(String value) => attributes['scope'] = value;

  /// Gets the token type
  String get tokenType => attributes['token_type'];

  /// Sets the token type
  set tokenType(String value) => attributes['token_type'] = value;

  /// Gets the UTC time of creation of this token
  DateTime get created =>
      DateTime.fromMillisecondsSinceEpoch(attributes['created'], isUtc: true);

  /// Sets the UTC time of creation of this token
  set created(DateTime value) =>
      attributes['created'] = value.millisecondsSinceEpoch;

  /// Gets the optional, implementation-specific provider
  String? get provider => attributes['provider'];

  /// Sets the optional, implementation-specific provider
  set provider(String? value) => attributes['provider'] = value;

  /// Checks if this token is expired
  bool get isExpired => expiresDateTime.isBefore(DateTime.now().toUtc());

  /// Retrieves the expiry date time
  DateTime get expiresDateTime => created.add(Duration(seconds: expiresIn));

  /// Checks if this token is still valid, ie not expired
  bool get isValid => !isExpired;

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

  /// Refreshes this token with the new [accessToken] and [expiresIn].
  OauthToken copyWith(String accessToken, int expiresIn) {
    return OauthToken(
      accessToken: accessToken,
      expiresIn: expiresIn,
      refreshToken: refreshToken,
      scope: scope,
      tokenType: tokenType,
      provider: provider,
    );
  }

  @override
  String toString() {
    return Serializer().serialize(this);
  }

  static OauthToken fromText(String text, {String? provider}) {
    final token = OauthToken();
    Serializer().deserialize(text, token);
    if (provider != null) {
      token.provider = provider;
    }
    return token;
  }
}

/// Provides an OAuth-compliant authentication
class OauthAuthentication extends UserNameBasedAuthentication {
  OauthToken get token => attributes['token'];
  set token(OauthToken value) => attributes['token'] = value;

  OauthAuthentication(String? userName, OauthToken? token)
      : super(userName, MailAuthentication._typeOauth) {
    if (token != null) {
      this.token = token;
    }
    objectCreators['token'] = (map) => OauthToken();
  }

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
  bool operator ==(o) =>
      o is OauthAuthentication &&
      o.userName == userName &&
      o.token.accessToken == token.accessToken;

  /// Creates an OauthAuthentication from the given [userName] and [oauthTokenText] in JSON.
  ///
  /// Optionally specify the [provider] for identifying tokens later.
  static OauthAuthentication from(String userName, String oauthTokenText,
      {String? provider}) {
    final token = OauthToken.fromText(oauthTokenText);
    if (provider != null) {
      token.provider = provider;
    }
    return OauthAuthentication(userName, token);
  }
}
