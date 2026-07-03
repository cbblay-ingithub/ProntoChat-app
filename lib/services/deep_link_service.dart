import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class DeepLinkService {
  // Singleton instance
  static final DeepLinkService instance = DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  final StreamController<String> _firmIdController = StreamController<String>.broadcast();

  // Expose firmIdStream as requested
  Stream<String> get firmIdStream => _firmIdController.stream;

  DeepLinkService._internal() {
    _init();
  }

  void _init() {
    // 1. Handle warm starts (app in background/foreground)
    try {
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) {
          _handleUri(uri);
        },
        onError: (err) {
          debugPrint('DeepLinkService warm start error: $err');
        },
      );
    } catch (e) {
      debugPrint('DeepLinkService initialization error: $e');
    }

    // 2. Handle cold starts (app was closed)
    _checkInitialLink();
  }

  Future<void> _checkInitialLink() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (e) {
      debugPrint('DeepLinkService cold start error: $e');
    }
  }

  void _handleUri(Uri uri) {
    try {
      debugPrint('Parsed URI: $uri');
      // Format: https://officespace.chottu.link/?firmId=<firmId>
      final firmId = uri.queryParameters['firmId'];
      if (firmId != null && firmId.trim().isNotEmpty) {
        _firmIdController.add(firmId);
      }
    } catch (e) {
      debugPrint('Error parsing URI: $e');
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
    _firmIdController.close();
  }
}
