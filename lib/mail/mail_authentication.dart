import 'package:enough_mail/discover/client_config.dart';
import 'package:enough_mail/imap/imap_client.dart';
import 'package:enough_mail/pop/pop_client.dart';
import 'package:enough_mail/smtp/smtp_client.dart';
import 'package:enough_serialization/enough_serialization.dart';

abstract class MailAuthentication extends SerializableObject {
  static const String _typePlain = 'plain';
  String get typeName => attributes['typeName'];
  set typeName(String value) => attributes['typeName'] = value;

  MailAuthentication(String typeName) {
    this.typeName = typeName;
  }

  Future<void> authenticate(ServerConfig serverConfig,
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
  String get userName => attributes['userName'];
  set userName(String value) => attributes['userName'] = value;

  String get password => attributes['password'];
  set password(String value) => attributes['password'] = value;

  PlainAuthentication(String userName, String password)
      : super(MailAuthentication._typePlain) {
    this.userName = userName;
    this.password = password;
  }

  @override
  Future<void> authenticate(ServerConfig serverConfig,
      {ImapClient imap, PopClient pop, SmtpClient smtp}) async {
    switch (serverConfig.type) {
      case ServerType.imap:
        await imap.login(userName, password);
        break;
      case ServerType.pop:
        await pop.login(userName, password);
        break;
      case ServerType.smtp:
        final authMechanism = smtp.serverInfo.supportsAuth(AuthMechanism.plain)
            ? AuthMechanism.plain
            : smtp.serverInfo.supportsAuth(AuthMechanism.login)
                ? AuthMechanism.login
                : AuthMechanism.cramMd5;
        await smtp.authenticate(userName, password, authMechanism);
        break;
      default:
        throw StateError('Unknown server type ${serverConfig.typeName}');
    }
  }

  @override
  bool operator ==(o) =>
      o is PlainAuthentication &&
      o.userName == userName &&
      o.password == password;
}
