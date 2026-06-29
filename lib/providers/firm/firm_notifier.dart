import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pronto_chat/models/firm.dart';
import 'package:pronto_chat/providers/firm/firm_state.dart';
import 'package:pronto_chat/services/db_service.dart';

/// StateNotifier for managing Firm state and operations
class FirmNotifier extends StateNotifier<FirmState> {
  FirmNotifier({required this.dbService}) : super(const FirmState());

  final DBService dbService;

  /// Load a firm by ID and set it as the current firm
  Future<void> loadFirm(String firmId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final firm = await dbService.getFirm(firmId);
      state = state.copyWith(currentFirm: firm, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load firm: ${e.toString()}',
      );
    }
  }

  /// Create a new firm (called during firm registration)
  /// This is typically coordinated through the auth flow,
  /// but can be called directly if needed
  Future<Firm> createFirm(Firm firm) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // DBService.createFirmWithAdmin handles the atomic write
      // This method just sets the firm in state after creation
      state = state.copyWith(currentFirm: firm, isLoading: false);
      return firm;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to create firm: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// Load all firms the current user is a member of
  Future<void> loadUserFirms(String uid) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final firms = await dbService.getUserFirms(uid).first;
      state = state.copyWith(userFirms: firms, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load firms: ${e.toString()}',
      );
    }
  }

  /// Set the loading state explicitly
  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  /// Clear the current firm and reset state
  void clearFirm() {
    state = const FirmState();
  }

  /// Clear any error messages
  void clearError() {
    state = state.copyWith(error: null);
  }
}
