import 'package:json_annotation/json_annotation.dart';

part 'client_config.g.dart';

/// Provides discovery information
class ClientConfig {
  /// Creates  a new client config
  ClientConfig({this.version, this.emailProviders});

  /// The version of this document
  String? version;

  /// The list of email providers
  List<ConfigEmailProvider>? emailProviders;

  /// Checks if the client configuration is not valid
  bool get isNotValid {
    final emailProviders = this.emailProviders;

    return emailProviders == null ||
        emailProviders.isEmpty ||
        emailProviders.first.preferredIncomingServer == null ||
        emailProviders.first.preferredOutgoingServer == null;
  }

  /// Checks if the client configuration is valid
  bool get isValid => !isNotValid;

  /// Adds the specified email [provider]
  void addEmailProvider(ConfigEmailProvider provider) {
    emailProviders ??= <ConfigEmailProvider>[];
    emailProviders?.add(provider);
  }

  /// Gets the preferred incoming mail server
  ServerConfig? get preferredIncomingServer => emailProviders?.isEmpty ?? true
      ? null
      : emailProviders?.first.preferredIncomingServer;

  /// The preferred incoming IMAP-compatible mail server
  ServerConfig? get preferredIncomingImapServer =>
      emailProviders?.isEmpty ?? true
          ? null
          : emailProviders?.first.preferredIncomingImapServer;
  set preferredIncomingImapServer(ServerConfig? server) {
    emailProviders?.first.preferredIncomingImapServer = server;
  }

  /// The preferred incoming POP-compatible mail server
  ServerConfig? get preferredIncomingPopServer =>
      emailProviders?.isEmpty ?? true
          ? null
          : emailProviders?.first.preferredIncomingPopServer;
  set preferredIncomingPopServer(ServerConfig? server) {
    emailProviders?.first.preferredIncomingPopServer = server;
  }

  /// The preferred outgoing mail server
  ServerConfig? get preferredOutgoingServer => emailProviders?.isEmpty ?? true
      ? null
      : emailProviders?.first.preferredOutgoingServer;
  set preferredOutgoingServer(ServerConfig? server) {
    emailProviders?.first.preferredOutgoingServer = server;
  }

  /// The preferred outgoing SMTP-compatible mail server
  ServerConfig? get preferredOutgoingSmtpServer =>
      emailProviders?.isEmpty ?? true
          ? null
          : emailProviders?.first.preferredOutgoingSmtpServer;
  set preferredOutgoingSmtpServer(ServerConfig? server) {
    emailProviders?.first.preferredOutgoingSmtpServer = server;
  }

  /// Retrieves the first display name
  String? get displayName => emailProviders?.isEmpty ?? true
      ? null
      : emailProviders?.first.displayName;
}

/// Contains configuration settings for a single email service
class ConfigEmailProvider {
  /// Creates a new mail provider
  ConfigEmailProvider({
    this.id,
    this.domains,
    this.displayName,
    this.displayShortName,
    this.incomingServers,
    this.outgoingServers,
  }) {
    preferredIncomingServer =
        (incomingServers?.isEmpty ?? true) ? null : incomingServers?.first;
    preferredOutgoingServer =
        (outgoingServers?.isEmpty ?? true) ? null : outgoingServers?.first;
  }

  /// ID of the provider
  String? id;

  /// Domains associated with the provider
  List<String?>? domains;

  /// The name used for display purposes
  String? displayName;

  /// The short name
  String? displayShortName;

  /// All incoming servers
  List<ServerConfig>? incomingServers;

  /// All outgoing servers
  List<ServerConfig>? outgoingServers;

  /// The URL for further documentation
  String? documentationUrl;

  /// The preferred incoming server
  ServerConfig? preferredIncomingServer;

  /// The preferred incoming IMAP server
  ServerConfig? preferredIncomingImapServer;

  /// The preferred incoming POP server
  ServerConfig? preferredIncomingPopServer;

  /// The preferred outgoing server
  ServerConfig? preferredOutgoingServer;

  /// The preferred outgoing SMTP server
  ServerConfig? preferredOutgoingSmtpServer;

  /// Adds the domain with the [name] to the list of associated domains
  void addDomain(String name) {
    domains ??= <String>[];
    domains?.add(name);
  }

  /// Adds the incoming [server].
  void addIncomingServer(ServerConfig server) {
    incomingServers ??= <ServerConfig>[];
    incomingServers?.add(server);
    preferredIncomingServer ??= server;
    if (server.type == ServerType.imap && preferredIncomingImapServer == null) {
      preferredIncomingImapServer = server;
    }
    if (server.type == ServerType.pop && preferredIncomingPopServer == null) {
      preferredIncomingPopServer = server;
    }
  }

  /// Adds the outgoing [server].
  void addOutgoingServer(ServerConfig server) {
    outgoingServers ??= <ServerConfig>[];
    outgoingServers?.add(server);
    preferredOutgoingServer ??= server;
    if (server.type == ServerType.smtp && preferredOutgoingSmtpServer == null) {
      preferredOutgoingSmtpServer = server;
    }
  }
}

/// The type of the server
enum ServerType {
  /// IMAP compatible incoming server
  imap,

  /// POP3 compatible incoming server
  pop,

  /// SMTP compatible outgoing server
  smtp,

  /// Unknown server type
  unknown,
}

/// The socket type
enum SocketType {
  /// No encryption.
  ///
  /// Typically this is switched to SSL using start TLS before authentication.
  plain,

  /// Secured connection
  ssl,

  /// No encryption for the first connection, then switch to SSL using start TLS
  starttls,

  /// Unknown encryption status
  unknown,

  /// No encryption is used, even not for authentication.
  plainNoStartTls,
}

/// The type of authentication
enum Authentication {
  /// OAuth 2 authentication
  oauth2,

  /// same as plain
  passwordClearText,

  /// plain text authentication
  plain,

  /// The password is encrypted before transmission
  passwordEncrypted,

  /// The password is secured before transmission
  secure,

  /// Family of authentication protocols
  // cSpell: disable-next-line
  ntlm,

  /// Generic Security Services Application Program Interface
  // cSpell: disable-next-line
  gsapi,

  /// The IP address of the client is used (very insecure)
  clientIpAddress,

  /// A client certificate is used
  tlsClientCert,

  /// SMTP can be used after authenticating via POP3
  smtpAfterPop,

  /// No authentication is used
  none,

  /// The authentication is not known in advance
  unknown,
}

/// The user name configuration
enum UsernameType {
  /// Full email address is used
  emailAddress,

  /// The start of the email address until the `@` is used
  emailLocalPart,

  /// The real name of the user
  realName,

  /// Unknown user name configuration
  unknown,
}

/// The configuration for a single server
@JsonSerializable()
class ServerConfig {
  /// Creates a new server configuration
  const ServerConfig({
    required this.type,
    required this.hostname,
    required this.port,
    required this.socketType,
    required this.authentication,
    required this.usernameType,
    this.authenticationAlternative,
  });

  /// Creates a new server configuration with the default values
  const ServerConfig.empty()
      : type = ServerType.unknown,
        hostname = '',
        port = 0,
        socketType = SocketType.unknown,
        authentication = Authentication.unknown,
        usernameType = UsernameType.unknown,
        authenticationAlternative = null;

  /// Creates a new [ServerConfig] from the given [json]
  factory ServerConfig.fromJson(Map<String, dynamic> json) =>
      _$ServerConfigFromJson(json);

  /// Generates json from this [ServerConfig]
  Map<String, dynamic> toJson() => _$ServerConfigToJson(this);

  /// The name of the server type
  @JsonKey(includeFromJson: false, includeToJson: false)
  String get typeName => type.toString().substring('serverType.'.length);

  /// The server type
  final ServerType type;

  /// The host
  final String hostname;

  /// The port
  final int port;

  /// The connection security
  final SocketType socketType;

  /// The name of the connection security
  @JsonKey(includeFromJson: false, includeToJson: false)
  String get socketTypeName =>
      socketType.toString().substring('socketType.'.length);

  /// The used main authentication mechanism
  final Authentication authentication;

  /// The used secondary authentication mechanism
  final Authentication? authenticationAlternative;

  /// The name of the main authentication
  @JsonKey(includeFromJson: false, includeToJson: false)
  String get authenticationName =>
      authentication.toString().substring('authentication.'.length);

  /// The name of the secondary authentication
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? get authenticationAlternativeName =>
      authenticationAlternative?.toString().substring('authentication.'.length);

  /// The name of the username configuration
  @JsonKey(includeFromJson: false, includeToJson: false)
  String get username => _usernameTypeToText(usernameType);

  /// The username configuration
  final UsernameType usernameType;

  /// Retrieves true when this server uses a secure connection
  bool get isSecureSocket => socketType == SocketType.ssl;

  @override
  String toString() => '$typeName:\n host: $hostname\n port: $port\n socket: '
      '$socketTypeName\n authentication: $authenticationName\n'
      'username: $username';

  /// Retrieves the user name based on the specified [email] address.
  /// Returns `null` in case usernameType is
  /// [UsernameType.realName] or [UsernameType.unknown].
  String? getUserName(String email) {
    switch (usernameType) {
      case UsernameType.emailAddress:
        return email;
      case UsernameType.emailLocalPart:
        final lastAtIndex = email.lastIndexOf('@');
        if (lastAtIndex == -1) {
          return email;
        }
        return email.substring(lastAtIndex + 1);
      case UsernameType.realName:
      case UsernameType.unknown:
      default:
        return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ServerConfig &&
      other.type == type &&
      other.hostname == hostname &&
      other.port == port &&
      other.usernameType == usernameType &&
      other.socketType == socketType &&
      other.authentication == authentication &&
      other.authenticationAlternative == authenticationAlternative;

  @override
  int get hashCode =>
      type.hashCode |
      hostname.hashCode |
      port |
      usernameType.hashCode |
      socketType.hashCode |
      authentication.hashCode |
      (authenticationAlternative?.hashCode ?? 0);

  /// Creates a copy of this [ServerConfig] with the specified values
  ServerConfig copyWith({
    ServerType? type,
    String? hostname,
    int? port,
    SocketType? socketType,
    Authentication? authentication,
    Authentication? authenticationAlternative,
    UsernameType? usernameType,
  }) =>
      ServerConfig(
        type: type ?? this.type,
        hostname: hostname ?? this.hostname,
        port: port ?? this.port,
        socketType: socketType ?? this.socketType,
        authentication: authentication ?? this.authentication,
        authenticationAlternative:
            authenticationAlternative ?? this.authenticationAlternative,
        usernameType: usernameType ?? this.usernameType,
      );

  static String _usernameTypeToText(UsernameType? type) {
    String text;
    switch (type) {
      case UsernameType.emailAddress:
        text = '%EMAILADDRESS%';
        break;
      case UsernameType.emailLocalPart:
        text = '%EMAILLOCALPART%';
        break;
      case UsernameType.realName:
        text = '%REALNAME%';
        break;
      default:
        text = 'UNKNOWN';
    }

    return text;
  }
}
