// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firm.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FirmImpl _$$FirmImplFromJson(Map<String, dynamic> json) => _$FirmImpl(
  firmId: json['firmId'] as String,
  name: json['name'] as String,
  primaryColor: json['primaryColor'] as String,
  adminId: json['adminId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  secondaryColor: json['secondaryColor'] as String?,
);

Map<String, dynamic> _$$FirmImplToJson(_$FirmImpl instance) =>
    <String, dynamic>{
      'firmId': instance.firmId,
      'name': instance.name,
      'primaryColor': instance.primaryColor,
      'adminId': instance.adminId,
      'createdAt': instance.createdAt.toIso8601String(),
      'secondaryColor': instance.secondaryColor,
    };
