import 'package:enough_mail/discover/client_config.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/io/json_serializable.dart';

import 'mail_authentication.dart';

/// Contains information about a single mail account
class MailAccount extends JsonSerializable {
  /// The name of the account
  String name;

  /// The associated name of the user such as `user@domain.com`
  String userName;

  /// The email address of the user
  String email;

  /// Incoming mail settings
  MailServerConfig incoming;

  /// Outgoing mail settings
  MailServerConfig outgoing;

  /// The domain that is reported to the outgoing SMTP service
  String outgoingClientDomain = 'enough.de';

  /// Any additional attrobutes
  Map<String, String> attributes = <String, String>{};

  /// Convenience getter for the from MailAddress
  MailAddress get fromAddress => MailAddress(userName, email);

  /// Optional list of associated aliases
  List<MailAddress> aliases;

  /// Optional indicator if the mail service supports + based aliases, e.g. `user+alias@domain.com`.
  bool supportsPlusAliases = false;

  /// Checks if this account has an attribute with the specified name
  bool hasAttribute(String name) => attributes.containsKey(name);

  /// Creates a mail account with a plain authentication for the preferred incoming and preferred outgoing server.
  static MailAccount fromDiscoveredSetings(
      String name, String email, String password, ClientConfig config,
      {String userName, String outgoingClientDomain}) {
    userName ??= config.preferredIncomingServer.getUserName(email);
    userName ??= email;
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
    userName = readText('userName', json);
    email = readText('email', json);
    outgoingClientDomain = readText('outgoingClientDomain', json);
    incoming = readObject('incoming', json, MailServerConfig());
    outgoing = readObject('outgoing', json, MailServerConfig());
    aliases =
        readList('aliases', json, () => MailAddress.empty(), <MailAddress>[])
            as List<MailAddress>;
    supportsPlusAliases = readBool('supportsPlusAliases', json);
    // other attributes:
    final usedKeys = [
      'name',
      'userName',
      'email',
      'outgoingClientDomain',
      'incoming',
      'outgoing',
      'aliases',
      'supportsPlusAliases'
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
    writeText('userName', userName, buffer);
    writeText('email', email, buffer);
    writeText('outgoingClientDomain', outgoingClientDomain, buffer);
    writeObject('incoming', incoming, buffer);
    writeObject('outgoing', outgoing, buffer);
    writeList('aliases', aliases, buffer);
    writeBool('supportsPlusAliases', supportsPlusAliases, buffer);
    for (final key in attributes.keys) {
      writeText(key, attributes[key], buffer);
    }
  }

  @override
  bool operator ==(o) =>
      o is MailAccount &&
      o.name == name &&
      o.userName == userName &&
      o.email == email &&
      o.outgoingClientDomain == outgoingClientDomain &&
      o.incoming == incoming &&
      o.outgoing == outgoing &&
      o.supportsPlusAliases == supportsPlusAliases &&
      o.aliases?.length == aliases?.length &&
      o.attributes?.length == attributes?.length;

  @override
  String toString() {
    return toJson();
  }
}

/// Configuration of an mail service
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
    return (serverCapabilities?.firstWhere((c) => c.name == capabilityName,
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
