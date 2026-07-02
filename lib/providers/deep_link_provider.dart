import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/deep_link_service.dart';

// ── PRONTOCHAT ADDITION ──
final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService.instance;
});

final firmIdFromLinkProvider = StreamProvider<String>((ref) {
  final deepLinkService = ref.watch(deepLinkServiceProvider);
  return deepLinkService.firmIdStream;
});
// ─────────────────────────
