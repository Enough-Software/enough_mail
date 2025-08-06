// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServerConfig _$ServerConfigFromJson(Map<String, dynamic> json) => ServerConfig(
      type: $enumDecode(_$ServerTypeEnumMap, json['type']),
      hostname: json['hostname'] as String,
      port: (json['port'] as num).toInt(),
      socketType: $enumDecode(_$SocketTypeEnumMap, json['socketType']),
      authentication:
          $enumDecode(_$AuthenticationEnumMap, json['authentication']),
      usernameType: $enumDecode(_$UsernameTypeEnumMap, json['usernameType']),
      authenticationAlternative: $enumDecodeNullable(
          _$AuthenticationEnumMap, json['authenticationAlternative']),
    );

Map<String, dynamic> _$ServerConfigToJson(ServerConfig instance) =>
    <String, dynamic>{
      'type': _$ServerTypeEnumMap[instance.type]!,
      'hostname': instance.hostname,
      'port': instance.port,
      'socketType': _$SocketTypeEnumMap[instance.socketType]!,
      'authentication': _$AuthenticationEnumMap[instance.authentication]!,
      'authenticationAlternative':
          _$AuthenticationEnumMap[instance.authenticationAlternative],
      'usernameType': _$UsernameTypeEnumMap[instance.usernameType]!,
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
