class ClientConfig {
  String version;
  List<ConfigEmailProvider> emailProviders;

  bool get isNotValid =>
      emailProviders == null ||
      emailProviders.isEmpty ||
      emailProviders.first.preferredIncomingServer == null ||
      emailProviders.first.preferredOutgoingServer == null;
  bool get isValid => !isNotValid;

  ClientConfig({this.version});

  void addEmailProvider(ConfigEmailProvider provider) {
    emailProviders ??= <ConfigEmailProvider>[];
    emailProviders.add(provider);
  }

  ServerConfig get preferredIncomingServer => emailProviders?.isEmpty ?? true
      ? null
      : emailProviders.first.preferredIncomingServer;
  ServerConfig get preferredIncomingImapServer =>
      emailProviders?.isEmpty ?? true
          ? null
          : emailProviders.first.preferredIncomingImapServer;
  ServerConfig get preferredIncomingPopServer => emailProviders?.isEmpty ?? true
      ? null
      : emailProviders.first.preferredIncomingPopServer;
  ServerConfig get preferredOutgoingServer => emailProviders?.isEmpty ?? true
      ? null
      : emailProviders.first.preferredOutgoingServer;
  ServerConfig get preferredOutgoingSmtpServer =>
      emailProviders?.isEmpty ?? true
          ? null
          : emailProviders.first.preferredOutgoingSmtpServer;
  String get displayName =>
      emailProviders?.isEmpty ?? true ? null : emailProviders.first.displayName;
}

class ConfigEmailProvider {
  String id;
  List<String> domains;
  String displayName;
  String displayShortName;
  List<ServerConfig> incomingServers;
  List<ServerConfig> outgoingServers;
  String documentationUrl;
  ServerConfig preferredIncomingServer;
  ServerConfig preferredIncomingImapServer;
  ServerConfig preferredIncomingPopServer;
  ServerConfig preferredOutgoingServer;
  ServerConfig preferredOutgoingSmtpServer;

  ConfigEmailProvider(
      {this.id,
      this.domains,
      this.displayName,
      this.displayShortName,
      this.incomingServers,
      this.outgoingServers});

  void addDomain(String name) {
    domains ??= <String>[];
    domains.add(name);
  }

  void addIncomingServer(ServerConfig server) {
    incomingServers ??= <ServerConfig>[];
    incomingServers.add(server);
    preferredIncomingServer ??= server;
    if (server.type == ServerType.imap && preferredIncomingImapServer == null) {
      preferredIncomingImapServer = server;
    }
    if (server.type == ServerType.pop && preferredIncomingPopServer == null) {
      preferredIncomingPopServer = server;
    }
  }

  void addOutgoingServer(ServerConfig server) {
    outgoingServers ??= <ServerConfig>[];
    outgoingServers.add(server);
    preferredOutgoingServer ??= server;
    if (server.type == ServerType.smtp && preferredOutgoingSmtpServer == null) {
      preferredOutgoingSmtpServer = server;
    }
  }
}

enum ServerType { imap, pop, smtp, unknown }

enum SocketType { plain, ssl, starttls, unknown }

enum Authentication {
  oauth2,
  passwordCleartext,
  plain,
  passwordEncrypted,
  secure,
  ntlm,
  gsapi,
  clientIpAddress,
  tlsClientCert,
  smtpAfterPop,
  none,
  unknown
}

enum UsernameType { emailAddress, emailLocalPart, realname, unknown }

class ServerConfig {
  String typeName;
  ServerType type;
  String hostname;
  int port;
  SocketType socketType;
  String get socketTypeName =>
      socketType.toString().substring('socketType.'.length);
  Authentication authentication;
  Authentication authenticationAlternative;
  String get authenticationName =>
      authentication.toString().substring('authentication.'.length);
  String username;
  UsernameType usernameType;

  bool get isSecureSocket => (socketType == SocketType.ssl);

  ServerConfig(
      {this.type,
      this.hostname,
      this.port,
      this.socketType,
      this.authentication,
      this.username});

  @override
  String toString() {
    return '$typeName:\n host: $hostname\n port: $port\n socket: $socketTypeName\n authentication: $authenticationName\n username: $username';
  }

  /// Retrieves the user name based on the specified [email] address.
  /// Returns [null] in case usernameType is UsernameType.realname or UsernameType.unknown.
  String getUserName(String email) {
    switch (usernameType) {
      case UsernameType.emailAddress:
        return email;
      case UsernameType.emailLocalPart:
        var lastAtIndex = email.lastIndexOf('@');
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
}
