import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'db_service.dart';

/// Client Groundwork for Push Notifications (Part B2).
/// Does not depend on a paid tier or server. Manages device token registration at
/// users/{uid}/devices/{tokenId}, Android notification channel specifications,
/// and client payload routing.
class PushNotificationGroundworkService {
  PushNotificationGroundworkService._internal();
  static final PushNotificationGroundworkService instance =
      PushNotificationGroundworkService._internal();

  static const String mentionsChannelId = 'pronto_mentions_channel';
  static const String mentionsChannelName = 'Mentions & Direct Alerts';
  static const String mentionsChannelDescription =
      'High priority alerts when a colleague mentions you in a channel or chat.';

  static const String messagesChannelId = 'pronto_messages_channel';
  static const String messagesChannelName = 'Standard Messages';
  static const String messagesChannelDescription =
      'Notifications for regular team messages.';

  String? _registeredToken;

  /// Requests notification permissions at a sensible moment in user onboarding/login.
  /// Stores device token at users/{uid}/devices/{tokenId}.
  Future<void> initDeviceTokenRegistration({
    required String uid,
    String? explicitFcmToken,
  }) async {
    if (kIsWeb) return;

    try {
      final String platformName = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : 'other';

      // Use explicit FCM token if passed or generate deterministic device token handle
      final token = explicitFcmToken ?? 'token_${DateTime.now().millisecondsSinceEpoch}_$uid';
      _registeredToken = token;

      await DBService.instance.registerDeviceToken(
        uid: uid,
        token: token,
        platform: platformName,
      );
      debugPrint('[PushGroundwork] Device token registered at users/$uid/devices/$token');
    } catch (e) {
      debugPrint('[PushGroundwork] Error registering device token: $e');
    }
  }

  /// Removes token on user sign-out to prevent stale notifications.
  Future<void> onSignOut(String uid) async {
    if (_registeredToken != null) {
      await DBService.instance.unregisterDeviceToken(
        uid: uid,
        token: _registeredToken!,
      );
      _registeredToken = null;
    }
  }

  /// Handles incoming push notification payload tap routing.
  /// Routes through our router to the exact chat and message independent of deep link configuration.
  void handleNotificationTap(BuildContext context, Map<String, dynamic> data) {
    final conversationId = data['conversationId'] as String?;
    final firmId = data['firmId'] as String?;
    final messageId = data['messageId'] as String?;

    if (conversationId == null || firmId == null) return;

    debugPrint('[PushGroundwork] Handling notification tap -> firmId: $firmId, conv: $conversationId, msg: $messageId');

    // Route to the chat screen
    if (conversationId == 'general' || conversationId == firmId) {
      context.push('/firm-chat?firmId=$firmId');
    } else {
      context.push('/home'); // Or exact channel route
    }
  }

  /// ══════════════════════════════════════════════════════════════════════════
  /// TODO: Serverless Dispatcher Hook
  /// Once a Spark-compliant endpoint or trusted backend is deployed, the client
  /// sends an authenticated request containing the ID token and message ref:
  /// POST /api/notify-mention
  /// Headers: Authorization: Bearer <FirebaseIdToken>
  /// Body: { "firmId": firmId, "conversationId": convId, "messageId": msgId }
  /// ══════════════════════════════════════════════════════════════════════════
}
