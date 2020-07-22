import 'package:enough_mail/discover/client_config.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/io/json_serializable.dart';

import 'mail_authentication.dart';

class MailServerConfig extends JsonSerializable {
  ServerConfig serverConfig;
  MailAuthentication authentication;
  List<Capability> serverCapabilities = <Capability>[];
  String pathSeparator;

  MailServerConfig(
      {this.serverConfig,
      this.authentication,
      this.serverCapabilities,
      this.pathSeparator});

  bool supports(String capabilityName) {
    return (serverCapabilities.firstWhere((c) => c.name == capabilityName,
            orElse: () => null) !=
        null);
  }

  @override
  void readJson(Map<String, dynamic> json) {
    pathSeparator = readText('pathSeparator', json);
    serverConfig = readObject('serverConfig', json, ServerConfig());
    var authenticationType = readText('authenticationType', json);
    authentication = readObject('authentication', json,
        MailAuthentication.createType(authenticationType));
    var caps = readText('capabilities', json);
    serverCapabilities = caps == null
        ? null
        : caps.split(' ').map<Capability>((name) => Capability(name)).toList();
  }

  @override
  void writeJson(StringBuffer buffer) {
    writeText('pathSeparator', pathSeparator, buffer);
    writeObject('serverConfig', serverConfig, buffer);
    writeText('authenticationType', authentication?.typeName, buffer);
    writeObject('authentication', authentication, buffer);
    var caps = serverCapabilities == null
        ? null
        : serverCapabilities.map<String>((c) => c.name).join(' ');
    writeText('capabilities', caps, buffer);
  }

  @override
  bool operator ==(o) =>
      o is MailServerConfig &&
      o.pathSeparator == pathSeparator &&
      o.serverCapabilities?.length == serverCapabilities?.length &&
      o.authentication == authentication &&
      o.serverConfig == serverConfig;

  @override
  String toString() {
    return toJson();
  }
}

class MailAccount extends JsonSerializable {
  String name;
  String email;
  MailServerConfig incoming;
  MailServerConfig outgoing;
  String outgoingClientDomain = 'enough.de';
  Map<String, String> attributes = <String, String>{};

  /// Creates a mail account with a plain authentication for the preferred incoming and preferred outgoing server.
  static MailAccount fromDiscoveredSetings(
      String name, String email, String password, ClientConfig config,
      {String userName, String outgoingClientDomain}) {
    userName ??= config.preferredIncomingImapServer.getUserName(email);
    var auth = PlainAuthentication(userName, password);
    var incoming = MailServerConfig()
      ..authentication = auth
      ..serverConfig = config.preferredIncomingImapServer;
    var outgoing = MailServerConfig()
      ..authentication = auth
      ..serverConfig = config.preferredOutgoingServer;
    var account = MailAccount()
      ..name = name
      ..email = email
      ..incoming = incoming
      ..outgoing = outgoing;
    if (outgoingClientDomain != null) {
      account.outgoingClientDomain = outgoingClientDomain;
    }
    return account;
  }

  @override
  void readJson(Map<String, dynamic> json) {
    name = readText('name', json);
    email = readText('email', json);
    outgoingClientDomain = readText('outgoingClientDomain', json);
    incoming = readObject('incoming', json, MailServerConfig());
    outgoing = readObject('outgoing', json, MailServerConfig());
    // other attributes:
    final usedKeys = [
      'name',
      'email',
      'outgoingClientDomain',
      'incoming',
      'outgoing'
    ];
    for (final key in json.keys) {
      if (usedKeys.contains(key)) {
        continue;
      }
      attributes[key] = readText(key, json);
    }
  }

  @override
  void writeJson(StringBuffer buffer) {
    writeText('name', name, buffer);
    writeText('email', email, buffer);
    writeText('outgoingClientDomain', outgoingClientDomain, buffer);
    writeObject('incoming', incoming, buffer);
    writeObject('outgoing', outgoing, buffer);
    for (final key in attributes.keys) {
      writeText(key, attributes[key], buffer);
    }
  }

  @override
  bool operator ==(o) =>
      o is MailAccount &&
      o.name == name &&
      o.email == email &&
      o.outgoingClientDomain == outgoingClientDomain &&
      o.incoming == incoming &&
      o.outgoing == outgoing &&
      o.attributes?.length == attributes?.length;

  @override
  String toString() {
    return toJson();
  }
}
