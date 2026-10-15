import 'package:flutter_test/flutter_test.dart';
import 'package:pronto_chat/models/media_ref.dart';
import 'package:pronto_chat/services/media_config.dart';
import 'package:pronto_chat/services/media_service.dart';
import 'package:pronto_chat/models/chat_message.dart';
import 'package:pronto_chat/models/user.dart';
import 'package:pronto_chat/models/firm.dart';

void main() {
  group('MediaRef Model', () {
    test('serializes and deserializes properly', () {
      const ref = MediaRef(
        provider: 'cloudinary',
        key: 'chat/photo_123',
        kind: 'image',
        w: 1920,
        h: 1080,
        bytes: 524288,
        format: 'webp',
      );

      final map = ref.toMap();
      expect(map['provider'], 'cloudinary');
      expect(map['key'], 'chat/photo_123');
      expect(map['kind'], 'image');
      expect(map['w'], 1920);
      expect(map['h'], 1080);
      expect(map['bytes'], 524288);
      expect(map['format'], 'webp');

      final restored = MediaRef.fromMap(map);
      expect(restored, isNotNull);
      expect(restored!.provider, 'cloudinary');
      expect(restored.key, 'chat/photo_123');
      expect(restored.w, 1920);
      expect(restored.h, 1080);
      expect(restored.bytes, 524288);
      expect(restored.format, 'webp');
    });

    test('clamps aspectRatio between 0.33 and 3.0', () {
      // Normal 16:9
      const normal = MediaRef(
        provider: 'cloudinary',
        key: 'k1',
        kind: 'image',
        w: 1600,
        h: 900,
      );
      expect(normal.aspectRatio, closeTo(1.777, 0.01));

      // Extremely tall (e.g. 100 x 1000 = 0.1) should clamp to 0.33
      const tall = MediaRef(
        provider: 'cloudinary',
        key: 'k2',
        kind: 'image',
        w: 100,
        h: 1000,
      );
      expect(tall.aspectRatio, 0.33);

      // Extremely wide (e.g. 4000 x 500 = 8.0) should clamp to 3.0
      const wide = MediaRef(
        provider: 'cloudinary',
        key: 'k3',
        kind: 'image',
        w: 4000,
        h: 500,
      );
      expect(wide.aspectRatio, 3.0);

      // Zero or missing dimensions fallback to 1.0
      const zero = MediaRef(
        provider: 'cloudinary',
        key: 'k4',
        kind: 'image',
        w: 0,
        h: 0,
      );
      expect(zero.aspectRatio, 1.0);
    });

    test('returns null when fromMap is passed null or non-map', () {
      expect(MediaRef.fromMap(null), isNull);
      expect(MediaRef.fromMap('not a map'), isNull);
      expect(MediaRef.fromMap({}), isNull); // empty key returns null
    });
  });

  group('MediaService URL Generation with Strict Transformations', () {
    test('formats delivery URLs with named transformations t_<name> only', () {
      const ref = MediaRef(
        provider: 'cloudinary',
        key: 'main-sample',
        kind: 'image',
        w: 800,
        h: 600,
      );

      final avatarSmUrl = MediaService.instance.urlFor(ref, MediaVariant.avatarSm);
      expect(
        avatarSmUrl,
        'https://res.cloudinary.com/${MediaConfig.cloudName}/image/upload/t_avatar_sm/main-sample',
      );

      final avatarLgUrl = MediaService.instance.urlFor(ref, MediaVariant.avatarLg);
      expect(
        avatarLgUrl,
        'https://res.cloudinary.com/${MediaConfig.cloudName}/image/upload/t_avatar_lg/main-sample',
      );

      final logoSmUrl = MediaService.instance.urlFor(ref, MediaVariant.logoSm);
      expect(
        logoSmUrl,
        'https://res.cloudinary.com/${MediaConfig.cloudName}/image/upload/t_logo_sm/main-sample',
      );

      final logoLgUrl = MediaService.instance.urlFor(ref, MediaVariant.logoLg);
      expect(
        logoLgUrl,
        'https://res.cloudinary.com/${MediaConfig.cloudName}/image/upload/t_logo_lg/main-sample',
      );

      final chatThumbUrl = MediaService.instance.urlFor(ref, MediaVariant.chatThumb);
      expect(
        chatThumbUrl,
        'https://res.cloudinary.com/${MediaConfig.cloudName}/image/upload/t_chat_thumb/main-sample',
      );

      final chatFullUrl = MediaService.instance.urlFor(ref, MediaVariant.chatFull);
      expect(
        chatFullUrl,
        'https://res.cloudinary.com/${MediaConfig.cloudName}/image/upload/t_chat_full/main-sample',
      );

      // Verify no ad-hoc transformation parameters are present in URL
      for (final url in [avatarSmUrl, avatarLgUrl, logoSmUrl, logoLgUrl, chatThumbUrl, chatFullUrl]) {
        expect(url.contains('w_'), isFalse);
        expect(url.contains('h_'), isFalse);
        expect(url.contains('c_fill'), isFalse);
        expect(url.contains('c_limit'), isFalse);
      }
    });

    test('presetFor returns configured preset for each purpose', () {
      expect(MediaService.instance.presetFor(MediaPurpose.avatar), MediaConfig.presetAvatar);
      expect(MediaService.instance.presetFor(MediaPurpose.logo), MediaConfig.presetLogo);
      expect(MediaService.instance.presetFor(MediaPurpose.chat), MediaConfig.presetChat);
    });

    test('validates file size limit of 10MB', () {
      // 10MB = 10,485,760 bytes
      expect(MediaService.instance.isUnderSizeLimit(10485760), isTrue);
      expect(MediaService.instance.isUnderSizeLimit(10485761), isFalse);
      expect(MediaService.instance.isUnderSizeLimit(15 * 1024 * 1024), isFalse);
    });

    test('validates allowed image extensions', () {
      expect(MediaService.instance.isSupportedExtension('photo.png'), isTrue);
      expect(MediaService.instance.isSupportedExtension('photo.jpg'), isTrue);
      expect(MediaService.instance.isSupportedExtension('photo.jpeg'), isTrue);
      expect(MediaService.instance.isSupportedExtension('photo.webp'), isTrue);
      expect(MediaService.instance.isSupportedExtension('photo.heic'), isTrue);
      expect(MediaService.instance.isSupportedExtension('document.pdf'), isFalse);
      expect(MediaService.instance.isSupportedExtension('video.mp4'), isFalse);
    });
  });

  group('Model Integrations with MediaRef', () {
    test('ChatMessage supports image type and media ref', () {
      final msg = ChatMessage(
        id: 'msg_img_1',
        senderId: 'user_1',
        content: 'Check this out',
        timestamp: DateTime(2026, 10, 14, 12, 0),
        type: 'image',
        media: const MediaRef(
          provider: 'cloudinary',
          key: 'chat/test_img',
          kind: 'image',
          w: 1200,
          h: 800,
          bytes: 204800,
          format: 'jpg',
        ),
      );

      final map = msg.toMap();
      expect(map['type'], 'image');
      expect(map['media'], isA<Map<String, dynamic>>());
      expect(map['media']['key'], 'chat/test_img');

      final restored = ChatMessage.fromMap(map, 'msg_img_1');
      expect(restored.type, 'image');
      expect(restored.media, isNotNull);
      expect(restored.media!.key, 'chat/test_img');
      expect(restored.media!.w, 1200);
      expect(restored.media!.h, 800);
    });

    test('AppUser supports avatar MediaRef and legacy image URL', () {
      final user = AppUser(
        uid: 'user_abc',
        email: 'alice@example.com',
        name: 'Alice',
        image: 'https://res.cloudinary.com/dj4miyael/image/upload/t_avatar_lg/avatars/user_abc',
        avatar: const MediaRef(
          provider: 'cloudinary',
          key: 'avatars/user_abc',
          kind: 'image',
          w: 256,
          h: 256,
        ),
      );

      final firestoreMap = user.toFirestore();
      expect(firestoreMap['avatar'], isNotNull);
      expect(firestoreMap['avatar']['key'], 'avatars/user_abc');
      expect(firestoreMap['image'], contains('t_avatar_lg'));

      final restored = AppUser.fromFirestore(firestoreMap, 'user_abc');
      expect(restored.avatar, isNotNull);
      expect(restored.avatar!.key, 'avatars/user_abc');
      expect(restored.image, contains('t_avatar_lg'));
    });

    test('Firm supports logo MediaRef and legacy logoUrl', () {
      final firm = Firm(
        id: 'firm_1',
        name: 'Acme Corp',
        adminId: 'admin_1',
        ownerUid: 'admin_1',
        logoUrl: 'https://res.cloudinary.com/dj4miyael/image/upload/t_logo_lg/logos/firm_1',
        logo: const MediaRef(
          provider: 'cloudinary',
          key: 'logos/firm_1',
          kind: 'image',
          w: 512,
          h: 512,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final json = firm.toJson();
      expect(json['logo'], isNotNull);
      expect(json['logo']['key'], 'logos/firm_1');
      expect(json['logoUrl'], contains('t_logo_lg'));

      final restored = Firm.fromJson(json, 'firm_1');
      expect(restored.logo, isNotNull);
      expect(restored.logo!.key, 'logos/firm_1');
      expect(restored.logoUrl, contains('t_logo_lg'));
    });
  });
}
