// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mail_authentication.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlainAuthentication _$PlainAuthenticationFromJson(Map<String, dynamic> json) =>
    PlainAuthentication(
      json['userName'] as String,
      json['password'] as String,
    );

Map<String, dynamic> _$PlainAuthenticationToJson(
        PlainAuthentication instance) =>
    <String, dynamic>{
      'userName': instance.userName,
      'password': instance.password,
    };

OauthToken _$OauthTokenFromJson(Map<String, dynamic> json) => OauthToken(
      accessToken: json['access_token'] as String,
      expiresIn: json['expires_in'] as int,
      refreshToken: json['refresh_token'] as String,
      scope: json['scope'] as String,
      tokenType: json['token_type'] as String,
      created: DateTime.parse(json['created'] as String),
      provider: json['provider'] as String?,
    );

Map<String, dynamic> _$OauthTokenToJson(OauthToken instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'expires_in': instance.expiresIn,
      'refresh_token': instance.refreshToken,
      'scope': instance.scope,
      'token_type': instance.tokenType,
      'created': instance.created.toIso8601String(),
      'provider': instance.provider,
    };

OauthAuthentication _$OauthAuthenticationFromJson(Map<String, dynamic> json) =>
    OauthAuthentication(
      json['userName'] as String,
      OauthToken.fromJson(json['token'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$OauthAuthenticationToJson(
        OauthAuthentication instance) =>
    <String, dynamic>{
      'userName': instance.userName,
      'token': instance.token.toJson(),
    };
