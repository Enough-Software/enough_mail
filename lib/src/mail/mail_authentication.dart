import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

import '../discover/client_config.dart';
import '../exception.dart';
import '../imap/imap_client.dart';
import '../pop/pop_client.dart';
import '../smtp/smtp_client.dart';

part 'mail_authentication.g.dart';

/// Contains an authentication for a mail service
/// Compare [PlainAuthentication] and [OauthAuthentication] for implementations.
abstract class MailAuthentication {
  /// Creates a new authentication with the given [typeName]
  const MailAuthentication(this.typeName);

  /// Creates a new [MailAuthentication] from the given [json]
  factory MailAuthentication.fromJson(Map<String, dynamic> json) {
    final typeName = json['typeName'];
    switch (typeName) {
      case _typePlain:
        return PlainAuthentication.fromJson(json);
      case _typeOauth:
        return OauthAuthentication.fromJson(json);
    }
    throw InvalidArgumentException(
        'unsupported MailAuthentication type [$typeName]');
  }

  /// Converts this [MailAuthentication] to JSON
  Map<String, dynamic> toJson();

  static const String _typePlain = 'plain';
  static const String _typeOauth = 'oauth';

  /// The name of this authentication type, e.g. `plain` or `oauth`
  final String typeName;

  /// Authenticates with the specified mail service
  Future<void> authenticate(
    ServerConfig serverConfig, {
    ImapClient? imap,
    PopClient? pop,
    SmtpClient? smtp,
  });
}

/// Base class for authentications with user-names
abstract class UserNameBasedAuthentication extends MailAuthentication {
  /// Creates a new user name based auth
  const UserNameBasedAuthentication(this.userName, String typeName)
      : super(typeName);

  /// The user name
  final String userName;
}

/// Provides a simple username-password authentication
@JsonSerializable()
class PlainAuthentication extends UserNameBasedAuthentication {
  /// Creates a new plain authentication
  /// with the given [userName] and [password].
  const PlainAuthentication(String userName, this.password)
      : super(userName, MailAuthentication._typePlain);

  /// Creates a new [PlainAuthentication] from the given [json]
  factory PlainAuthentication.fromJson(Map<String, dynamic> json) =>
      _$PlainAuthenticationFromJson(json);

  /// Converts this [PlainAuthentication] to JSON
  @override
  Map<String, dynamic> toJson() =>
      _$PlainAuthenticationToJson(this)..['typeName'] = typeName;

  /// The password
  final String password;

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
        throw InvalidArgumentException(
            'Unknown server type ${serverConfig.typeName}');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PlainAuthentication &&
      other.userName == userName &&
      other.password == password;

  @override
  int get hashCode => userName.hashCode | password.hashCode;
}

/// Contains an OAuth compliant token
@JsonSerializable()
class OauthToken {
  /// Creates a new token
  const OauthToken({
    required this.accessToken,
    required this.expiresIn,
    required this.refreshToken,
    required this.scope,
    required this.tokenType,
    required this.created,
    this.provider,
  });

  /// Creates a new [OauthToken] from the given [json]
  factory OauthToken.fromJson(Map<String, dynamic> json) =>
      _$OauthTokenFromJson(json);

  /// Parses a new token from the given [text].
  factory OauthToken.fromText(String text, {String? provider}) {
    final json = jsonDecode(text);
    if (provider != null) {
      json['provider'] = provider;
    }
    if (json['created'] == null) {
      json['created'] = DateTime.now().toUtc().toIso8601String();
    }
    return OauthToken.fromJson(json);
  }

  /// Converts this [OauthToken] to JSON.
  Map<String, dynamic> toJson() => _$OauthTokenToJson(this);

  /// Token for API access
  @JsonKey(name: 'access_token')
  final String accessToken;

  /// Expiration in seconds from [created] time
  @JsonKey(name: 'expires_in')
  final int expiresIn;

  /// Token for refreshing the [accessToken]
  @JsonKey(name: 'refresh_token')
  final String refreshToken;

  /// Granted scope(s) for access
  final String scope;

  /// Type of the token
  @JsonKey(name: 'token_type')
  final String tokenType;

  /// UTC time of creation of this token
  ///
  /// Typically `DateTime.now().toUtc()`
  final DateTime created;

  /// Optional, implementation-specific provider
  final String? provider;

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
        created: DateTime.now().toUtc(),
      );

  @override
  String toString() => jsonEncode(toJson());
}

/// Provides an OAuth-compliant authentication
@JsonSerializable()
class OauthAuthentication extends UserNameBasedAuthentication {
  /// Creates a new authentication
  const OauthAuthentication(String userName, this.token)
      : super(userName, MailAuthentication._typeOauth);

  /// Creates a new [OauthAuthentication] from the given [json]
  factory OauthAuthentication.fromJson(Map<String, dynamic> json) =>
      _$OauthAuthenticationFromJson(json);

  /// Creates an OauthAuthentication from the given [userName]
  /// and [oauthTokenText] in JSON.
  ///
  /// Optionally specify the [provider] for identifying tokens later.
  factory OauthAuthentication.from(
    String userName,
    String oauthTokenText, {
    String? provider,
  }) {
    final token = OauthToken.fromText(oauthTokenText, provider: provider);
    return OauthAuthentication(userName, token);
  }

  /// Converts this [OauthAuthentication] to JSON.
  @override
  Map<String, dynamic> toJson() =>
      _$OauthAuthenticationToJson(this)..['typeName'] = typeName;

  /// Token for the access
  final OauthToken token;

  @override
  Future<void> authenticate(ServerConfig serverConfig,
      {ImapClient? imap, PopClient? pop, SmtpClient? smtp}) async {
    final userName = this.userName;
    final accessToken = token.accessToken;
    switch (serverConfig.type) {
      case ServerType.imap:
        await imap!.authenticateWithOAuth2(userName, accessToken);
        break;
      case ServerType.pop:
        await pop!.login(userName, accessToken);
        break;
      case ServerType.smtp:
        await smtp!.authenticate(userName, accessToken, AuthMechanism.xoauth2);
        break;
      default:
        throw InvalidArgumentException(
            'Unknown server type ${serverConfig.typeName}');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is OauthAuthentication &&
      other.userName == userName &&
      other.token.accessToken == token.accessToken;

  @override
  int get hashCode => userName.hashCode | token.hashCode;

  /// Copies this [OauthAuthentication] with the given [token]
  OauthAuthentication copyWith(OauthToken token) =>
      OauthAuthentication(userName, token);
}
