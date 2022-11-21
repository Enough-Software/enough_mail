// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mail_account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MailAccount _$MailAccountFromJson(Map<String, dynamic> json) => MailAccount(
      name: json['name'] as String,
      email: json['email'] as String,
      incoming:
          MailServerConfig.fromJson(json['incoming'] as Map<String, dynamic>),
      outgoing:
          MailServerConfig.fromJson(json['outgoing'] as Map<String, dynamic>),
      userName: json['userName'] as String? ?? '',
      outgoingClientDomain:
          json['outgoingClientDomain'] as String? ?? 'enough.de',
      supportsPlusAliases: json['supportsPlusAliases'] as bool? ?? false,
      aliases: (json['aliases'] as List<dynamic>?)
          ?.map((e) => MailAddress.fromJson(e as Map<String, dynamic>))
          .toList(),
      attributes: json['attributes'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$MailAccountToJson(MailAccount instance) =>
    <String, dynamic>{
      'name': instance.name,
      'userName': instance.userName,
      'email': instance.email,
      'incoming': instance.incoming,
      'outgoing': instance.outgoing,
      'outgoingClientDomain': instance.outgoingClientDomain,
      'aliases': instance.aliases,
      'supportsPlusAliases': instance.supportsPlusAliases,
      'attributes': instance.attributes,
    };

MailServerConfig _$MailServerConfigFromJson(Map<String, dynamic> json) =>
    MailServerConfig(
      serverConfig:
          ServerConfig.fromJson(json['serverConfig'] as Map<String, dynamic>),
      authentication: MailAuthentication.fromJson(
          json['authentication'] as Map<String, dynamic>),
      serverCapabilities: (json['serverCapabilities'] as List<dynamic>?)
              ?.map((e) => Capability.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      pathSeparator: json['pathSeparator'] as String? ?? '/',
    );

Map<String, dynamic> _$MailServerConfigToJson(MailServerConfig instance) =>
    <String, dynamic>{
      'serverConfig': instance.serverConfig,
      'authentication': instance.authentication,
      'serverCapabilities': instance.serverCapabilities,
      'pathSeparator': instance.pathSeparator,
    };
