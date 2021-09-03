import 'package:enough_serialization/enough_serialization.dart';

/// Provides discovery information
class ClientConfig {
  String? version;
  List<ConfigEmailProvider>? emailProviders;

  /// Checks if the client configuration is not valid
  bool get isNotValid =>
      emailProviders == null ||
      emailProviders!.isEmpty ||
      emailProviders!.first.preferredIncomingServer == null ||
      emailProviders!.first.preferredOutgoingServer == null;

  /// Checks if the client configuration is valid
  bool get isValid => !isNotValid;

  ClientConfig({this.version, this.emailProviders});

  void addEmailProvider(ConfigEmailProvider provider) {
    emailProviders ??= <ConfigEmailProvider>[];
    emailProviders!.add(provider);
  }

  ServerConfig? get preferredIncomingServer => emailProviders?.isEmpty ?? true
      ? null
      : emailProviders!.first.preferredIncomingServer;
  ServerConfig? get preferredIncomingImapServer =>
      emailProviders?.isEmpty ?? true
          ? null
          : emailProviders!.first.preferredIncomingImapServer;
  ServerConfig? get preferredIncomingPopServer =>
      emailProviders?.isEmpty ?? true
          ? null
          : emailProviders!.first.preferredIncomingPopServer;
  ServerConfig? get preferredOutgoingServer => emailProviders?.isEmpty ?? true
      ? null
      : emailProviders!.first.preferredOutgoingServer;
  ServerConfig? get preferredOutgoingSmtpServer =>
      emailProviders?.isEmpty ?? true
          ? null
          : emailProviders!.first.preferredOutgoingSmtpServer;
  String? get displayName => emailProviders?.isEmpty ?? true
      ? null
      : emailProviders!.first.displayName;
}

class ConfigEmailProvider {
  String? id;
  List<String?>? domains;
  String? displayName;
  String? displayShortName;
  List<ServerConfig>? incomingServers;
  List<ServerConfig>? outgoingServers;
  String? documentationUrl;
  ServerConfig? preferredIncomingServer;
  ServerConfig? preferredIncomingImapServer;
  ServerConfig? preferredIncomingPopServer;
  ServerConfig? preferredOutgoingServer;
  ServerConfig? preferredOutgoingSmtpServer;

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

  void addDomain(String name) {
    domains ??= <String>[];
    domains!.add(name);
  }

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

  void addOutgoingServer(ServerConfig server) {
    outgoingServers ??= <ServerConfig>[];
    outgoingServers!.add(server);
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

class ServerConfig extends OnDemandSerializable {
  String get typeName => type.toString().substring('serverType.'.length);
  set typeName(String value) {
    type = _serverTypeFromText(value);
  }

  ServerType? type;
  String? hostname;
  int? port;
  SocketType? socketType;
  String get socketTypeName =>
      socketType.toString().substring('socketType.'.length);
  set socketTypeName(String value) {
    socketType = _socketTypeFromText(value);
  }

  Authentication? authentication;
  Authentication? authenticationAlternative;

  String? get authenticationName =>
      authentication?.toString().substring('authentication.'.length);
  set authenticationName(String? value) {
    authentication = _authenticationFromText(value);
  }

  set authenticationAlternativeName(String? value) {
    authenticationAlternative = _authenticationFromText(value);
  }

  String? get authenticationAlternativeName =>
      authenticationAlternative?.toString().substring('authentication.'.length);

  late String _username;
  String get username => _username;
  set username(String value) {
    _username = value;
    usernameType = _usernameTypeFromText(value);
  }

  UsernameType? usernameType;

  bool get isSecureSocket => (socketType == SocketType.ssl);

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

// class ServerConfig2 extends SerializableObject {
//   String get typeName => type.toString().substring('serverType.'.length);
//   set typeName(String value) {
//     type = _serverTypeFromText(value);
//   }

//   ServerType get type => attributes['type'];
//   set type(ServerType value) => attributes['type'] = value;

//   String get hostname => attributes['hostname'];
//   set hostname(String value) => attributes['hostname'] = value;
//   int get port => attributes['port'];
//   set port(int value) => attributes['port'] = value;

//   SocketType get socketType => attributes['socketType'];
//   set socketType(SocketType value) => attributes['socketType'] = value;

//   String get socketTypeName =>
//       socketType.toString().substring('socketType.'.length);
//   set socketTypeName(String value) {
//     socketType = _socketTypeFromText(value);
//   }

//   Authentication get authentication => attributes['authentication'];
//   set authentication(Authentication value) =>
//       attributes['authentication'] = value;
//   Authentication get authenticationAlternative =>
//       attributes['authenticationAlternative'];
//   set authenticationAlternative(Authentication value) =>
//       attributes['authenticationAlternative'] = value;

//   String get authenticationName =>
//       authentication?.toString()?.substring('authentication.'.length);
//   set authenticationName(String value) {
//     authentication = _authenticationFromText(value);
//   }

//   set authenticationAlternativeName(String value) {
//     authenticationAlternative = _authenticationFromText(value);
//   }

//   String get authenticationAlternativeName => authenticationAlternative
//       ?.toString()
//       ?.substring('authentication.'.length);

//   String _username;
//   String get username => _username;
//   set username(String value) {
//     _username = value;
//     usernameType = _usernameTypeFromText(value);
//   }

//   UsernameType get usernameType => attributes['usernameType'];

//   set usernameType(UsernameType value) => attributes['usernameType'] = value;

//   bool get isSecureSocket => (socketType == SocketType.ssl);

//   ServerConfig(
//       {ServerType type,
//       String hostname,
//       int port,
//       SocketType socketType,
//       Authentication authentication,
//       UsernameType usernameType}) {
//     if (usernameType != null) {
//       _username = _usernameTypeToText(usernameType);
//     }
//     this.type = type;
//     this.hostname = hostname;
//     this.socketType = socketType;
//     this.authentication = authentication;
//     this.usernameType = usernameType;
//     transformers['type'] =
//         (value) => value is ServerType ? value.index : ServerType.values[value];
//     transformers['socketType'] =
//         (value) => value is SocketType ? value.index : SocketType.values[value];
//     transformers['authentication'] = (value) =>
//         value is Authentication ? value.index : Authentication.values[value];
//     transformers['usernameType'] = (value) =>
//         value is UsernameType ? value.index : UsernameType.values[value];
//   }

  @override
  String toString() {
    return '$typeName:\n host: $hostname\n port: $port\n socket: $socketTypeName\n authentication: $authenticationName\n username: $username';
  }

  /// Retrieves the user name based on the specified [email] address.
  /// Returns [null] in case usernameType is UsernameType.realname or UsernameType.unknown.
  String? getUserName(String email) {
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
  bool operator ==(o) =>
      o is ServerConfig &&
      o.type == type &&
      o.hostname == hostname &&
      o.port == port &&
      o.usernameType == usernameType &&
      o.socketType == socketType &&
      o.authentication == authentication &&
      o.authenticationAlternative == authenticationAlternative;

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
