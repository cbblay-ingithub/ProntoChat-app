# Push-Sending Server Specification (FCM Backend Contract)

> **Context**: ProntoChat operates strictly on the **Firebase Spark Free Tier** (no paid billing account, no Cloud Functions, no paid external servers).
> Push notification client-side groundwork (device token registration, Android notification channels, incoming payload routing) is fully implemented in Flutter.
> This document specifies the exact contract for an external push-sending server or worker should one be deployed on a free-tier hosting provider (e.g. Free Cloud Run instance, Fly.io free tier, Oracle Cloud Always Free VM, or GitHub Actions webhook).

---

## 1. Spark Zero-Cost Serverless Execution Assumptions

1. **Why No Cloud Functions?**
   Firebase Spark plan prohibits Cloud Functions entirely because Google Cloud Functions require a Blaze (pay-as-you-go) billing account.
2. **FCM v1 API Requirement**:
   Google FCM v1 HTTP API (`https://fcm.googleapis.com/v1/projects/{projectId}/messages:send`) requires OAuth2 access tokens generated using a Google Service Account Private Key.
   Client devices (Flutter mobile apps) cannot safely hold a Google Service Account key due to security risks.
3. **Data Flow**:
   - Flutter App writes device FCM tokens to: `Users/{userId}/devices/{tokenId}`
   - When a message with `@mentions` is sent, Flutter writes an inbox entry to: `Firms/{firmId}/mentions/{targetUid}/items/{messageId}`
   - If an external free-tier backend is configured, it polls or receives a webhook and dispatches FCM pushes using the contract below.

---

## 2. Server API Endpoint Specification

### `POST /api/v1/push/dispatch-mention`

Dispatches a high-priority push notification to a mentioned user's registered devices.

#### Request Headers
```http
POST /api/v1/push/dispatch-mention HTTP/1.1
Host: push.prontochat.local
Content-Type: application/json
Authorization: Bearer <SERVER_SHARED_SECRET_OR_JWT>
X-Firm-ID: firm_workspace_101
```

#### Request Payload
```json
{
  "targetUid": "emp_alex_101",
  "firmId": "firm_workspace_101",
  "conversationId": "all_staff",
  "conversationTitle": "#all-staff",
  "conversationType": "allStaff",
  "messageId": "msg_8928347293",
  "senderId": "user_lead_01",
  "senderName": "Sarah Connor",
  "snippet": "Hey @Alex Morgan please review the Q3 financial report.",
  "isAllMention": false,
  "timestamp": "2026-10-14T12:00:00.000Z"
}
```

#### Target Device Resolution
1. Backend reads registered tokens: `Users/{targetUid}/devices` subcollection.
2. Filters active devices where `fcmToken` is present and `updatedAt` is recent (< 60 days).
3. If no tokens exist, returns `200 OK` with `{"dispatched": 0, "status": "no_registered_devices"}`.

#### FCM v1 Message Payload Sent to Google FCM
```json
{
  "message": {
    "token": "dKjs83...fcm_device_token",
    "notification": {
      "title": "Sarah Connor mentioned you in #all-staff",
      "body": "Hey @Alex Morgan please review the Q3 financial report."
    },
    "data": {
      "type": "mention",
      "firmId": "firm_workspace_101",
      "conversationId": "all_staff",
      "conversationTitle": "#all-staff",
      "conversationType": "allStaff",
      "messageId": "msg_8928347293",
      "senderId": "user_lead_01",
      "click_action": "FLUTTER_NOTIFICATION_CLICK"
    },
    "android": {
      "priority": "HIGH",
      "notification": {
        "channel_id": "pronto_chat_mentions",
        "color": "#00E5FF",
        "icon": "ic_notification_mention",
        "default_vibrate_timings": true
      }
    },
    "apns": {
      "payload": {
        "aps": {
          "sound": "default",
          "badge": 1
        }
      }
    }
  }
}
```

---

## 3. Flutter Client Groundwork & Integration Hook

The client-side groundwork has already been prepared in:
- `lib/services/push_notification_groundwork_service.dart`

### Key Flutter Implementation Hooks:
1. **Device Token Registration**:
   `PushNotificationGroundworkService.instance.registerCurrentDeviceToken(firmId: firmId)`
   Stores device details (platform, model, FCM token, timestamp) under:
   `Users/{userId}/devices/{deviceInstallationId}`
2. **Android Channels**:
   - `pronto_chat_mentions`: High importance, vibration enabled, cyan accent tint.
   - `pronto_chat_messages`: Default importance, standard chime.
3. **Deep Link / Tap Router**:
   `PushNotificationGroundworkService.instance.handleNotificationPayload(data)`
   Routes directly to `ChannelChatScreen` or `FirmChatScreen` and highlights the target message.
4. **Marked Server Webhook Hook**:
   Located in `lib/services/push_notification_groundwork_service.dart`:
   ```dart
   // TODO(Spark-Free-Tier-Push-Dispatch):
   // On Firebase Spark (free tier), Cloud Functions cannot be deployed.
   // If an external microservice or Cloud Run instance is added later,
   // invoke the HTTP endpoint defined in docs/push_server_spec.md here.
   ```
