import 'package:enough_mail/discover/client_config.dart';
import 'package:enough_mail/enough_mail.dart';

import 'mail_authentication.dart';

class MailServerConfig {
  ServerConfig serverConfig;
  MailAuthentication authentication;
  List<Capability> serverCapabilities;

  String pathSeparator;

  bool supports(String capabilityName) {
    return (serverCapabilities.firstWhere((c) => c.name == capabilityName,
            orElse: () => null) !=
        null);
  }
}

class MailAccount {
  String name;
  String email;
  MailServerConfig incoming;
  MailServerConfig outgoing;
  String outgoingClientDomain = 'enough.de';

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
}
