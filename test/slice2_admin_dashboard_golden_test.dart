import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pronto_chat/models/audit_entry.dart';
import 'package:pronto_chat/models/dashboard_metrics_models.dart';
import 'package:pronto_chat/models/firm.dart';
import 'package:pronto_chat/providers/dashboard/dashboard_providers.dart';
import 'package:pronto_chat/providers/firm/providers.dart';
import 'package:pronto_chat/screens/admin/admin_shell.dart';
import 'package:pronto_chat/screens/admin/tabs/customization_tab.dart';
import 'package:pronto_chat/screens/admin/tabs/dashboard_tab.dart';
import 'package:pronto_chat/theme/admin_theme_provider.dart';
import 'package:pronto_chat/theme/admin_theme_storage.dart';
import 'package:pronto_chat/theme/pc_tokens.dart';
import 'package:pronto_chat/theme/pronto_tokens.dart';

class _StubDashboardMetricsNotifier extends DashboardMetricsNotifier {
  _StubDashboardMetricsNotifier(super.ref, DashboardBundle initialBundle) {
    state = AsyncValue.data(initialBundle);
  }

  void setBundle(DashboardBundle bundle) {
    state = AsyncValue.data(bundle);
  }

  @override
  Future<void> loadDashboard({bool force = false}) async {}

  @override
  Future<bool> refreshDashboard({bool force = false}) async => true;
}

Future<void> _loadAllSdkFonts() async {
  const fontDir =
      r'C:\Users\cyrus\flutter\flutter\bin\cache\artifacts\material_fonts';
  final dir = Directory(fontDir);
  if (!dir.existsSync()) return;

  Future<ByteData> readFont(String file) async {
    final bytes = await File('$fontDir\\$file').readAsBytes();
    return ByteData.sublistView(bytes);
  }

  for (final family in [
    'Roboto',
    '.SF Pro Text',
    '.SF UI Text',
    'Ahem',
    'packages/flutter_test/Ahem',
  ]) {
    final loader = FontLoader(family)
      ..addFont(readFont('roboto-thin.ttf'))
      ..addFont(readFont('roboto-light.ttf'))
      ..addFont(readFont('roboto-regular.ttf'))
      ..addFont(readFont('roboto-medium.ttf'))
      ..addFont(readFont('roboto-bold.ttf'))
      ..addFont(readFont('roboto-black.ttf'))
      ..addFont(readFont('roboto-italic.ttf'))
      ..addFont(readFont('roboto-bolditalic.ttf'));
    await loader.load();
  }

  final icons = FontLoader('MaterialIcons')
    ..addFont(readFont('materialicons-regular.otf'));
  await icons.load();
}

DashboardBundle _buildPopulatedBundle() {
  final baseDate = DateTime(2026, 11, 2);
  return DashboardBundle(
    headlineKpis: const HeadlineKpiData(
      totalStaff: 18,
      activeStaff: 14,
      pendingStaff: 3,
      revokedStaff: 1,
      activeDelta: 0, // Exercises "No change this week" + tooltip check
      pendingDelta: 2,
      revokedDelta: 0,
    ),
    seatUsage: const SeatUsageData(
      storedSeatCount: 15,
      seatLimit: 25,
      trueSeatCount: 17,
      isOutOfSync: true, // Must be logged via debugPrint, NEVER shown in UI!
    ),
    funnel: const OnboardingFunnelData(
      totalInvited: 20,
      codePending: 3,
      joined: 14,
      expired: 3,
      conversionRate: 70.0,
    ),
    departmentBreakdown: const DepartmentBreakdownData(
      departments: [
        DepartmentHeadcountItem(deptId: 'd1', name: 'Corporate Law', count: 5),
        DepartmentHeadcountItem(deptId: 'd2', name: 'Litigation', count: 4),
        DepartmentHeadcountItem(deptId: 'd3', name: 'Compliance', count: 3),
        DepartmentHeadcountItem(deptId: 'd4', name: 'Operations', count: 2),
      ],
      unassignedCount: 0,
    ),
    roleDistribution: const RoleDistributionData(
      adminCount: 2,
      leadCount: 3,
      employeeCount: 9,
    ),
    joinsOverTime: JoinsOverTimeData(
      requestedWeeks: 8,
      weeklyBuckets: List.generate(8, (i) {
        const counts = [1, 2, 1, 3, 2, 4, 2, 3];
        final start = baseDate.add(Duration(days: i * 7));
        return WeeklyJoinBucket(
          weekStart: start,
          weekEnd: start.add(const Duration(days: 6)),
          count: counts[i],
        );
      }),
      excludedNoJoinDateCount: 1,
    ),
    groupsOverview: const GroupsOverviewData(
      activeDepartments: 4,
      archivedDepartments: 1,
      activeProjects: 6,
      archivedProjects: 2,
    ),
    needsAttention: const [
      NeedsAttentionItem(
        id: 'na1',
        title: '3 staff invites expiring within 48h',
        subtitle: 'Resend or extend 6-digit onboarding codes',
        type: NeedsAttentionType.expiringCode,
        route: '/admin/onboarding?filter=pending',
      ),
      NeedsAttentionItem(
        id: 'na2',
        title: 'Compliance channel has no assigned Lead',
        subtitle: 'Assign a department lead for notice moderation',
        type: NeedsAttentionType.departmentNoHead,
        route: '/admin/notices?sub=departments',
      ),
    ],
    noticesOversight: const NoticesOversightData(
      publishedCount: 9,
      urgentCount: 1,
      policyCount: 3,
      latestPolicyNoticeId: 'pol_2026_q4',
      latestPolicyAuthor: 'Sarah Chen',
      latestPolicyVersion: 2,
      latestPolicyAckRate: 85.7,
      latestPolicyAckCount: 12,
      activeMembersCount: 14,
    ),
    presenceEngagement: const PresenceEngagementData(
      activeInLast7Days: 13,
      isPrivacyDisabled: false,
    ),
    recentActivity: [
      AuditEntry(
        id: 'a1',
        actorId: 'u_admin',
        actorName: 'Sarah Chen',
        action: 'department_created',
        targetType: 'department',
        targetId: 'd3',
        targetLabel: 'Compliance',
        createdAt: DateTime(2026, 11, 24),
      ),
      AuditEntry(
        id: 'a2',
        actorId: 'u_admin',
        actorName: 'Sarah Chen',
        action: 'staff_added',
        targetType: 'staff',
        targetId: 's9',
        targetLabel: 'Marcus Vance',
        createdAt: DateTime(2026, 11, 23),
      ),
    ],
    lastFetched: DateTime.now(),
  );
}

DashboardBundle _buildZeroDataBundle() {
  final baseDate = DateTime(2026, 11, 2);
  return DashboardBundle(
    headlineKpis: const HeadlineKpiData.empty(),
    seatUsage: const SeatUsageData(
      storedSeatCount: 1,
      seatLimit: 5,
      trueSeatCount: 1,
      isOutOfSync: false,
    ),
    funnel: const OnboardingFunnelData(
      totalInvited: 0,
      codePending: 0,
      joined: 0,
      expired: 0,
      conversionRate: 0.0,
    ),
    departmentBreakdown: const DepartmentBreakdownData(
      departments: [],
      unassignedCount: 0,
    ),
    roleDistribution: const RoleDistributionData(
      adminCount: 1,
      leadCount: 0,
      employeeCount: 0,
    ),
    joinsOverTime: JoinsOverTimeData(
      requestedWeeks: 8,
      weeklyBuckets: List.generate(8, (i) {
        final start = baseDate.add(Duration(days: i * 7));
        return WeeklyJoinBucket(
          weekStart: start,
          weekEnd: start.add(const Duration(days: 6)),
          count: 0,
        );
      }),
      excludedNoJoinDateCount: 0,
    ),
    groupsOverview: const GroupsOverviewData(
      activeDepartments: 0,
      archivedDepartments: 0,
      activeProjects: 0,
      archivedProjects: 0,
    ),
    needsAttention: const [],
    noticesOversight: const NoticesOversightData(
      publishedCount: 0,
      urgentCount: 0,
      policyCount: 0,
    ),
    presenceEngagement: const PresenceEngagementData(
      activeInLast7Days: 1,
      isPrivacyDisabled: false,
    ),
    recentActivity: const [],
    lastFetched: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
    await _loadAllSdkFonts();

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const mockedPigeonChannels = [
      'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.registerIdTokenListener',
      'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.registerAuthStateListener',
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceSnapshot',
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.querySnapshot',
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceGet',
    ];
    for (final ch in mockedPigeonChannels) {
      messenger.setMockMessageHandler(
        ch,
        (_) => Completer<ByteData?>().future,
      );
    }
  });

  testWidgets(
      'Slice 2: Admin Dashboard across 5 themes x Light/Dark x 1920x1080 & 900x1080 + defect & empty-state checks',
      (WidgetTester tester) async {
    AdminThemeStorage.writeCachedAccentHex('#00C853');
    AdminThemeStorage.writeCachedThemeId('calm');
    AdminThemeStorage.writeDarkMode(false);

    // Firm without logo so the Setup Checklist renders on Dashboard (verifying checklist title & last item!)
    final sampleFirm = Firm(
      firmId: 'apex_legal',
      name: 'Apex Legal Partners',
      primaryColor: '#00C853',
      themeId: 'calm',
      seatLimit: 25,
      seatCount: 15,
      createdAt: DateTime(2026, 6, 15),
    );

    final logs = <String>[];
    final origDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };

    late _StubDashboardMetricsNotifier stubNotifier;
    final populatedBundle = _buildPopulatedBundle();

    final router = GoRouter(
      initialLocation: '/admin/dashboard',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AdminShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/dashboard',
                  builder: (_, _) => const DashboardTab(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/onboarding',
                  builder: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/notices',
                  builder: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/brand',
                  builder: (_, _) => const CustomizationTab(),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        currentFirmProvider.overrideWithValue(sampleFirm),
        dashboardMetricsProvider.overrideWith((ref) {
          stubNotifier = _StubDashboardMetricsNotifier(ref, populatedBundle);
          return stubNotifier;
        }),
      ],
    );
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: PcThemeBuilder.buildLightTheme(
            primaryColor: const Color(0xFF00C853),
          ),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // DEFECT CHECK 1: Out-of-sync seat counter is logged internally and NEVER shown in UI
    debugPrint = origDebugPrint;
    expect(find.textContaining('Live aggregate'), findsNothing);
    expect(find.textContaining('differs from firm counter'), findsNothing);
    expect(
      logs.any((l) => l.contains('[SeatUsageMeter] Live aggregate')),
      isTrue,
    );

    // DEFECT CHECK 2: Checklist title and last item are visible
    expect(find.text('Firm Setup Checklist'), findsOneWidget);
    expect(find.text('Invite Team Members or Import CSV'), findsOneWidget);

    // DEFECT CHECK 3: Hovering MetricCard header shows Tooltip ABOVE without overlapping "No change this week"
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('Active Staff')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final tooltipFinder = find.text('View Active Staff in Onboarding');
    expect(tooltipFinder, findsOneWidget);
    final tooltipRect = tester.getRect(tooltipFinder);
    final noChangeRect = tester.getRect(find.text('No change this week').first);
    expect(
      tooltipRect.overlaps(noChangeRect),
      isFalse,
      reason: 'MetricCard tooltip must never overlap "No change this week"',
    );
    await gesture.moveTo(const Offset(1915, 1075));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    Future<void> scrollDashboardTo(double offset) async {
      final states = tester.stateList<ScrollableState>(find.byType(Scrollable));
      for (final st in states) {
        if (st.widget.axisDirection == AxisDirection.down &&
            st.position.maxScrollExtent > 0) {
          st.position.jumpTo(offset.clamp(0.0, st.position.maxScrollExtent));
        }
      }
      await tester.pumpAndSettle();
    }

    // 1. 1920x1080 Light Mode — All 5 Harmonies
    for (final theme in ProntoThemeId.values) {
      container.read(adminThemeControllerProvider.notifier).stageThemeId(theme);
      await scrollDashboardTo(0);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/slice2/light_1920_${theme.id}.png'),
      );
    }

    // Also capture lower dashboard charts & panels @ 1920x1080 Light (Playful)
    await scrollDashboardTo(600);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/slice2/lower_light_1920_playful.png'),
    );

    // 2. 1920x1080 Dark Mode — All 5 Harmonies
    container.read(adminThemeControllerProvider.notifier).setDarkMode(true);
    await tester.pumpAndSettle();

    for (final theme in ProntoThemeId.values) {
      container.read(adminThemeControllerProvider.notifier).stageThemeId(theme);
      await scrollDashboardTo(0);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/slice2/dark_1920_${theme.id}.png'),
      );
    }

    // Capture lower dashboard charts & panels @ 1920x1080 Dark (Contrast)
    container
        .read(adminThemeControllerProvider.notifier)
        .stageThemeId(ProntoThemeId.contrast);
    await scrollDashboardTo(600);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/slice2/lower_dark_1920_contrast.png'),
    );

    // 3. Narrow ~900px (900x1080) Dark Mode — All 5 Harmonies
    tester.view.physicalSize = const Size(900, 1080);
    await tester.pumpAndSettle();

    for (final theme in ProntoThemeId.values) {
      container.read(adminThemeControllerProvider.notifier).stageThemeId(theme);
      await scrollDashboardTo(0);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/slice2/dark_900_${theme.id}.png'),
      );
    }

    // 4. Narrow ~900px (900x1080) Light Mode — All 5 Harmonies
    container.read(adminThemeControllerProvider.notifier).setDarkMode(false);
    await tester.pumpAndSettle();

    for (final theme in ProntoThemeId.values) {
      container.read(adminThemeControllerProvider.notifier).stageThemeId(theme);
      await scrollDashboardTo(0);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/slice2/light_900_${theme.id}.png'),
      );
    }

    // 5. Friendly Zero-Data Empty States (Total Staff == 0, Funnel empty, Departments empty)
    stubNotifier.setBundle(_buildZeroDataBundle());
    container
        .read(adminThemeControllerProvider.notifier)
        .stageThemeId(ProntoThemeId.harmony);
    tester.view.physicalSize = const Size(1920, 1080);
    await tester.pumpAndSettle();
    await scrollDashboardTo(0);

    expect(find.text('No staff yet • Invite team'), findsOneWidget);
    expect(find.text('No onboarding invites yet'), findsOneWidget);
    expect(find.text('No department headcounts yet'), findsOneWidget);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/slice2/empty_light_1920_harmony.png'),
    );

    container.read(adminThemeControllerProvider.notifier).setDarkMode(true);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/slice2/empty_dark_1920_harmony.png'),
    );
  });
}
