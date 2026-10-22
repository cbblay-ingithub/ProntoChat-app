import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:pronto_chat/firebase_options.dart';

/// Seed script for the Admin Dashboard.
/// Populates realistic test data across all 12 metrics:
/// - ~120 staff members (85 active, 25 invites, 10 revoked)
/// - 6 departments (including 1 with no head and 1 with zero staff)
/// - Join dates distributed over 10 weeks
/// - Project group with revoked owner
/// - Policy notice with 65% acknowledgement rate
/// - 10 audit log entries
///
/// SAFETY GUARD:
/// Hard aborts if targeting a production environment or if ALLOW_SEED != 'true'.
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Parse Firm ID from arguments
  String? firmId;
  for (final arg in args) {
    if (arg.startsWith('--firmId=')) {
      firmId = arg.substring('--firmId='.length);
    }
  }

  // 2. Production Safety Guard
  final allowSeed = Platform.environment['ALLOW_SEED'] == 'true' || args.contains('--allowSeed');
  if (!allowSeed) {
    stderr.writeln('⛔ [ABORT] Refusing to seed without explicit safety flag.');
    stderr.writeln('To run this script, provide --allowSeed or set ALLOW_SEED=true in environment:');
    stderr.writeln('  dart run scripts/seed_dashboard_data.dart --allowSeed --firmId=<YOUR_FIRM_ID>');
    exit(1);
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final projectId = Firebase.app().options.projectId;
  stdout.writeln('Connected to Firebase Project: $projectId');

  if (projectId.toLowerCase().contains('prod') || projectId.toLowerCase().contains('production')) {
    stderr.writeln('⛔ [CRITICAL SAFETY GUARD] Cannot run seed script against a production project ($projectId).');
    exit(1);
  }

  final db = FirebaseFirestore.instance;

  // Resolve Firm ID if not provided: pick the first firm in the database
  if (firmId == null || firmId.isEmpty) {
    stdout.writeln('No --firmId provided. Looking up available firms...');
    final firmsSnap = await db.collection('Firms').limit(1).get();
    if (firmsSnap.docs.isEmpty) {
      stderr.writeln('No firms found in database. Create a firm first.');
      exit(1);
    }
    firmId = firmsSnap.docs.first.id;
    stdout.writeln('Selected Firm ID: $firmId (${firmsSnap.docs.first.data()['name']})');
  }

  stdout.writeln('\n🚀 Starting Dashboard Data Seeding for Firm: $firmId...\n');

  final firmRef = db.collection('Firms').doc(firmId);
  final membersCol = firmRef.collection('members');
  final preApprovedCol = firmRef.collection('PreApprovedStaff');
  final deptsCol = firmRef.collection('departments');
  final projectsCol = firmRef.collection('projects');
  final auditCol = firmRef.collection('audit');
  final noticesCol = firmRef.collection('notices');
  final noticeIndexCol = firmRef.collection('noticeIndex');

  final now = DateTime.now();

  // 1. Seed 6 Departments
  stdout.writeln('📁 Seeding 6 Departments...');
  final deptData = [
    {'id': 'dept_eng', 'name': 'Engineering', 'headUid': 'staff_lead_eng', 'status': 'active'},
    {'id': 'dept_prod', 'name': 'Product & Design', 'headUid': 'staff_lead_prod', 'status': 'active'},
    {'id': 'dept_sales', 'name': 'Sales & Growth', 'headUid': 'staff_lead_sales', 'status': 'active'},
    {'id': 'dept_ops', 'name': 'Operations', 'headUid': 'staff_lead_ops', 'status': 'active'},
    {'id': 'dept_legal', 'name': 'Legal & Compliance', 'headUid': null, 'status': 'active'}, // No Head
    {'id': 'dept_qa', 'name': 'Quality Assurance', 'headUid': 'staff_lead_qa', 'status': 'active'}, // 0 Staff
  ];

  for (final d in deptData) {
    await deptsCol.doc(d['id'] as String).set({
      'name': d['name'],
      'headUid': d['headUid'],
      'status': d['status'],
      'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 90))),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  // 2. Seed Active Members (~85 members across 10 weeks)
  stdout.writeln('👥 Seeding Active Members across 10 weeks...');
  final activeDepts = ['dept_eng', 'dept_prod', 'dept_sales', 'dept_ops'];
  int memberCounter = 0;

  for (int week = 9; week >= 0; week--) {
    // Distribute 8-10 members per week
    final membersThisWeek = (week == 0) ? 6 : 8;
    for (int j = 0; j < membersThisWeek; j++) {
      memberCounter++;
      final uid = 'member_$memberCounter';
      final joinDate = now.subtract(Duration(days: (week * 7) + (j % 5)));

      // Department assignment: 5 members are unassigned
      final deptId = (memberCounter <= 5) ? null : activeDepts[memberCounter % activeDepts.length];

      // Role assignment: 3 admins, 5 leads, rest employees
      String role = 'employee';
      if (memberCounter <= 3) {
        role = 'admin';
      } else if (memberCounter <= 8) {
        role = 'lead';
      }

      await membersCol.doc(uid).set({
        'uid': uid,
        'firmId': firmId,
        'name': 'Staff Member $memberCounter',
        'email': 'staff$memberCounter@demo-firm.com',
        'role': role,
        'status': 'active',
        'departmentId': deptId,
        'joinedAt': Timestamp.fromDate(joinDate),
      }, SetOptions(merge: true));
    }
  }

  // Assign designated head uids
  await membersCol.doc('staff_lead_eng').set({
    'uid': 'staff_lead_eng',
    'firmId': firmId,
    'name': 'Alex Rivera (Lead)',
    'email': 'alex.rivera@demo-firm.com',
    'role': 'lead',
    'status': 'active',
    'departmentId': 'dept_eng',
    'joinedAt': Timestamp.fromDate(now.subtract(const Duration(days: 60))),
  }, SetOptions(merge: true));

  // 3. Seed Revoked Members (8 members)
  stdout.writeln('🚫 Seeding Revoked Members...');
  for (int r = 1; r <= 8; r++) {
    final uid = 'revoked_member_$r';
    await membersCol.doc(uid).set({
      'uid': uid,
      'firmId': firmId,
      'name': 'Former Employee $r',
      'email': 'former$r@demo-firm.com',
      'role': 'employee',
      'status': 'revoked',
      'departmentId': 'dept_eng',
      'joinedAt': Timestamp.fromDate(now.subtract(const Duration(days: 120))),
      'revokedAt': Timestamp.fromDate(now.subtract(Duration(days: r * 4))),
    }, SetOptions(merge: true));
  }

  // 4. Seed Pre-Approved Staff Invites (25 invites)
  stdout.writeln('✉️ Seeding Pre-Approved Staff Invites for Funnel...');
  // 10 Joined
  for (int i = 1; i <= 10; i++) {
    await preApprovedCol.doc('invite_joined_$i').set({
      'email': 'onboarded$i@demo-firm.com',
      'status': 'joined',
      'invitedAt': Timestamp.fromDate(now.subtract(Duration(days: i * 3))),
      'codeExpiresAt': Timestamp.fromDate(now.subtract(Duration(days: (i * 3) - 1))),
    });
  }

  // 8 Invited & Valid
  for (int i = 1; i <= 8; i++) {
    await preApprovedCol.doc('invite_valid_$i').set({
      'email': 'candidate$i@demo-firm.com',
      'status': 'invited',
      'invitedAt': Timestamp.fromDate(now.subtract(Duration(days: i))),
      'codeExpiresAt': Timestamp.fromDate(now.add(Duration(days: 2 + i))),
    });
  }

  // 4 Expired
  for (int i = 1; i <= 4; i++) {
    await preApprovedCol.doc('invite_expired_$i').set({
      'email': 'expired$i@demo-firm.com',
      'status': 'invited',
      'invitedAt': Timestamp.fromDate(now.subtract(Duration(days: 10 + i))),
      'codeExpiresAt': Timestamp.fromDate(now.subtract(Duration(days: i))),
    });
  }

  // 2 Expiring within 5 minutes (Needs Attention)
  for (int i = 1; i <= 2; i++) {
    await preApprovedCol.doc('invite_expiring_soon_$i').set({
      'email': 'expiring.soon$i@demo-firm.com',
      'status': 'invited',
      'invitedAt': Timestamp.fromDate(now.subtract(const Duration(hours: 47))),
      'codeExpiresAt': Timestamp.fromDate(now.add(Duration(minutes: i * 2))),
    });
  }

  // 1 Stale Invite (>7 days) (Needs Attention)
  await preApprovedCol.doc('invite_stale_1').set({
    'email': 'stale.candidate@demo-firm.com',
    'status': 'invited',
    'invitedAt': Timestamp.fromDate(now.subtract(const Duration(days: 14))),
    'codeExpiresAt': Timestamp.fromDate(now.add(const Duration(days: 1))),
  });

  // 5. Seed Project with Revoked Owner (Needs Attention)
  stdout.writeln('🔒 Seeding Project Group with Revoked Owner...');
  await projectsCol.doc('proj_legacy_alpha').set({
    'name': 'Alpha Migration 2026',
    'ownerUid': 'revoked_member_1',
    'status': 'active',
    'memberCount': 6,
    'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 45))),
  }, SetOptions(merge: true));

  // 6. Seed Policy Notice & Acknowledgment Rate
  stdout.writeln('📜 Seeding Policy Notice & Acknowledgements...');
  const policyNoticeId = 'notice_policy_security_2026';
  await noticeIndexCol.doc(policyNoticeId).set({
    'title': 'Information Security & Device Policy 2026',
    'type': 'policy',
    'status': 'published',
    'authorName': 'Compliance Team',
    'version': 1,
    'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 5))),
  });

  // Seed 55 acknowledgements out of 85 active members (~65%)
  for (int a = 1; a <= 55; a++) {
    await noticesCol
        .doc(policyNoticeId)
        .collection('acks')
        .doc('member_$a')
        .set({
      'uid': 'member_$a',
      'version': 1,
      'acknowledgedAt': Timestamp.fromDate(now.subtract(Duration(hours: a))),
    });
  }

  // 1 Urgent Notice
  await noticeIndexCol.doc('notice_urgent_office_update').set({
    'title': 'Scheduled Network Maintenance Tonight',
    'type': 'urgent',
    'status': 'published',
    'authorName': 'IT Infrastructure',
    'version': 1,
    'createdAt': Timestamp.fromDate(now.subtract(const Duration(hours: 4))),
  });

  // 7. Seed 10 Recent Admin Activity Audit Entries
  stdout.writeln('📝 Seeding 10 Audit Log Entries...');
  final auditEvents = [
    'Updated firm security policy: Device encryption required',
    'Created department channel: Quality Assurance',
    'Invited 5 new staff members via CSV bulk upload',
    'Assigned Alex Rivera as Engineering Department Head',
    'Published urgent notice: Scheduled Network Maintenance',
    'Revoked access for Former Employee 1',
    'Modified Trial seat cap to 150',
    'Generated join link with 48h expiration',
    'Archived department: Legacy Product v1',
    'Exported onboarding compliance roster',
  ];

  for (int e = 0; e < auditEvents.length; e++) {
    await auditCol.add({
      'action': 'admin_action_${e + 1}',
      'description': auditEvents[e],
      'actorUid': 'admin_user_main',
      'createdAt': Timestamp.fromDate(now.subtract(Duration(hours: (e * 6) + 1))),
    });
  }

  // 8. Update Firm Seat Count
  await firmRef.update({
    'seatCount': memberCounter,
    'seatLimit': 150,
  });

  stdout.writeln('\n✅ Seeding complete! Dashboard now contains realistic data across all metrics.');
  exit(0);
}
