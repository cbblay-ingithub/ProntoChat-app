import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pronto_chat/models/firm.dart';
import 'package:pronto_chat/providers/firm/firm_notifier.dart';
import 'package:pronto_chat/providers/firm/firm_state.dart';
import 'package:pronto_chat/services/db_service.dart';

/// Provider for DBService singleton
final dbServiceProvider = Provider<DBService>((ref) {
  return DBService.instance;
});

/// Provider for FirmNotifier StateNotifier
final firmNotifierProvider = StateNotifierProvider<FirmNotifier, FirmState>((
  ref,
) {
  final dbService = ref.watch(dbServiceProvider);
  return FirmNotifier(dbService: dbService);
});

/// Convenience provider to get the current firm
final currentFirmProvider = Provider<Firm?>((ref) {
  final firmState = ref.watch(firmNotifierProvider);
  return firmState.currentFirm;
});

/// Convenience provider to check if a firm operation is loading
final isFirmLoadingProvider = Provider<bool>((ref) {
  final firmState = ref.watch(firmNotifierProvider);
  return firmState.isLoading;
});

/// Convenience provider to get any firm-related errors
final firmErrorProvider = Provider<String?>((ref) {
  final firmState = ref.watch(firmNotifierProvider);
  return firmState.error;
});

/// Convenience provider to get all user firms
final userFirmsProvider = Provider<List<Firm>>((ref) {
  final firmState = ref.watch(firmNotifierProvider);
  return firmState.userFirms;
});
