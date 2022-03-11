import 'package:collection/collection.dart' show IterableExtension;
import 'package:enough_serialization/enough_serialization.dart';

import '../discover/client_config.dart';
import '../imap/imap_client.dart';
import '../mail_address.dart';
import 'mail_authentication.dart';

/// Contains information about a single mail account
class MailAccount extends SerializableObject {
  /// Creates a new empty mail account
  MailAccount() {
    _initSerialization();
  }

  /// Creates a mail account with  the given [name] for the specified [email]
  /// from the discovered [config] with a a plain authentication for the
  /// preferred incoming and preferred outgoing server.
  ///
  /// You nee to specify the [password].
  /// Specify the [userName] if it cannot be deducted from the email
  /// or the discovery config.
  /// For SMTP usage you also should define the [outgoingClientDomain],
  /// which defaults to `enough.de`.
  MailAccount.fromDiscoveredSettings(
      String name, String email, String password, ClientConfig config,
      {String? userName, String outgoingClientDomain = 'enough.de'})
      : this.fromDiscoveredSettingsWithAuth(
          name,
          email,
          PlainAuthentication(
              userName ?? getUserName(email, config.preferredIncomingServer!),
              password),
          config,
          outgoingClientDomain: outgoingClientDomain,
        );

  /// Creates a mail account with  the given [name] from the discovered [config]
  /// with the given [auth] for the preferred incoming and
  /// preferred outgoing server.
  ///
  /// Optionally specify a different [outgoingAuth] if needed.
  /// For SMTP usage you also should define the [outgoingClientDomain],
  /// which defaults to `enough.de`.
  MailAccount.fromDiscoveredSettingsWithAuth(
      String name, String email, MailAuthentication auth, ClientConfig config,
      {String outgoingClientDomain = 'enough.de',
      MailAuthentication? outgoingAuth}) {
    _initSerialization();
    final incoming = MailServerConfig()
      ..authentication = auth
      ..serverConfig =
          config.preferredIncomingImapServer ?? config.preferredIncomingServer;
    final outgoing = MailServerConfig()
      ..authentication = outgoingAuth ?? auth
      ..serverConfig = config.preferredOutgoingServer;
    this.name = name;
    this.email = email;
    this.incoming = incoming;
    this.outgoing = outgoing;
    this.outgoingClientDomain = outgoingClientDomain;
  }

  /// Creates a mail account from manual settings
  /// with a simple user-name/password authentication.
  ///
  /// You need to specify the account [name], the associated [email],
  /// the [incomingHost], [outgoingHost] and [password].
  /// When the [userName] is different from the email,
  /// it must also be specified.
  /// You should specify the [outgoingClientDomain] for sending messages,
  /// this defaults to `enough.de`.
  /// The [incomingType] defaults to [ServerType.imap], the [incomingPort]
  /// to `993` and the [incomingSocketType] to [SocketType.ssl].
  /// The [outgoingType] defaults to [ServerType.smtp], the [outgoingPort]
  /// to `465` and the [outgoingSocketType] to [SocketType.ssl].
  MailAccount.fromManualSettings(
    String name,
    String email,
    String incomingHost,
    String outgoingHost,
    String password, {
    ServerType incomingType = ServerType.imap,
    ServerType outgoingType = ServerType.smtp,
    String? userName,
    String outgoingClientDomain = 'enough.de',
    int incomingPort = 993,
    int outgoingPort = 465,
    SocketType incomingSocketType = SocketType.ssl,
    SocketType outgoingSocketType = SocketType.ssl,
  }) : this.fromManualSettingsWithAuth(
          name,
          email,
          incomingHost,
          outgoingHost,
          PlainAuthentication(userName ?? email, password),
          incomingType: incomingType,
          outgoingType: outgoingType,
          outgoingClientDomain: outgoingClientDomain,
          incomingPort: incomingPort,
          outgoingPort: outgoingPort,
          incomingSocketType: incomingSocketType,
          outgoingSocketType: outgoingSocketType,
        );

  /// Creates a mail account from manual settings with the specified [auth].
  ///
  /// You need to specify the account [name], the associated [email],
  /// the [incomingHost], [outgoingHost] and [auth].
  /// You can specify a different authentication for the outgoing server using
  /// the [outgoingAuth] parameter.
  /// You should specify the [outgoingClientDomain] for sending messages,
  /// this defaults to `enough.de`.
  /// The [incomingType] defaults to [ServerType.imap], the [incomingPort] to
  /// `993` and the [incomingSocketType] to [SocketType.ssl].
  /// The [outgoingType] defaults to [ServerType.smtp], the [outgoingPort] to
  /// `465` and the [outgoingSocketType] to [SocketType.ssl].
  MailAccount.fromManualSettingsWithAuth(
    String name,
    String email,
    String incomingHost,
    String outgoingHost,
    MailAuthentication auth, {
    ServerType incomingType = ServerType.imap,
    ServerType outgoingType = ServerType.smtp,
    MailAuthentication? outgoingAuth,
    String outgoingClientDomain = 'enough.de',
    incomingPort = 993,
    outgoingPort = 465,
    SocketType incomingSocketType = SocketType.ssl,
    SocketType outgoingSocketType = SocketType.ssl,
  }) {
    _initSerialization();
    final incoming = MailServerConfig()
      ..authentication = auth
      ..serverConfig = ServerConfig(
        type: incomingType,
        hostname: incomingHost,
        port: incomingPort,
        socketType: incomingSocketType,
      );
    final outgoing = MailServerConfig()
      ..authentication = outgoingAuth ?? auth
      ..serverConfig = ServerConfig(
        type: outgoingType,
        hostname: outgoingHost,
        port: outgoingPort,
        socketType: outgoingSocketType,
      );
    this.name = name;
    this.email = email;
    this.incoming = incoming;
    this.outgoing = outgoing;
    this.outgoingClientDomain = outgoingClientDomain;
  }

  void _initSerialization() {
    // serialization settings:
    objectCreators['incoming'] = (map) => MailServerConfig();
    objectCreators['outgoing'] = (map) => MailServerConfig();
    objectCreators['aliases'] = (map) => <MailAddress>[];
    objectCreators['aliases.value'] = (map) => MailAddress.empty();
  }

  /// The name of the account
  String? get name => attributes['name'];
  set name(String? value) => attributes['name'] = value;

  /// The associated name of the user such as `user@domain.com`
  String? get userName => attributes['userName'];
  set userName(String? value) => attributes['userName'] = value;

  /// The email address of the user
  String? get email => attributes['email'];
  set email(String? value) => attributes['email'] = value;

  /// Incoming mail settings
  MailServerConfig? get incoming => attributes['incoming'];
  set incoming(MailServerConfig? value) => attributes['incoming'] = value;

  /// Outgoing mail settings
  MailServerConfig? get outgoing => attributes['outgoing'];
  set outgoing(MailServerConfig? value) => attributes['outgoing'] = value;

  /// The domain that is reported to the outgoing SMTP service
  String get outgoingClientDomain =>
      attributes['outgoingClientDomain'] ?? 'enough.de';
  set outgoingClientDomain(String value) =>
      attributes['outgoingClientDomain'] = value;

  /// Convenience getter for the from MailAddress
  MailAddress get fromAddress => MailAddress(userName, email!);

  /// Optional list of associated aliases
  List<MailAddress>? get aliases => attributes['aliases'];
  set aliases(List<MailAddress>? value) => attributes['aliases'] = value;

  /// Optional indicator if the mail service supports + based aliases
  ///
  /// E.g. `user+alias@domain.com`.
  bool get supportsPlusAliases => attributes['supportsPlusAliases'] ?? false;
  set supportsPlusAliases(bool value) =>
      attributes['supportsPlusAliases'] = value;

  /// Checks if this account has an attribute with the specified name
  bool hasAttribute(String name) => attributes.containsKey(name);

  /// Retrieves the user name from the given [email] and
  /// the discovered [serverConfig].
  ///
  /// Defaults to the email when the serverConfig does not contain any rules.
  static String getUserName(String email, ServerConfig serverConfig) =>
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
  int get hashCode => (name?.hashCode ?? 0) | (email?.hashCode ?? 0);

  @override
  String toString() => Serializer().serialize(this);
}

/// Configuration of a specific mail service like IMAP, POP3 or SMTP
class MailServerConfig extends SerializableObject {
  /// Creates a new mail server configuration
  MailServerConfig(
      {ServerConfig? serverConfig,
      MailAuthentication? authentication,
      List<Capability>? serverCapabilities,
      String? pathSeparator}) {
    this.serverConfig = serverConfig;
    this.authentication = authentication;
    this.serverCapabilities = serverCapabilities;
    this.pathSeparator = pathSeparator;
    objectCreators['serverConfig'] = (map) => ServerConfig();
    objectCreators['authentication'] =
        (map) => MailAuthentication.createType(map!['typeName']);
    objectCreators['serverCapabilities'] = (map) => <Capability>[];
    objectCreators['serverCapabilities.value'] = (map) => Capability('');
  }

  /// The server configuration like host, port and socket type
  ServerConfig? get serverConfig => attributes['serverConfig'];
  set serverConfig(ServerConfig? value) => attributes['serverConfig'] = value;

  /// The authentication like [PlainAuthentication] or [OauthAuthentication]
  MailAuthentication? get authentication => attributes['authentication'];
  set authentication(MailAuthentication? value) =>
      attributes['authentication'] = value;

  /// Capabilities of the server
  List<Capability>? get serverCapabilities => attributes['serverCapabilities'];
  set serverCapabilities(List<Capability>? value) =>
      attributes['serverCapabilities'] = value;

  /// Path separator of the server, e.g. `/`
  String? get pathSeparator => attributes['pathSeparator'];
  set pathSeparator(String? value) => attributes['pathSeparator'] = value;

  /// Checks of the given capability is supported
  bool supports(String capabilityName) =>
      serverCapabilities?.firstWhereOrNull((c) => c.name == capabilityName) !=
      null;

  @override
  bool operator ==(Object other) =>
      other is MailServerConfig &&
      other.pathSeparator == pathSeparator &&
      other.serverCapabilities?.length == serverCapabilities?.length &&
      other.authentication == authentication &&
      other.serverConfig == serverConfig;

  @override
  int get hashCode =>
      (serverConfig?.hashCode ?? 0) | (authentication?.hashCode ?? 0);

  @override
  String toString() => Serializer().serialize(this);
}
