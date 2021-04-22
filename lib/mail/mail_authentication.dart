import 'package:enough_mail/discover/client_config.dart';
import 'package:enough_mail/imap/imap_client.dart';
import 'package:enough_mail/pop/pop_client.dart';
import 'package:enough_mail/smtp/smtp_client.dart';
import 'package:enough_serialization/enough_serialization.dart';

abstract class MailAuthentication extends SerializableObject {
  static const String _typePlain = 'plain';
  static const String _typeOauth = 'oauth';
  String? get typeName => attributes['typeName'];
  set typeName(String? value) => attributes['typeName'] = value;

  MailAuthentication(String typeName) {
    this.typeName = typeName;
  }

  Future<void> authenticate(ServerConfig serverConfig,
      {ImapClient? imap, PopClient? pop, SmtpClient? smtp});

  static MailAuthentication createType(String typeName) {
    switch (typeName) {
      case _typePlain:
        return PlainAuthentication(null, null);
      case _typeOauth:
        return OauthAuthentication(null, null);
    }
    throw StateError('unsupported MailAuthentication type [$typeName]');
  }
}

abstract class UserNameBasedAuthentication extends MailAuthentication {
  String? get userName => attributes['userName'];
  set userName(String? value) => attributes['userName'] = value;

  UserNameBasedAuthentication(String? userName, String typeName)
      : super(typeName) {
    this.userName = userName;
  }
}

class PlainAuthentication extends UserNameBasedAuthentication {
  String? get password => attributes['password'];
  set password(String? value) => attributes['password'] = value;

  PlainAuthentication(String? userName, String? password)
      : super(userName, MailAuthentication._typePlain) {
    this.password = password;
  }

  @override
  Future<void> authenticate(ServerConfig serverConfig,
      {ImapClient? imap, PopClient? pop, SmtpClient? smtp}) async {
    final name = userName!;
    final pwd = password!;
    switch (serverConfig.type) {
      case ServerType.imap:
        await imap!.login(name, pwd);
        break;
      case ServerType.pop:
        await pop!.login(name, pwd);
        break;
      case ServerType.smtp:
        final authMechanism = smtp!.serverInfo.supportsAuth(AuthMechanism.plain)
            ? AuthMechanism.plain
            : smtp.serverInfo.supportsAuth(AuthMechanism.login)
                ? AuthMechanism.login
                : AuthMechanism.cramMd5;
        await smtp.authenticate(name, pwd, authMechanism);
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

class OauthAuthentication extends UserNameBasedAuthentication {
  String? get token => attributes['token'];
  set token(String? value) => attributes['token'] = value;

  OauthAuthentication(String? userName, String? token)
      : super(userName, MailAuthentication._typeOauth) {
    this.token = token;
  }

  @override
  Future<void> authenticate(ServerConfig serverConfig,
      {ImapClient? imap, PopClient? pop, SmtpClient? smtp}) async {
    final name = userName!;
    final tkn = token!;
    switch (serverConfig.type) {
      case ServerType.imap:
        await imap!.authenticateWithOAuth2(name, tkn);
        break;
      case ServerType.pop:
        await pop!.login(name, tkn);
        break;
      case ServerType.smtp:
        await smtp!.authenticate(name, tkn, AuthMechanism.xoauth2);
        break;
      default:
        throw StateError('Unknown server type ${serverConfig.typeName}');
    }
  }

  @override
  bool operator ==(o) =>
      o is OauthAuthentication && o.userName == userName && o.token == token;
}
