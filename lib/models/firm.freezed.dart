// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'firm.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Firm _$FirmFromJson(Map<String, dynamic> json) {
  return _Firm.fromJson(json);
}

/// @nodoc
mixin _$Firm {
  /// Firestore document ID (UUID or custom ID)
  String get firmId => throw _privateConstructorUsedError;

  /// Display name of the firm (e.g., "Acme Corporation")
  String get name => throw _privateConstructorUsedError;

  /// Primary brand color as hex string (e.g., "#295CB4")
  String get primaryColor => throw _privateConstructorUsedError;

  /// UID of the super_admin who created this firm
  String get adminId => throw _privateConstructorUsedError;

  /// Timestamp when the firm was created
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Optional secondary brand color for UI accents
  String? get secondaryColor => throw _privateConstructorUsedError;

  /// Serializes this Firm to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Firm
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FirmCopyWith<Firm> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FirmCopyWith<$Res> {
  factory $FirmCopyWith(Firm value, $Res Function(Firm) then) =
      _$FirmCopyWithImpl<$Res, Firm>;
  @useResult
  $Res call({
    String firmId,
    String name,
    String primaryColor,
    String adminId,
    DateTime createdAt,
    String? secondaryColor,
  });
}

/// @nodoc
class _$FirmCopyWithImpl<$Res, $Val extends Firm>
    implements $FirmCopyWith<$Res> {
  _$FirmCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Firm
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? firmId = null,
    Object? name = null,
    Object? primaryColor = null,
    Object? adminId = null,
    Object? createdAt = null,
    Object? secondaryColor = freezed,
  }) {
    return _then(
      _value.copyWith(
            firmId: null == firmId
                ? _value.firmId
                : firmId // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            primaryColor: null == primaryColor
                ? _value.primaryColor
                : primaryColor // ignore: cast_nullable_to_non_nullable
                      as String,
            adminId: null == adminId
                ? _value.adminId
                : adminId // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            secondaryColor: freezed == secondaryColor
                ? _value.secondaryColor
                : secondaryColor // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FirmImplCopyWith<$Res> implements $FirmCopyWith<$Res> {
  factory _$$FirmImplCopyWith(
    _$FirmImpl value,
    $Res Function(_$FirmImpl) then,
  ) = __$$FirmImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String firmId,
    String name,
    String primaryColor,
    String adminId,
    DateTime createdAt,
    String? secondaryColor,
  });
}

/// @nodoc
class __$$FirmImplCopyWithImpl<$Res>
    extends _$FirmCopyWithImpl<$Res, _$FirmImpl>
    implements _$$FirmImplCopyWith<$Res> {
  __$$FirmImplCopyWithImpl(_$FirmImpl _value, $Res Function(_$FirmImpl) _then)
    : super(_value, _then);

  /// Create a copy of Firm
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? firmId = null,
    Object? name = null,
    Object? primaryColor = null,
    Object? adminId = null,
    Object? createdAt = null,
    Object? secondaryColor = freezed,
  }) {
    return _then(
      _$FirmImpl(
        firmId: null == firmId
            ? _value.firmId
            : firmId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        primaryColor: null == primaryColor
            ? _value.primaryColor
            : primaryColor // ignore: cast_nullable_to_non_nullable
                  as String,
        adminId: null == adminId
            ? _value.adminId
            : adminId // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        secondaryColor: freezed == secondaryColor
            ? _value.secondaryColor
            : secondaryColor // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FirmImpl implements _Firm {
  const _$FirmImpl({
    required this.firmId,
    required this.name,
    required this.primaryColor,
    required this.adminId,
    required this.createdAt,
    this.secondaryColor,
  });

  factory _$FirmImpl.fromJson(Map<String, dynamic> json) =>
      _$$FirmImplFromJson(json);

  /// Firestore document ID (UUID or custom ID)
  @override
  final String firmId;

  /// Display name of the firm (e.g., "Acme Corporation")
  @override
  final String name;

  /// Primary brand color as hex string (e.g., "#295CB4")
  @override
  final String primaryColor;

  /// UID of the super_admin who created this firm
  @override
  final String adminId;

  /// Timestamp when the firm was created
  @override
  final DateTime createdAt;

  /// Optional secondary brand color for UI accents
  @override
  final String? secondaryColor;

  @override
  String toString() {
    return 'Firm(firmId: $firmId, name: $name, primaryColor: $primaryColor, adminId: $adminId, createdAt: $createdAt, secondaryColor: $secondaryColor)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FirmImpl &&
            (identical(other.firmId, firmId) || other.firmId == firmId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.primaryColor, primaryColor) ||
                other.primaryColor == primaryColor) &&
            (identical(other.adminId, adminId) || other.adminId == adminId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.secondaryColor, secondaryColor) ||
                other.secondaryColor == secondaryColor));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    firmId,
    name,
    primaryColor,
    adminId,
    createdAt,
    secondaryColor,
  );

  /// Create a copy of Firm
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FirmImplCopyWith<_$FirmImpl> get copyWith =>
      __$$FirmImplCopyWithImpl<_$FirmImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FirmImplToJson(this);
  }
}

abstract class _Firm implements Firm {
  const factory _Firm({
    required final String firmId,
    required final String name,
    required final String primaryColor,
    required final String adminId,
    required final DateTime createdAt,
    final String? secondaryColor,
  }) = _$FirmImpl;

  factory _Firm.fromJson(Map<String, dynamic> json) = _$FirmImpl.fromJson;

  /// Firestore document ID (UUID or custom ID)
  @override
  String get firmId;

  /// Display name of the firm (e.g., "Acme Corporation")
  @override
  String get name;

  /// Primary brand color as hex string (e.g., "#295CB4")
  @override
  String get primaryColor;

  /// UID of the super_admin who created this firm
  @override
  String get adminId;

  /// Timestamp when the firm was created
  @override
  DateTime get createdAt;

  /// Optional secondary brand color for UI accents
  @override
  String? get secondaryColor;

  /// Create a copy of Firm
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FirmImplCopyWith<_$FirmImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
