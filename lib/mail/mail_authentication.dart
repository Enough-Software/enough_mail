import 'package:enough_mail/discover/client_config.dart';
import 'package:enough_mail/imap/imap_client.dart';
import 'package:enough_mail/pop/pop_client.dart';
import 'package:enough_mail/smtp/smtp_client.dart';

import 'mail_response.dart';

abstract class MailAuthentication {
  Future<MailResponse> authenticate(ServerConfig serverConfig,
      {ImapClient imap, PopClient pop, SmtpClient smtp});
}

class PlainAuthentication extends MailAuthentication {
  String userName;
  String password;
  PlainAuthentication(this.userName, this.password);

  @override
  Future<MailResponse> authenticate(ServerConfig serverConfig,
      {ImapClient imap, PopClient pop, SmtpClient smtp}) async {
    switch (serverConfig.type) {
      case ServerType.imap:
        var imapResponse = await imap.login(userName, password);
        return MailResponseHelper.createFromImap(imapResponse);
        break;
      case ServerType.pop:
        var popResponse = await pop.login(userName, password);
        return MailResponseHelper.createFromPop(popResponse);
        break;
      case ServerType.smtp:
        break;
      default:
        throw StateError('Unknown server type ${serverConfig.typeName}');
    }
  }
}
