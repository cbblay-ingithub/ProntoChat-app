// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppUserImpl _$$AppUserImplFromJson(Map<String, dynamic> json) =>
    _$AppUserImpl(
      uid: json['uid'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role:
          $enumDecodeNullable(_$UserRoleEnumMap, json['role']) ??
          UserRole.employee,
      image: json['image'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastSeen: json['lastSeen'] == null
          ? null
          : DateTime.parse(json['lastSeen'] as String),
      nameLower: json['nameLower'] as String?,
    );

Map<String, dynamic> _$$AppUserImplToJson(_$AppUserImpl instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'name': instance.name,
      'email': instance.email,
      'role': _$UserRoleEnumMap[instance.role]!,
      'image': instance.image,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastSeen': instance.lastSeen?.toIso8601String(),
      'nameLower': instance.nameLower,
    };

const _$UserRoleEnumMap = {
  UserRole.super_admin: 'super_admin',
  UserRole.admin: 'admin',
  UserRole.employee: 'employee',
};
