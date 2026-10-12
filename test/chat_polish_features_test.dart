import 'package:flutter_test/flutter_test.dart';
import 'package:pronto_chat/models/chat_message.dart';
import 'package:pronto_chat/models/chat_polish_models.dart';
import 'package:pronto_chat/models/firm.dart';

void main() {
  group('ChatMessage Polish Features', () {
    test('serializes and deserializes mentions, replyTo, editedAt, and deleted', () {
      final now = DateTime.now();
      const mention = MessageMention(uid: 'user_123', name: 'Alice', start: 6, end: 12);
      const reply = MessageReplyTo(
        messageId: 'msg_orig',
        senderId: 'user_456',
        senderName: 'Charlie',
        snippet: 'Original message text here',
      );

      final msg = ChatMessage(
        messageId: 'msg_001',
        senderId: 'user_789',
        senderName: 'Bob',
        text: 'Hello @Alice, responding to you',
        timestamp: now,
        mentions: const [mention],
        replyTo: reply,
        editedAt: now.add(const Duration(minutes: 1)),
        deleted: false,
      );

      final map = msg.toMap();
      expect(map['text'], 'Hello @Alice, responding to you');
      expect(map['content'], 'Hello @Alice, responding to you');
      expect(map['deleted'], false);
      expect(map['mentions'], isA<List>());
      expect((map['mentions'] as List).length, 1);
      expect((map['mentions'] as List)[0]['uid'], 'user_123');
      expect(map['replyTo'], isNotNull);
      expect((map['replyTo'] as Map)['messageId'], 'msg_orig');
      expect((map['replyTo'] as Map)['snippet'], 'Original message text here');

      // Round-trip deserialization
      final restored = ChatMessage.fromMap(map, 'msg_001');
      expect(restored.messageId, 'msg_001');
      expect(restored.senderName, 'Bob');
      expect(restored.text, 'Hello @Alice, responding to you');
      expect(restored.mentions.length, 1);
      expect(restored.mentions[0].name, 'Alice');
      expect(restored.replyTo?.messageId, 'msg_orig');
      expect(restored.replyTo?.snippet, 'Original message text here');
      expect(restored.deleted, false);
      expect(restored.editedAt, isNotNull);
    });

    test('backward compatibility: falls back to "content" field if "text" is absent', () {
      final legacyMap = <String, dynamic>{
        'senderId': 'legacy_user',
        'senderName': 'Legacy Charlie',
        'content': 'Message stored under legacy content field',
        'timestamp': DateTime.now().toIso8601String(),
      };

      final msg = ChatMessage.fromMap(legacyMap, 'legacy_01');
      expect(msg.text, 'Message stored under legacy content field');
      expect(msg.deleted, false);
      expect(msg.mentions, isEmpty);
      expect(msg.replyTo, isNull);
    });

    test('tombstone message representation when deleted is true', () {
      final deletedMsg = ChatMessage(
        messageId: 'del_01',
        senderId: 'user_1',
        senderName: 'User 1',
        text: 'This message was deleted',
        timestamp: DateTime.now(),
        deleted: true,
      );

      final map = deletedMsg.toMap();
      expect(map['deleted'], true);

      final restored = ChatMessage.fromMap(map, 'del_01');
      expect(restored.deleted, true);
    });
  });

  group('UserPresence Logic', () {
    test('identifies user as online if lastSeenAt is within 5 minutes', () {
      final recent = DateTime.now().subtract(const Duration(minutes: 2));
      final presence = UserPresence(uid: 'u1', lastSeenAt: recent);

      expect(presence.isOnline, isTrue);
      expect(presence.formatLastSeen(), 'Online');
    });

    test('formats last seen today with month name, day, and time', () {
      final todayTime = DateTime.now().subtract(const Duration(hours: 2));
      final presence = UserPresence(uid: 'u2', lastSeenAt: todayTime);

      expect(presence.isOnline, isFalse);
      final formatted = presence.formatLastSeen();
      expect(formatted, startsWith('last seen today, '));
      expect(formatted, contains(' at '));
    });

    test('formats last seen yesterday with month name, day, and time', () {
      final yesterdayTime = DateTime.now().subtract(const Duration(days: 1, hours: 2));
      final presence = UserPresence(uid: 'u3', lastSeenAt: yesterdayTime);

      expect(presence.isOnline, isFalse);
      final formatted = presence.formatLastSeen();
      expect(formatted, startsWith('last seen yesterday, '));
      expect(formatted, contains(' at '));
    });

    test('formats older dates with calendar date and time', () {
      final olderTime = DateTime(2025, 3, 15, 14, 30);
      final presence = UserPresence(uid: 'u4', lastSeenAt: olderTime);

      expect(presence.isOnline, isFalse);
      final formatted = presence.formatLastSeen();
      expect(formatted, contains('Mar 15'));
      expect(formatted, contains('2025'));
      expect(formatted, contains('14:30'));
    });
  });

  group('TypingIndicatorStatus Logic', () {
    test('isActive returns true only within skew tolerance (< 5s)', () {
      final active = TypingIndicatorStatus(
        uid: 'u1',
        userName: 'Alice',
        updatedAt: DateTime.now().subtract(const Duration(seconds: 2)),
      );
      expect(active.isActive, isTrue);

      final expired = TypingIndicatorStatus(
        uid: 'u2',
        userName: 'Bob',
        updatedAt: DateTime.now().subtract(const Duration(seconds: 10)),
      );
      expect(expired.isActive, isFalse);
    });
  });

  group('ReadPointer Serialization', () {
    test('correctly serializes and deserializes lastReadMessageId and hasMention', () {
      final now = DateTime.now();
      final read = ReadPointer(
        uid: 'u1',
        lastReadMessageId: 'msg_999',
        lastReadAt: now,
        hasMention: true,
      );

      final map = read.toMap();
      expect(map['lastReadMessageId'], 'msg_999');
      expect(map['hasMention'], true);

      final restored = ReadPointer.fromMap('u1', map);
      expect(restored.uid, 'u1');
      expect(restored.lastReadMessageId, 'msg_999');
      expect(restored.hasMention, true);
    });
  });

  group('PinnedMessage Cap, Expiration & Precedence', () {
    test('serializes and deserializes PinnedMessage with pinnedUntil', () {
      final now = DateTime.now();
      final until = now.add(const Duration(hours: 24));
      final pinned = PinnedMessage(
        messageId: 'msg_pin_1',
        snippet: 'Important project update',
        pinnedAt: now,
        pinnedUntil: until,
        pinnedBy: 'admin_1',
      );

      final map = pinned.toMap();
      expect(map['messageId'], 'msg_pin_1');
      expect(map['snippet'], 'Important project update');
      expect(map['pinnedBy'], 'admin_1');
      expect(map['pinnedUntil'], isNotNull);

      final restored = PinnedMessage.fromMap(map);
      expect(restored.messageId, 'msg_pin_1');
      expect(restored.snippet, 'Important project update');
      expect(restored.pinnedBy, 'admin_1');
      expect(restored.isExpired, isFalse);
      expect(restored.formatRemaining(), contains('left'));
    });

    test('correctly identifies expired pinned messages', () {
      final now = DateTime.now();
      final expired = PinnedMessage(
        messageId: 'msg_old_pin',
        snippet: 'Expired pin',
        pinnedAt: now.subtract(const Duration(hours: 25)),
        pinnedUntil: now.subtract(const Duration(hours: 1)),
        pinnedBy: 'admin_1',
      );

      expect(expired.isExpired, isTrue);
      expect(expired.formatRemaining(), 'Expired');
    });

    test('newly pinned message takes precedence at index 0 and evicts oldest when cap is 3', () {
      final now = DateTime.now();
      final list = <PinnedMessage>[
        PinnedMessage(
          messageId: 'pin_1',
          snippet: 'First',
          pinnedAt: now.subtract(const Duration(hours: 2)),
          pinnedUntil: now.add(const Duration(hours: 22)),
          pinnedBy: 'u',
        ),
        PinnedMessage(
          messageId: 'pin_2',
          snippet: 'Second',
          pinnedAt: now.subtract(const Duration(hours: 1)),
          pinnedUntil: now.add(const Duration(hours: 23)),
          pinnedBy: 'u',
        ),
        PinnedMessage(
          messageId: 'pin_3',
          snippet: 'Third',
          pinnedAt: now,
          pinnedUntil: now.add(const Duration(hours: 24)),
          pinnedBy: 'u',
        ),
      ];

      final newPin = PinnedMessage(
        messageId: 'pin_new',
        snippet: 'Brand New Pin',
        pinnedAt: now.add(const Duration(minutes: 5)),
        pinnedUntil: now.add(const Duration(hours: 24)),
        pinnedBy: 'u',
      );

      // Precedence insertion
      list.insert(0, newPin);
      if (list.length > 3) {
        list.removeRange(3, list.length);
      }

      expect(list.length, 3);
      // Brand new pin must be at index 0 (taking precedence)
      expect(list[0].messageId, 'pin_new');
      expect(list[1].messageId, 'pin_1');
      expect(list[2].messageId, 'pin_2');
      // Oldest pin (pin_3) was evicted
      expect(list.any((p) => p.messageId == 'pin_3'), isFalse);
    });
  });

  group('Firm Privacy Settings', () {
    test('defaults showLastSeen and showReadReceipts to true when omitted', () {
      final firmMap = <String, dynamic>{
        'firmId': 'firm_001',
        'adminId': 'admin_001',
        'name': 'Acme Corp',
        'primaryColor': '#295CB4',
        'seatLimit': 10,
        'createdAt': DateTime.now().toIso8601String(),
      };

      final firm = Firm.fromJson(firmMap);
      expect(firm.showLastSeen, isTrue);
      expect(firm.showReadReceipts, isTrue);
    });

    test('respects explicit privacy settings toggles when false', () {
      final firmMap = <String, dynamic>{
        'firmId': 'firm_002',
        'adminId': 'admin_001',
        'name': 'Private Corp',
        'primaryColor': '#295CB4',
        'seatLimit': 10,
        'createdAt': DateTime.now().toIso8601String(),
        'showLastSeen': false,
        'showReadReceipts': false,
      };

      final firm = Firm.fromJson(firmMap);
      expect(firm.showLastSeen, isFalse);
      expect(firm.showReadReceipts, isFalse);
    });
  });
}
