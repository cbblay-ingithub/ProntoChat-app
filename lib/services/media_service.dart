import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/media_ref.dart';
import 'media_config.dart';

/// Service responsible for unsigned uploads to Cloudinary and building delivery URLs.
/// Follows strict security: NO API keys or secrets are stored or transmitted.
class MediaService {
  static final MediaService instance = MediaService._internal();
  MediaService._internal();

  /// Build public delivery URL for a MediaRef and named transformation.
  /// Strict transformations is ON: URLs strictly use `t_{transformationName}`.
  String urlFor(MediaRef ref, MediaVariant variant) {
    final cloudName = MediaConfig.cloudName;
    final transform = variant.transformationName;
    final key = ref.key;
    return 'https://res.cloudinary.com/$cloudName/image/upload/t_$transform/$key';
  }

  /// Helper to resolve an image URL given either a new MediaRef or a legacy full URL.
  /// Checks `mediaRef` first; if absent, falls back to `legacyUrl`.
  String? resolveUrl({
    MediaRef? mediaRef,
    String? legacyUrl,
    required MediaVariant variant,
  }) {
    if (mediaRef != null && mediaRef.key.isNotEmpty) {
      return urlFor(mediaRef, variant);
    }
    if (legacyUrl != null && legacyUrl.isNotEmpty) {
      return legacyUrl;
    }
    return null;
  }

  /// Returns the appropriate upload preset name for the given purpose.
  String presetFor(MediaPurpose purpose) {
    switch (purpose) {
      case MediaPurpose.avatar:
        return MediaConfig.presetAvatar;
      case MediaPurpose.logo:
        return MediaConfig.presetLogo;
      case MediaPurpose.chat:
        return MediaConfig.presetChat;
    }
  }

  /// Allowed file extensions per media purpose.
  List<String> allowedExtensions(MediaPurpose purpose) {
    switch (purpose) {
      case MediaPurpose.avatar:
      case MediaPurpose.chat:
        return const ['jpg', 'jpeg', 'png', 'webp', 'heic'];
      case MediaPurpose.logo:
        // Logos must support PNG transparency and not force webp conversion
        return const ['png', 'jpg', 'jpeg', 'webp'];
    }
  }

  /// Check if file size is within the allowed limit (10MB).
  bool isUnderSizeLimit(int bytes) => bytes <= MediaConfig.kMaxUploadBytes;

  /// Check if file extension is supported for the given purpose.
  bool isSupportedExtension(String fileName, [MediaPurpose purpose = MediaPurpose.chat]) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    return ext.isNotEmpty && allowedExtensions(purpose).contains(ext);
  }

  /// Validate image bytes and filename before initiating network upload.
  void validateImage({
    required Uint8List bytes,
    required String fileName,
    required MediaPurpose purpose,
  }) {
    // 1. File size check
    if (bytes.length > MediaConfig.kMaxUploadBytes) {
      final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      throw Exception(
        'Image size ($mb MB) exceeds the 10 MB limit. Please select a smaller image.',
      );
    }

    if (bytes.isEmpty) {
      throw Exception('Selected image file is empty.');
    }

    // 2. Extension check
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    final allowed = allowedExtensions(purpose);
    if (ext.isNotEmpty && !allowed.contains(ext)) {
      throw Exception(
        'Format ".$ext" is not supported for ${purpose.name}. Allowed: ${allowed.join(', ')}',
      );
    }
  }

  /// Upload raw image bytes to Cloudinary via unsigned preset.
  /// Includes exponential backoff retry for transient network errors.
  Future<MediaRef> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required MediaPurpose purpose,
    required String firmId,
    void Function(double progress)? onProgress,
  }) async {
    // Validate client-side first
    validateImage(bytes: bytes, fileName: fileName, purpose: purpose);

    final cloudName = MediaConfig.cloudName;
    final preset = presetFor(purpose);
    final endpoint = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    int attempts = 0;
    const maxAttempts = 3;

    onProgress?.call(0.1);

    while (attempts < maxAttempts) {
      attempts++;
      try {
        final request = http.MultipartRequest('POST', endpoint);
        request.fields['upload_preset'] = preset;
        request.fields['tags'] = 'firmId:$firmId,purpose:${purpose.name}';
        request.fields['context'] = 'firmId=$firmId|purpose=${purpose.name}';

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName.isNotEmpty ? fileName : 'upload.jpg',
          ),
        );

        onProgress?.call(0.3);

        final streamedResponse = await request.send();
        onProgress?.call(0.7);

        final responseBody = await streamedResponse.stream.bytesToString();
        onProgress?.call(0.9);

        if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
          final Map<String, dynamic> data = jsonDecode(responseBody) as Map<String, dynamic>;
          final String publicId = data['public_id'] as String? ?? '';
          if (publicId.isEmpty) {
            throw Exception('Cloudinary upload response missing public_id');
          }

          final mediaRef = MediaRef(
            provider: 'cloudinary',
            key: publicId,
            kind: 'image',
            w: (data['width'] as num?)?.toInt() ?? 0,
            h: (data['height'] as num?)?.toInt() ?? 0,
            bytes: (data['bytes'] as num?)?.toInt() ?? bytes.length,
            format: (data['format'] as String? ?? 'webp').toLowerCase(),
          );

          debugPrint('[MediaService] Uploaded successfully: ${mediaRef.toMap()}');
          onProgress?.call(1.0);
          return mediaRef;
        } else {
          // Cloudinary returned an error status code
          String errorMessage = 'Upload failed (${streamedResponse.statusCode})';
          try {
            final Map<String, dynamic> errJson = jsonDecode(responseBody) as Map<String, dynamic>;
            if (errJson['error']?['message'] != null) {
              errorMessage = errJson['error']['message'].toString();
            }
          } catch (_) {}

          // If client error (4xx), do not retry — fail immediately
          if (streamedResponse.statusCode >= 400 && streamedResponse.statusCode < 500) {
            throw Exception('Cloudinary error: $errorMessage');
          }

          // If server error (5xx) and has attempts left, back off and retry
          if (attempts >= maxAttempts) {
            throw Exception('Upload failed after $attempts attempts: $errorMessage');
          }
        }
      } catch (e) {
        if (attempts >= maxAttempts || e.toString().contains('Cloudinary error:')) {
          rethrow;
        }
        debugPrint('[MediaService] Upload attempt $attempts failed: $e. Retrying...');
      }

      // Exponential backoff wait before retry
      await Future.delayed(Duration(milliseconds: 500 * attempts));
    }

    throw Exception('Failed to upload image to Cloudinary.');
  }
}
