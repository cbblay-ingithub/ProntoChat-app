// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'membership.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Membership _$MembershipFromJson(Map<String, dynamic> json) {
  return _Membership.fromJson(json);
}

/// @nodoc
mixin _$Membership {
  /// Firestore document ID (UUID)
  String get membershipId => throw _privateConstructorUsedError;

  /// Firebase Auth UID of the user
  String get uid => throw _privateConstructorUsedError;

  /// Firestore firm ID that this user belongs to
  String get firmId => throw _privateConstructorUsedError;

  /// Membership status (pending, approved, revoked)
  MembershipStatus get status => throw _privateConstructorUsedError;

  /// User's role within this firm (admin, employee)
  MembershipRole get role => throw _privateConstructorUsedError;

  /// Timestamp when the membership was created
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Optional: when the membership was approved (for tracking approval time)
  DateTime? get approvedAt => throw _privateConstructorUsedError;

  /// Optional: when the membership was revoked
  DateTime? get revokedAt => throw _privateConstructorUsedError;

  /// Serializes this Membership to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Membership
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MembershipCopyWith<Membership> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MembershipCopyWith<$Res> {
  factory $MembershipCopyWith(
    Membership value,
    $Res Function(Membership) then,
  ) = _$MembershipCopyWithImpl<$Res, Membership>;
  @useResult
  $Res call({
    String membershipId,
    String uid,
    String firmId,
    MembershipStatus status,
    MembershipRole role,
    DateTime createdAt,
    DateTime? approvedAt,
    DateTime? revokedAt,
  });
}

/// @nodoc
class _$MembershipCopyWithImpl<$Res, $Val extends Membership>
    implements $MembershipCopyWith<$Res> {
  _$MembershipCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Membership
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? membershipId = null,
    Object? uid = null,
    Object? firmId = null,
    Object? status = null,
    Object? role = null,
    Object? createdAt = null,
    Object? approvedAt = freezed,
    Object? revokedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            membershipId: null == membershipId
                ? _value.membershipId
                : membershipId // ignore: cast_nullable_to_non_nullable
                      as String,
            uid: null == uid
                ? _value.uid
                : uid // ignore: cast_nullable_to_non_nullable
                      as String,
            firmId: null == firmId
                ? _value.firmId
                : firmId // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as MembershipStatus,
            role: null == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                      as MembershipRole,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            approvedAt: freezed == approvedAt
                ? _value.approvedAt
                : approvedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            revokedAt: freezed == revokedAt
                ? _value.revokedAt
                : revokedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MembershipImplCopyWith<$Res>
    implements $MembershipCopyWith<$Res> {
  factory _$$MembershipImplCopyWith(
    _$MembershipImpl value,
    $Res Function(_$MembershipImpl) then,
  ) = __$$MembershipImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String membershipId,
    String uid,
    String firmId,
    MembershipStatus status,
    MembershipRole role,
    DateTime createdAt,
    DateTime? approvedAt,
    DateTime? revokedAt,
  });
}

/// @nodoc
class __$$MembershipImplCopyWithImpl<$Res>
    extends _$MembershipCopyWithImpl<$Res, _$MembershipImpl>
    implements _$$MembershipImplCopyWith<$Res> {
  __$$MembershipImplCopyWithImpl(
    _$MembershipImpl _value,
    $Res Function(_$MembershipImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Membership
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? membershipId = null,
    Object? uid = null,
    Object? firmId = null,
    Object? status = null,
    Object? role = null,
    Object? createdAt = null,
    Object? approvedAt = freezed,
    Object? revokedAt = freezed,
  }) {
    return _then(
      _$MembershipImpl(
        membershipId: null == membershipId
            ? _value.membershipId
            : membershipId // ignore: cast_nullable_to_non_nullable
                  as String,
        uid: null == uid
            ? _value.uid
            : uid // ignore: cast_nullable_to_non_nullable
                  as String,
        firmId: null == firmId
            ? _value.firmId
            : firmId // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as MembershipStatus,
        role: null == role
            ? _value.role
            : role // ignore: cast_nullable_to_non_nullable
                  as MembershipRole,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        approvedAt: freezed == approvedAt
            ? _value.approvedAt
            : approvedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        revokedAt: freezed == revokedAt
            ? _value.revokedAt
            : revokedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MembershipImpl implements _Membership {
  const _$MembershipImpl({
    required this.membershipId,
    required this.uid,
    required this.firmId,
    this.status = MembershipStatus.approved,
    this.role = MembershipRole.employee,
    required this.createdAt,
    this.approvedAt,
    this.revokedAt,
  });

  factory _$MembershipImpl.fromJson(Map<String, dynamic> json) =>
      _$$MembershipImplFromJson(json);

  /// Firestore document ID (UUID)
  @override
  final String membershipId;

  /// Firebase Auth UID of the user
  @override
  final String uid;

  /// Firestore firm ID that this user belongs to
  @override
  final String firmId;

  /// Membership status (pending, approved, revoked)
  @override
  @JsonKey()
  final MembershipStatus status;

  /// User's role within this firm (admin, employee)
  @override
  @JsonKey()
  final MembershipRole role;

  /// Timestamp when the membership was created
  @override
  final DateTime createdAt;

  /// Optional: when the membership was approved (for tracking approval time)
  @override
  final DateTime? approvedAt;

  /// Optional: when the membership was revoked
  @override
  final DateTime? revokedAt;

  @override
  String toString() {
    return 'Membership(membershipId: $membershipId, uid: $uid, firmId: $firmId, status: $status, role: $role, createdAt: $createdAt, approvedAt: $approvedAt, revokedAt: $revokedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MembershipImpl &&
            (identical(other.membershipId, membershipId) ||
                other.membershipId == membershipId) &&
            (identical(other.uid, uid) || other.uid == uid) &&
            (identical(other.firmId, firmId) || other.firmId == firmId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.approvedAt, approvedAt) ||
                other.approvedAt == approvedAt) &&
            (identical(other.revokedAt, revokedAt) ||
                other.revokedAt == revokedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    membershipId,
    uid,
    firmId,
    status,
    role,
    createdAt,
    approvedAt,
    revokedAt,
  );

  /// Create a copy of Membership
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MembershipImplCopyWith<_$MembershipImpl> get copyWith =>
      __$$MembershipImplCopyWithImpl<_$MembershipImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MembershipImplToJson(this);
  }
}

abstract class _Membership implements Membership {
  const factory _Membership({
    required final String membershipId,
    required final String uid,
    required final String firmId,
    final MembershipStatus status,
    final MembershipRole role,
    required final DateTime createdAt,
    final DateTime? approvedAt,
    final DateTime? revokedAt,
  }) = _$MembershipImpl;

  factory _Membership.fromJson(Map<String, dynamic> json) =
      _$MembershipImpl.fromJson;

  /// Firestore document ID (UUID)
  @override
  String get membershipId;

  /// Firebase Auth UID of the user
  @override
  String get uid;

  /// Firestore firm ID that this user belongs to
  @override
  String get firmId;

  /// Membership status (pending, approved, revoked)
  @override
  MembershipStatus get status;

  /// User's role within this firm (admin, employee)
  @override
  MembershipRole get role;

  /// Timestamp when the membership was created
  @override
  DateTime get createdAt;

  /// Optional: when the membership was approved (for tracking approval time)
  @override
  DateTime? get approvedAt;

  /// Optional: when the membership was revoked
  @override
  DateTime? get revokedAt;

  /// Create a copy of Membership
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MembershipImplCopyWith<_$MembershipImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
