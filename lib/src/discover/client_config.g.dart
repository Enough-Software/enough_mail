// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServerConfig _$ServerConfigFromJson(Map<String, dynamic> json) => ServerConfig(
      type: $enumDecodeNullable(_$ServerTypeEnumMap, json['type']),
      hostname: json['hostname'] as String?,
      port: json['port'] as int?,
      socketType: $enumDecodeNullable(_$SocketTypeEnumMap, json['socketType']),
      authentication:
          $enumDecodeNullable(_$AuthenticationEnumMap, json['authentication']),
      usernameType:
          $enumDecodeNullable(_$UsernameTypeEnumMap, json['usernameType']),
    )
      ..typeName = json['typeName'] as String
      ..socketTypeName = json['socketTypeName'] as String
      ..authenticationAlternative = $enumDecodeNullable(
          _$AuthenticationEnumMap, json['authenticationAlternative'])
      ..authenticationName = json['authenticationName'] as String?
      ..authenticationAlternativeName =
          json['authenticationAlternativeName'] as String?
      ..username = json['username'] as String;

Map<String, dynamic> _$ServerConfigToJson(ServerConfig instance) =>
    <String, dynamic>{
      'typeName': instance.typeName,
      'type': _$ServerTypeEnumMap[instance.type],
      'hostname': instance.hostname,
      'port': instance.port,
      'socketType': _$SocketTypeEnumMap[instance.socketType],
      'socketTypeName': instance.socketTypeName,
      'authentication': _$AuthenticationEnumMap[instance.authentication],
      'authenticationAlternative':
          _$AuthenticationEnumMap[instance.authenticationAlternative],
      'authenticationName': instance.authenticationName,
      'authenticationAlternativeName': instance.authenticationAlternativeName,
      'username': instance.username,
      'usernameType': _$UsernameTypeEnumMap[instance.usernameType],
    };

const _$ServerTypeEnumMap = {
  ServerType.imap: 'imap',
  ServerType.pop: 'pop',
  ServerType.smtp: 'smtp',
  ServerType.unknown: 'unknown',
};

const _$SocketTypeEnumMap = {
  SocketType.plain: 'plain',
  SocketType.ssl: 'ssl',
  SocketType.starttls: 'starttls',
  SocketType.unknown: 'unknown',
  SocketType.plainNoStartTls: 'plainNoStartTls',
};

const _$AuthenticationEnumMap = {
  Authentication.oauth2: 'oauth2',
  Authentication.passwordClearText: 'passwordClearText',
  Authentication.plain: 'plain',
  Authentication.passwordEncrypted: 'passwordEncrypted',
  Authentication.secure: 'secure',
  Authentication.ntlm: 'ntlm',
  Authentication.gsapi: 'gsapi',
  Authentication.clientIpAddress: 'clientIpAddress',
  Authentication.tlsClientCert: 'tlsClientCert',
  Authentication.smtpAfterPop: 'smtpAfterPop',
  Authentication.none: 'none',
  Authentication.unknown: 'unknown',
};

const _$UsernameTypeEnumMap = {
  UsernameType.emailAddress: 'emailAddress',
  UsernameType.emailLocalPart: 'emailLocalPart',
  UsernameType.realName: 'realName',
  UsernameType.unknown: 'unknown',
};
