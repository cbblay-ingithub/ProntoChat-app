import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

// Helper to convert hex color string to Color object
Color hexToColor(String hexString, Color fallback) {
  try {
    String colorString = hexString.toUpperCase().replaceAll('#', '');
    if (colorString.length == 6) {
      colorString = 'FF$colorString';
    }
    if (colorString.length == 8) {
      final value = int.tryParse(colorString, radix: 16);
      if (value != null) {
        return Color(value);
      }
    }
  } catch (e) {
    debugPrint('Error parsing color $hexString: $e');
  }
  return fallback;
}

/// Provider for Firebase Auth state stream
final firebaseUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Stream of the current user's membership document
final myMembershipStreamProvider = StreamProvider<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  final user = userAsync.value;
  if (user == null) {
    return Stream.value(null);
  }
  
  final controller = StreamController<DocumentSnapshot<Map<String, dynamic>>?>();
  
  final sub = FirebaseFirestore.instance
      .collection('Memberships')
      .doc(user.uid)
      .snapshots()
      .listen((doc) async {
        if (doc.exists) {
          controller.add(doc);
        } else {
          // If membership doc does not exist, check if user has super_admin/admin role in Users/{uid}
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('Users')
                .doc(user.uid)
                .get();
                
            if (userDoc.exists) {
              final role = userDoc.data()?['role'] as String?;
              if (role == 'super_admin' || role == 'admin') {
                // Check if they own any firm
                final firmsQuery = await FirebaseFirestore.instance
                    .collection('Firms')
                    .where('adminId', isEqualTo: user.uid)
                    .limit(1)
                    .get();
                    
                if (firmsQuery.docs.isNotEmpty) {
                  final firmId = firmsQuery.docs.first.id;
                  
                  // Automatically recreate the missing membership document to heal the state
                  await FirebaseFirestore.instance
                      .collection('Memberships')
                      .doc(user.uid)
                      .set({
                    'uid': user.uid,
                    'firmId': firmId,
                    'status': 'approved',
                    'role': 'admin',
                    'createdAt': FieldValue.serverTimestamp(),
                    'approvedAt': FieldValue.serverTimestamp(),
                  });
                  return;
                }
              }
            }
          } catch (e) {
            debugPrint('Error auto-healing membership: $e');
          }
          controller.add(doc);
        }
      });

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });
  
  return controller.stream;
});

/// Provider that reactively loads the firm document once membership is approved
final membershipLoaderProvider = Provider<void>((ref) {
  final membershipAsync = ref.watch(myMembershipStreamProvider);
  
  membershipAsync.whenData((doc) {
    if (doc != null && doc.exists) {
      final data = doc.data();
      if (data != null) {
        final status = data['status'] as String? ?? 'pending';
        final firmId = data['firmId'] as String? ?? '';
        
        if ((status == 'approved' || status == 'active') && firmId.isNotEmpty) {
          // Fetch the firm document once membership is approved
          Future.microtask(() {
            ref.read(firmNotifierProvider.notifier).loadFirm(firmId);
          });
        }
      }
    }
  });
});

/// Exposes a ThemeData object derived from the approved firm's colors.
/// Falls back to a neutral dark theme if pending approval or if no colors are set.
final brandThemeProvider = Provider<ThemeData>((ref) {
  final currentFirm = ref.watch(currentFirmProvider);
  final membershipAsync = ref.watch(myMembershipStreamProvider);
  
  final membershipDoc = membershipAsync.value;
  final isApproved = membershipDoc != null && 
      membershipDoc.exists && 
      (membershipDoc.data()?['status'] == 'approved' || membershipDoc.data()?['status'] == 'active');
  
  // Default neutral dark theme
  final defaultTheme = ThemeData(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color.fromRGBO(41, 116, 188, 1),
      secondary: Color.fromRGBO(41, 116, 188, 1),
      surface: Color.fromRGBO(28, 27, 27, 1),
    ),
    scaffoldBackgroundColor: const Color.fromRGBO(28, 27, 27, 1),
  );

  // If not approved or no firm details are loaded, return the default neutral theme
  if (!isApproved || currentFirm == null) {
    return defaultTheme;
  }
  
  final primaryColor = hexToColor(currentFirm.primaryColor, const Color.fromRGBO(41, 116, 188, 1));
  final secondaryColor = currentFirm.secondaryColor != null 
      ? hexToColor(currentFirm.secondaryColor!, primaryColor)
      : primaryColor;
      
  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: secondaryColor,
      brightness: Brightness.dark,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: primaryColor,
      centerTitle: true,
    ),
  );
});

