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
}
