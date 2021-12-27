import 'package:enough_serialization/enough_serialization.dart';

/// Provides discovery information
class ClientConfig {
  /// Creates  a new client config
  ClientConfig({this.version, this.emailProviders});

  /// The version of this document
  String? version;

  /// The list of email providers
  List<ConfigEmailProvider>? emailProviders;

  /// Checks if the client configuration is not valid
  bool get isNotValid =>
      emailProviders == null ||
      emailProviders!.isEmpty ||
      emailProviders!.first.preferredIncomingServer == null ||
      emailProviders!.first.preferredOutgoingServer == null;

  /// Checks if the client configuration is valid
  bool get isValid => !isNotValid;

  /// Adds the specified email [provider]
  void addEmailProvider(ConfigEmailProvider provider) {
    emailProviders ??= <ConfigEmailProvider>[];
    emailProviders!.add(provider);
  }

  /// Gets the preferred incoming mail server
  ServerConfig? get preferredIncomingServer => emailProviders?.isEmpty ?? true
      ? null
      : emailProviders!.first.preferredIncomingServer;

  /// Gets the preferred incoming IMAP-compatible mail server
  ServerConfig? get preferredIncomingImapServer =>
      emailProviders?.isEmpty ?? true
          ? null
          : emailProviders!.first.preferredIncomingImapServer;

  /// Gets the preferred incoming POP-compatible mail server
  ServerConfig? get preferredIncomingPopServer =>
      emailProviders?.isEmpty ?? true
          ? null
          : emailProviders!.first.preferredIncomingPopServer;

  /// Gets the preferred outgoing mail server
  ServerConfig? get preferredOutgoingServer => emailProviders?.isEmpty ?? true
      ? null
      : emailProviders!.first.preferredOutgoingServer;

  /// Gets the preferred outgoing SMTP-compatible mail server
  ServerConfig? get preferredOutgoingSmtpServer =>
      emailProviders?.isEmpty ?? true
          ? null
          : emailProviders!.first.preferredOutgoingSmtpServer;

  /// Retrieves the first display name
  String? get displayName => emailProviders?.isEmpty ?? true
      ? null
      : emailProviders?.first.displayName;
}

/// Contains configution settings for a single email service
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
    domains!.add(name);
  }

  /// Adds the incoming [server].
  void addIncomingServer(ServerConfig server) {
    incomingServers ??= <ServerConfig>[];
    incomingServers!.add(server);
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
    outgoingServers!.add(server);
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
  unknown
}

/// The socket type
enum SocketType {
  /// No encryption.
  ///
  /// Typically this is switched to SSL using start TLS before authenciation.
  plain,

  /// Secured connection
  ssl,

  /// No encryption for the first connection, then switch to SSL using start TLS
  starttls,

  /// Unknown encyption status
  unknown,

  /// No encryption is used, even not for authentication.
  plainNoStartTls
}

/// The type of authentication
enum Authentication {
  /// OAuth 2 authentication
  oauth2,

  /// same as plain
  passwordCleartext,

  /// plain text authentication
  plain,

  /// The password is encrypted before transmition
  passwordEncrypted,

  /// The password is secured before transtion
  secure,

  /// Family of authentication protocols
  ntlm,

  /// Generic Security Services Application Program Interface
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
  unknown
}

/// The user name configuration
enum UsernameType {
  /// Full email adress is used
  emailAddress,

  /// The start of the email address until the `@` is used
  emailLocalPart,

  /// The real name of the user
  realname,

  /// Unknown user name configuration
  unknown
}

/// The configuration for a single server
class ServerConfig extends OnDemandSerializable {
  /// Creates a new server configuration
  ServerConfig(
      {this.type,
      this.hostname,
      this.port,
      this.socketType,
      this.authentication,
      this.usernameType}) {
    if (usernameType != null) {
      _username = _usernameTypeToText(usernameType);
    }
  }

  /// The name of the server type
  String get typeName => type.toString().substring('serverType.'.length);
  set typeName(String value) {
    type = _serverTypeFromText(value);
  }

  /// The server type
  ServerType? type;

  /// The host
  String? hostname;

  /// The port
  int? port;

  /// The connection security
  SocketType? socketType;

  /// The name of the connection security
  String get socketTypeName =>
      socketType.toString().substring('socketType.'.length);
  set socketTypeName(String value) {
    socketType = _socketTypeFromText(value);
  }

  /// The used main authentication mechanism
  Authentication? authentication;

  /// The used seconcary authentication mechanism
  Authentication? authenticationAlternative;

  /// The name of the main authentication
  String? get authenticationName =>
      authentication?.toString().substring('authentication.'.length);
  set authenticationName(String? value) {
    authentication = _authenticationFromText(value);
  }

  /// The name of the secondary authentication
  String? get authenticationAlternativeName =>
      authenticationAlternative?.toString().substring('authentication.'.length);
  set authenticationAlternativeName(String? value) {
    authenticationAlternative = _authenticationFromText(value);
  }

  late String _username;

  /// The name of the username configuration
  String get username => _username;
  set username(String value) {
    _username = value;
    usernameType = _usernameTypeFromText(value);
  }

  /// The username configuration
  UsernameType? usernameType;

  /// Retrieves true when this server uses a secure conection
  bool get isSecureSocket => socketType == SocketType.ssl;

  @override
  String toString() => '$typeName:\n host: $hostname\n port: $port\n socket: '
      '$socketTypeName\n authentication: $authenticationName\n'
      'username: $username';

  /// Retrieves the user name based on the specified [email] address.
  /// Returns `null` in case usernameType is
  /// [UsernameType.realname] or [UsernameType.unknown].
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
      case UsernameType.realname:
      case UsernameType.unknown:
      default:
        return null;
    }
  }

  @override
  void read(Map<String, dynamic> attributes) {
    typeName = attributes['typeName'];
    hostname = attributes['hostname'];
    port = attributes['port'];
    username = attributes['username'];
    socketTypeName = attributes['socketType'];
    authenticationName = attributes['authentication'];
    authenticationAlternativeName = attributes['authenticationAlternative'];
  }

  @override
  void write(Map<String, dynamic> attributes) {
    attributes['typeName'] = typeName;
    attributes['hostname'] = hostname;
    attributes['port'] = port;
    attributes['username'] = username;
    attributes['socketType'] = socketTypeName;
    attributes['authentication'] = authenticationName;
    attributes['authenticationAlternative'] = authenticationAlternativeName;
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
      (type?.hashCode ?? 0) |
      (hostname?.hashCode ?? 0) |
      (port ?? 0) |
      (usernameType?.hashCode ?? 0) |
      (socketType?.hashCode ?? 0) |
      (authentication?.hashCode ?? 0) |
      (authenticationAlternative?.hashCode ?? 0);

  static ServerType _serverTypeFromText(String text) {
    ServerType type;
    switch (text.toLowerCase()) {
      case 'imap':
        type = ServerType.imap;
        break;
      case 'pop3':
        type = ServerType.pop;
        break;
      case 'smtp':
        type = ServerType.smtp;
        break;
      default:
        type = ServerType.unknown;
    }
    return type;
  }

  static SocketType _socketTypeFromText(String text) {
    SocketType type;
    switch (text.toUpperCase()) {
      case 'SSL':
        type = SocketType.ssl;
        break;
      case 'STARTTLS':
        type = SocketType.starttls;
        break;
      case 'PLAIN':
        type = SocketType.plain;
        break;
      default:
        type = SocketType.unknown;
    }
    return type;
  }

  static Authentication? _authenticationFromText(String? text) {
    if (text == null) {
      return null;
    }
    Authentication authentication;
    switch (text.toLowerCase()) {
      case 'oauth2':
        authentication = Authentication.oauth2;
        break;
      case 'password-cleartext':
        authentication = Authentication.passwordCleartext;
        break;
      case 'plain':
        authentication = Authentication.plain;
        break;
      case 'password-encrypted':
        authentication = Authentication.passwordEncrypted;
        break;
      case 'secure':
        authentication = Authentication.secure;
        break;
      case 'ntlm':
        authentication = Authentication.ntlm;
        break;
      case 'gsapi':
        authentication = Authentication.gsapi;
        break;
      case 'client-ip-address':
        authentication = Authentication.clientIpAddress;
        break;
      case 'tls-client-cert':
        authentication = Authentication.tlsClientCert;
        break;
      case 'smtp-after-pop':
        authentication = Authentication.smtpAfterPop;
        break;
      case 'none':
        authentication = Authentication.none;
        break;
      default:
        authentication = Authentication.unknown;
    }
    return authentication;
  }

  static UsernameType _usernameTypeFromText(String text) {
    UsernameType type;
    switch (text.toUpperCase()) {
      case '%EMAILADDRESS%':
        type = UsernameType.emailAddress;
        break;
      case '%EMAILLOCALPART%':
        type = UsernameType.emailLocalPart;
        break;
      case '%REALNAME%':
        type = UsernameType.realname;
        break;
      default:
        type = UsernameType.unknown;
    }
    return type;
  }

  static String _usernameTypeToText(UsernameType? type) {
    String text;
    switch (type) {
      case UsernameType.emailAddress:
        text = '%EMAILADDRESS%';
        break;
      case UsernameType.emailLocalPart:
        text = '%EMAILLOCALPART%';
        break;
      case UsernameType.realname:
        text = '%REALNAME%';
        break;
      default:
        text = 'UNKNOWN';
    }
    return text;
  }
}
