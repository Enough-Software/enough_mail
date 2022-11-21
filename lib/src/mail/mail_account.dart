import 'dart:convert';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:json_annotation/json_annotation.dart';

import '../discover/client_config.dart';
import '../imap/imap_client.dart';
import '../mail_address.dart';
import 'mail_authentication.dart';

part 'mail_account.g.dart';

/// Contains information about a single mail account
@JsonSerializable()
class MailAccount {
  /// Creates a new empty mail account
  const MailAccount({
    required this.name,
    required this.email,
    required this.incoming,
    required this.outgoing,
    this.userName = '',
    this.outgoingClientDomain = 'enough.de',
    this.supportsPlusAliases = false,
    this.aliases,
    this.attributes = const {},
  });

  /// Creates a mail account with  the given [name] for the specified [email]
  /// from the discovered [config] with a a plain authentication for the
  /// preferred incoming and preferred outgoing server.
  ///
  /// You nee to specify the [password].
  ///
  /// Specify the [userName] if it cannot be deducted from the email
  /// or the discovery config.
  ///
  /// For SMTP usage you also should define the [outgoingClientDomain],
  /// which defaults to `enough.de`.
  factory MailAccount.fromDiscoveredSettings({
    required String name,
    required String email,
    required String password,
    required ClientConfig config,
    required String userName,
    String outgoingClientDomain = 'enough.de',
    String? loginName,
    bool supportsPlusAliases = false,
    List<MailAddress>? aliases,
  }) =>
      MailAccount.fromDiscoveredSettingsWithAuth(
        name: name,
        email: email,
        userName: userName,
        auth: PlainAuthentication(
            loginName ?? getLoginName(email, config.preferredIncomingServer!),
            password),
        config: config,
        outgoingClientDomain: outgoingClientDomain,
        supportsPlusAliases: supportsPlusAliases,
        aliases: aliases,
      );

  /// Creates a mail account with  the given [name] from the discovered [config]
  /// with the given [auth] for the preferred incoming and
  /// preferred outgoing server.
  ///
  /// Optionally specify a different [outgoingAuth] if needed.
  /// For SMTP usage you also should define the [outgoingClientDomain],
  /// which defaults to `enough.de`.
  factory MailAccount.fromDiscoveredSettingsWithAuth({
    required String name,
    required String email,
    required MailAuthentication auth,
    required ClientConfig config,
    String userName = '',
    String outgoingClientDomain = 'enough.de',
    MailAuthentication? outgoingAuth,
    bool supportsPlusAliases = false,
    List<MailAddress>? aliases,
  }) {
    final incoming = MailServerConfig(
      authentication: auth,
      serverConfig:
          config.preferredIncomingImapServer ?? config.preferredIncomingServer!,
    );
    final outgoing = MailServerConfig(
      authentication: outgoingAuth ?? auth,
      serverConfig: config.preferredOutgoingServer!,
    );
    return MailAccount(
      name: name,
      email: email,
      incoming: incoming,
      outgoing: outgoing,
      userName: userName,
      outgoingClientDomain: outgoingClientDomain,
      supportsPlusAliases: supportsPlusAliases,
      aliases: aliases,
    );
  }

  /// Creates a mail account from manual settings
  /// with a simple user-name/password authentication.
  ///
  /// You need to specify the account [name], the associated [email],
  /// the [incomingHost], [outgoingHost] and [password].
  ///
  /// When the [userName] is different from the email,
  /// it must also be specified.
  ///
  /// You should specify the [outgoingClientDomain] for sending messages,
  /// this defaults to `enough.de`.
  ///
  /// The [incomingType] defaults to [ServerType.imap], the [incomingPort]
  /// to `993` and the [incomingSocketType] to [SocketType.ssl].
  ///
  /// The [outgoingType] defaults to [ServerType.smtp], the [outgoingPort]
  /// to `465` and the [outgoingSocketType] to [SocketType.ssl].
  factory MailAccount.fromManualSettings({
    required String name,
    required String email,
    required String incomingHost,
    required String outgoingHost,
    required String password,
    String userName = '',
    ServerType incomingType = ServerType.imap,
    ServerType outgoingType = ServerType.smtp,
    String? loginName,
    String outgoingClientDomain = 'enough.de',
    int incomingPort = 993,
    int outgoingPort = 465,
    SocketType incomingSocketType = SocketType.ssl,
    SocketType outgoingSocketType = SocketType.ssl,
    bool supportsPlusAliases = false,
    List<MailAddress>? aliases,
  }) =>
      MailAccount.fromManualSettingsWithAuth(
        name: name,
        email: email,
        userName: userName,
        incomingHost: incomingHost,
        outgoingHost: outgoingHost,
        auth: PlainAuthentication(loginName ?? email, password),
        incomingType: incomingType,
        outgoingType: outgoingType,
        outgoingClientDomain: outgoingClientDomain,
        incomingPort: incomingPort,
        outgoingPort: outgoingPort,
        incomingSocketType: incomingSocketType,
        outgoingSocketType: outgoingSocketType,
        supportsPlusAliases: supportsPlusAliases,
        aliases: aliases,
      );

  /// Creates a mail account from manual settings with the specified [auth].
  ///
  /// You need to specify the account [name], the associated [email],
  /// the [incomingHost], [outgoingHost] and [auth].
  ///
  /// You can specify a different authentication for the outgoing server using
  /// the [outgoingAuth] parameter.
  ///
  /// You should specify the [outgoingClientDomain] for sending messages,
  /// this defaults to `enough.de`.
  ///
  /// The [incomingType] defaults to [ServerType.imap], the [incomingPort] to
  /// `993` and the [incomingSocketType] to [SocketType.ssl].
  ///
  /// The [outgoingType] defaults to [ServerType.smtp], the [outgoingPort] to
  /// `465` and the [outgoingSocketType] to [SocketType.ssl].
  factory MailAccount.fromManualSettingsWithAuth({
    required String name,
    required String email,
    required String incomingHost,
    required String outgoingHost,
    required MailAuthentication auth,
    String userName = '',
    ServerType incomingType = ServerType.imap,
    ServerType outgoingType = ServerType.smtp,
    MailAuthentication? outgoingAuth,
    String outgoingClientDomain = 'enough.de',
    incomingPort = 993,
    outgoingPort = 465,
    SocketType incomingSocketType = SocketType.ssl,
    SocketType outgoingSocketType = SocketType.ssl,
    bool supportsPlusAliases = false,
    List<MailAddress>? aliases,
  }) {
    final incoming = MailServerConfig(
      authentication: auth,
      serverConfig: ServerConfig(
        type: incomingType,
        hostname: incomingHost,
        port: incomingPort,
        socketType: incomingSocketType,
      ),
    );
    final outgoing = MailServerConfig(
      authentication: outgoingAuth ?? auth,
      serverConfig: ServerConfig(
        type: outgoingType,
        hostname: outgoingHost,
        port: outgoingPort,
        socketType: outgoingSocketType,
      ),
    );
    return MailAccount(
      name: name,
      email: email,
      incoming: incoming,
      outgoing: outgoing,
      userName: userName,
      outgoingClientDomain: outgoingClientDomain,
      supportsPlusAliases: supportsPlusAliases,
      aliases: aliases,
    );
  }

  /// Creates a new [MailAccount] from the given [json]
  factory MailAccount.fromJson(Map<String, dynamic> json) =>
      _$MailAccountFromJson(json);

  /// Generates JSON from this [MailAccount]
  Map<String, dynamic> toJson() => _$MailAccountToJson(this);

  /// The name of the account
  final String name;

  /// The associated name of the user such as `First Last`, e.g. `Andrea Ghez`
  final String userName;

  /// The email address of the user
  final String email;

  /// Incoming mail settings
  final MailServerConfig incoming;

  /// Outgoing mail settings
  final MailServerConfig outgoing;

  /// The domain that is reported to the outgoing SMTP service
  final String outgoingClientDomain;

  /// Convenience getter for the from MailAddress
  MailAddress get fromAddress => MailAddress(userName, email);

  /// Optional list of associated aliases
  final List<MailAddress>? aliases;

  /// Optional indicator if the mail service supports + based aliases
  ///
  /// E.g. `user+alias@domain.com`.
  final bool supportsPlusAliases;

  /// Further attributes
  ///
  /// Note that you need to specify these attributes in case you want them,
  /// by default an unmodifiable `const {}` is used.
  final Map<String, dynamic> attributes;

  /// Checks if this account has an attribute with the specified name
  bool hasAttribute(String name) => attributes.containsKey(name);

  /// Retrieves the user name from the given [email] and
  /// the discovered [serverConfig].
  ///
  /// Defaults to the email when the serverConfig does not contain any rules.
  static String getLoginName(String email, ServerConfig serverConfig) =>
      serverConfig.getUserName(email) ?? email;

  @override
  bool operator ==(Object other) =>
      other is MailAccount &&
      other.name == name &&
      other.userName == userName &&
      other.email == email &&
      other.outgoingClientDomain == outgoingClientDomain &&
      other.incoming == incoming &&
      other.outgoing == outgoing &&
      other.supportsPlusAliases == supportsPlusAliases &&
      other.aliases?.length == aliases?.length &&
      other.attributes.length == attributes.length;

  @override
  int get hashCode => name.hashCode | email.hashCode;

  @override
  String toString() => jsonEncode(toJson());

  /// Creates a new [MailAccount] with the given settings or by copying
  /// the current settings.
  MailAccount copyWith({
    String? name,
    String? email,
    String? userName,
    MailServerConfig? incoming,
    MailServerConfig? outgoing,
    List<MailAddress>? aliases,
    Map<String, dynamic>? attributes,
    String? outgoingClientDomain,
    bool? supportsPlusAliases,
  }) =>
      MailAccount(
        name: name ?? this.name,
        email: email ?? this.email,
        userName: userName ?? this.userName,
        incoming: incoming ?? this.incoming,
        outgoing: outgoing ?? this.outgoing,
        aliases: aliases ?? this.aliases,
        outgoingClientDomain: outgoingClientDomain ?? this.outgoingClientDomain,
        supportsPlusAliases: supportsPlusAliases ?? this.supportsPlusAliases,
        attributes: attributes ?? this.attributes,
      );
}

/// Configuration of a specific mail service like IMAP, POP3 or SMTP
@JsonSerializable()
class MailServerConfig {
  /// Creates a new mail server configuration
  const MailServerConfig({
    required this.serverConfig,
    required this.authentication,
    this.serverCapabilities = const [],
    this.pathSeparator = '/',
  });

  /// Creates a new [MailServerConfig] from the given [json]
  factory MailServerConfig.fromJson(Map<String, dynamic> json) =>
      _$MailServerConfigFromJson(json);

  /// Converts this [MailServerConfig] to JSON
  Map<String, dynamic> toJson() => _$MailServerConfigToJson(this);

  /// The server configuration like host, port and socket type
  final ServerConfig serverConfig;

  /// The authentication like [PlainAuthentication] or [OauthAuthentication]
  final MailAuthentication authentication;

  /// Capabilities of the server
  final List<Capability> serverCapabilities;

  /// Path separator of the server, e.g. `/`
  final String pathSeparator;

  /// Checks of the given capability is supported
  bool supports(String capabilityName) =>
      serverCapabilities.firstWhereOrNull((c) => c.name == capabilityName) !=
      null;

  @override
  bool operator ==(Object other) =>
      other is MailServerConfig &&
      other.pathSeparator == pathSeparator &&
      other.serverCapabilities.length == serverCapabilities.length &&
      other.authentication == authentication &&
      other.serverConfig == serverConfig;

  @override
  int get hashCode => serverConfig.hashCode | authentication.hashCode;

  @override
  String toString() => jsonEncode(toJson());

  /// Copies this [MailServerConfig] with the given values
  MailServerConfig copyWith({
    ServerConfig? serverConfig,
    MailAuthentication? authentication,
    String? pathSeparator,
    List<Capability>? serverCapabilities,
  }) =>
      MailServerConfig(
        serverConfig: serverConfig ?? this.serverConfig,
        authentication: authentication ?? this.authentication,
        pathSeparator: pathSeparator ?? this.pathSeparator,
        serverCapabilities: serverCapabilities ?? this.serverCapabilities,
      );
}
