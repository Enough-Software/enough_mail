import 'package:enough_mail/discover/client_config.dart';
import 'package:enough_mail/imap/imap_client.dart';
import 'package:enough_mail/pop/pop_client.dart';
import 'package:enough_mail/smtp/smtp_client.dart';
import 'package:enough_mail/io/json_serializable.dart';

import 'mail_response.dart';

abstract class MailAuthentication extends JsonSerializable {
  static const String _typePlain = 'plain';
  final String typeName;

  MailAuthentication(this.typeName);

  Future<MailResponse> authenticate(ServerConfig serverConfig,
      {ImapClient imap, PopClient pop, SmtpClient smtp});

  static MailAuthentication createType(String typeName) {
    switch (typeName) {
      case _typePlain:
        return PlainAuthentication(null, null);
    }
    throw StateError('unsupported MailAuthentication type [$typeName]');
  }
}

class PlainAuthentication extends MailAuthentication {
  String userName;
  String password;
  PlainAuthentication(this.userName, this.password)
      : super(MailAuthentication._typePlain);

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
        var smtpResponse = await smtp.login(userName, password);
        return MailResponseHelper.createFromSmtp(smtpResponse);
        break;
      default:
        throw StateError('Unknown server type ${serverConfig.typeName}');
    }
  }

  @override
  void readJson(Map<String, dynamic> json) {
    userName = json['userName'] as String;
    password = json['password'] as String;
  }

  @override
  void writeJson(StringBuffer buffer) {
    writeText('userName', userName, buffer);
    writeText('password', password, buffer);
  }

  @override
  bool operator ==(o) =>
      o is PlainAuthentication &&
      o.userName == userName &&
      o.password == password;
}
