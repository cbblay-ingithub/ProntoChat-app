import 'package:pronto_chat/models/firm.dart';

/// State class for Firm-related operations
/// Tracks current firm context and loading/error states
class FirmState {
  const FirmState({
    this.currentFirm,
    this.isLoading = false,
    this.error,
    this.userFirms = const [],
  });

  /// The currently active firm (admin's firm)
  final Firm? currentFirm;

  /// Whether a firm operation is in progress
  final bool isLoading;

  /// Error message if a firm operation failed
  final String? error;

  /// List of all firms the user is a member of
  /// (Phase 2: when employees can switch firms)
  final List<Firm> userFirms;

  /// Create a copy of FirmState with some fields replaced
  FirmState copyWith({
    Firm? currentFirm,
    bool? isLoading,
    String? error,
    List<Firm>? userFirms,
  }) {
    return FirmState(
      currentFirm: currentFirm ?? this.currentFirm,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      userFirms: userFirms ?? this.userFirms,
    );
  }

  @override
  String toString() =>
      'FirmState(currentFirm: $currentFirm, isLoading: $isLoading, error: $error, userFirms: $userFirms)';
}
