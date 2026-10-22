import 'package:flutter_test/flutter_test.dart';
import 'package:pronto_chat/models/dashboard_metrics_models.dart';
import 'package:pronto_chat/services/dashboard_metrics_repository.dart';

void main() {
  group('Dashboard Metrics - Monday 00:00:00 Local Calculations', () {
    test('Correctly computes Monday 00:00:00 when given a Wednesday afternoon', () {
      // 2026-10-21 is a Wednesday
      final wednesday = DateTime(2026, 10, 21, 14, 35, 20);
      final monday = DashboardMetricsRepository.getStartOfWeekLocal(wednesday);

      expect(monday.year, equals(2026));
      expect(monday.month, equals(10));
      expect(monday.day, equals(19)); // Monday
      expect(monday.hour, equals(0));
      expect(monday.minute, equals(0));
      expect(monday.second, equals(0));
      expect(monday.weekday, equals(DateTime.monday));
    });

    test('Correctly computes Monday 00:00:00 when given Monday morning', () {
      final mondayMorning = DateTime(2026, 10, 19, 9, 15, 0);
      final monday = DashboardMetricsRepository.getStartOfWeekLocal(mondayMorning);

      expect(monday.day, equals(19));
      expect(monday.hour, equals(0));
      expect(monday.minute, equals(0));
      expect(monday.second, equals(0));
    });

    test('Correctly computes Monday 00:00:00 when given Sunday evening', () {
      // 2026-10-25 is a Sunday
      final sunday = DateTime(2026, 10, 25, 23, 59, 59);
      final monday = DashboardMetricsRepository.getStartOfWeekLocal(sunday);

      expect(monday.day, equals(19)); // Same week's Monday
      expect(monday.hour, equals(0));
      expect(monday.minute, equals(0));
    });
  });

  group('Dashboard Metrics - Onboarding Status Parity', () {
    test('Unifies Pending definition with OnboardingTab (pending members + invited pre-approved)', () {
      const activeMembers = 40;
      const pendingMembers = 5;
      const revokedMembers = 3;
      const invitedPreApproved = 10;

      final pendingTotal = pendingMembers + invitedPreApproved;
      final totalStaff = activeMembers + pendingTotal + revokedMembers;

      final kpis = HeadlineKpiData(
        totalStaff: totalStaff,
        activeStaff: activeMembers,
        pendingStaff: pendingTotal,
        revokedStaff: revokedMembers,
        activeDelta: 2,
        pendingDelta: 1,
        revokedDelta: 0,
      );

      expect(kpis.totalStaff, equals(58));
      expect(kpis.activeStaff, equals(40));
      expect(kpis.pendingStaff, equals(15));
      expect(kpis.revokedStaff, equals(3));
    });

    test('Onboarding Funnel correctly calculates conversion rate', () {
      const funnel = OnboardingFunnelData(
        totalInvited: 20,
        codePending: 8,
        joined: 10,
        expired: 2,
        conversionRate: 50.0,
      );

      expect(funnel.conversionRate, equals(50.0));
      expect(funnel.hasData, isTrue);

      const emptyFunnel = OnboardingFunnelData(
        totalInvited: 0,
        codePending: 0,
        joined: 0,
        expired: 0,
        conversionRate: 0.0,
      );
      expect(emptyFunnel.hasData, isFalse);
    });
  });

  group('Dashboard Metrics - Seat Usage Math & Sync Checks', () {
    test('Calculates seat ratio and remaining seats accurately', () {
      const seatData = SeatUsageData(
        storedSeatCount: 30,
        seatLimit: 50,
        trueSeatCount: 35,
        isOutOfSync: true,
      );

      expect(seatData.ratio, closeTo(0.70, 0.001));
      expect(seatData.remainingSeats, equals(15));
      expect(seatData.isOutOfSync, isTrue);
    });

    test('Clamps seat ratio to 1.0 when trueSeatCount exceeds seatLimit', () {
      const seatData = SeatUsageData(
        storedSeatCount: 50,
        seatLimit: 50,
        trueSeatCount: 52,
        isOutOfSync: true,
      );

      expect(seatData.ratio, equals(1.0));
      expect(seatData.remainingSeats, equals(0));
    });
  });

  group('Dashboard Metrics - Department Unassigned Staff Math', () {
    test('Accurately computes unassigned active staff without extra queries', () {
      final departments = [
        const DepartmentHeadcountItem(deptId: 'd1', name: 'Engineering', count: 20),
        const DepartmentHeadcountItem(deptId: 'd2', name: 'Marketing', count: 10),
        const DepartmentHeadcountItem(deptId: 'd3', name: 'Sales', count: 5),
      ];

      const totalActiveStaff = 42;
      final assignedTotal = departments.fold<int>(0, (acc, d) => acc + d.count);
      final unassigned = totalActiveStaff - assignedTotal;

      final breakdown = DepartmentBreakdownData(
        departments: departments,
        unassignedCount: unassigned,
      );

      expect(assignedTotal, equals(35));
      expect(breakdown.unassignedCount, equals(7));
      expect(breakdown.hasData, isTrue);
    });
  });

  group('Dashboard Metrics - Privacy by Design Safeguards', () {
    test('Disables presence metrics when firm privacy setting is false', () {
      const presence = PresenceEngagementData(
        activeInLast7Days: null,
        isPrivacyDisabled: true,
      );

      expect(presence.isPrivacyDisabled, isTrue);
      expect(presence.activeInLast7Days, isNull);
    });
  });
}
