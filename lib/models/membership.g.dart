// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'membership.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MembershipImpl _$$MembershipImplFromJson(Map<String, dynamic> json) =>
    _$MembershipImpl(
      membershipId: json['membershipId'] as String,
      uid: json['uid'] as String,
      firmId: json['firmId'] as String,
      status:
          $enumDecodeNullable(_$MembershipStatusEnumMap, json['status']) ??
          MembershipStatus.approved,
      role:
          $enumDecodeNullable(_$MembershipRoleEnumMap, json['role']) ??
          MembershipRole.employee,
      createdAt: DateTime.parse(json['createdAt'] as String),
      approvedAt: json['approvedAt'] == null
          ? null
          : DateTime.parse(json['approvedAt'] as String),
      revokedAt: json['revokedAt'] == null
          ? null
          : DateTime.parse(json['revokedAt'] as String),
    );

Map<String, dynamic> _$$MembershipImplToJson(_$MembershipImpl instance) =>
    <String, dynamic>{
      'membershipId': instance.membershipId,
      'uid': instance.uid,
      'firmId': instance.firmId,
      'status': _$MembershipStatusEnumMap[instance.status]!,
      'role': _$MembershipRoleEnumMap[instance.role]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'approvedAt': instance.approvedAt?.toIso8601String(),
      'revokedAt': instance.revokedAt?.toIso8601String(),
    };

const _$MembershipStatusEnumMap = {
  MembershipStatus.pending: 'pending',
  MembershipStatus.approved: 'approved',
  MembershipStatus.revoked: 'revoked',
};

const _$MembershipRoleEnumMap = {
  MembershipRole.admin: 'admin',
  MembershipRole.employee: 'employee',
};
