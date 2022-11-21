// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mail_address.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MailAddress _$MailAddressFromJson(Map<String, dynamic> json) => MailAddress(
      json['personalName'] as String?,
      json['email'] as String,
    );

Map<String, dynamic> _$MailAddressToJson(MailAddress instance) =>
    <String, dynamic>{
      'personalName': instance.personalName,
      'email': instance.email,
    };
