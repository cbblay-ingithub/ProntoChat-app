import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service class for interacting with Vercel serverless API endpoints
/// replacing any reliance on paid Firebase Cloud Functions.
class ApiService {
  ApiService._internal();
  static final ApiService instance = ApiService._internal();

  /// Default Vercel bridge base URL (can be overridden via environment or configuration)
  static String baseUrl = 'https://pronto-chat.vercel.app/api';

  /// Configure custom API base URL
  static void setBaseUrl(String url) {
    baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Check serverless endpoint health & Spark Plan compatibility mode
  Future<Map<String, dynamic>?> checkHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('[ApiService] Health check returned HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('[ApiService] Health check exception: $e');
      return null;
    }
  }

  /// Verify employee pre-approval status via Vercel serverless function
  Future<Map<String, dynamic>> checkPreApproval({
    required String firmId,
    required String email,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/onboard');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'firmId': firmId,
              'email': email,
              'action': 'check',
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('[ApiService] Pre-approval check failed: HTTP ${response.statusCode}');
        return {
          'success': false,
          'error': 'Server error (HTTP ${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('[ApiService] Pre-approval check exception: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Claim pre-approved membership via Vercel serverless function
  Future<Map<String, dynamic>> claimMembership({
    required String firmId,
    required String email,
    required String uid,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/onboard');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'firmId': firmId,
              'email': email,
              'uid': uid,
              'action': 'claim',
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'error': 'Server error (HTTP ${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('[ApiService] Claim membership exception: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Perform administrative server action via Vercel serverless endpoint
  Future<Map<String, dynamic>> performAdminAction({
    required String action,
    required String firmId,
    String? targetUid,
    String? status,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/admin');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': action,
              'firmId': firmId,
              if (targetUid != null) 'targetUid': targetUid,
              if (status != null) 'status': status,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'error': 'Server error (HTTP ${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('[ApiService] Perform admin action exception: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
