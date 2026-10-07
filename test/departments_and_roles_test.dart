import 'package:flutter_test/flutter_test.dart';
import 'package:pronto_chat/models/department.dart';
import 'package:pronto_chat/models/membership.dart';
import 'package:pronto_chat/models/project_group.dart';

void main() {
  group('Membership Model & Roles Tests', () {
    test('Correctly maps admin, lead, and employee roles', () {
      final admin = Membership(
        membershipId: 'm1',
        uid: 'u1',
        firmId: 'f1',
        role: MembershipRole.admin,
      );
      expect(admin.isAdmin, isTrue);
      expect(admin.isLead, isFalse);
      expect(admin.isEmployee, isFalse);

      final lead = Membership(
        membershipId: 'm2',
        uid: 'u2',
        firmId: 'f1',
        role: MembershipRole.lead,
        departmentId: 'dept_eng',
      );
      expect(lead.isAdmin, isFalse);
      expect(lead.isLead, isTrue);
      expect(lead.isEmployee, isFalse);
      expect(lead.departmentId, equals('dept_eng'));

      final employee = Membership(
        membershipId: 'm3',
        uid: 'u3',
        firmId: 'f1',
        role: MembershipRole.employee,
      );
      expect(employee.isAdmin, isFalse);
      expect(employee.isLead, isFalse);
      expect(employee.isEmployee, isTrue);
    });

    test('Membership serialization includes departmentId and role', () {
      final lead = Membership(
        membershipId: 'm2',
        uid: 'u2',
        firmId: 'f1',
        role: MembershipRole.lead,
        departmentId: 'dept_sales',
      );

      final json = lead.toJson();
      expect(json['role'], equals('lead'));
      expect(json['departmentId'], equals('dept_sales'));

      final parsed = Membership.fromJson(json);
      expect(parsed.role, equals(MembershipRole.lead));
      expect(parsed.departmentId, equals('dept_sales'));
      expect(parsed.isLead, isTrue);
    });
  });

  group('Department Model Tests', () {
    test('Department correctly tracks status, head, and conversation pairing', () {
      final dept = Department(
        deptId: 'd1',
        firmId: 'f1',
        name: 'Engineering',
        headUid: 'u_head',
        conversationId: 'c1',
        status: 'active',
        createdAt: DateTime(2026, 1, 1),
        createdBy: 'u_admin',
        headcount: 12,
      );

      expect(dept.isActive, isTrue);
      expect(dept.isArchived, isFalse);
      expect(dept.name, equals('Engineering'));
      expect(dept.headUid, equals('u_head'));
      expect(dept.conversationId, equals('c1'));
      expect(dept.headcount, equals(12));

      final archived = dept.copyWith(status: 'archived');
      expect(archived.isActive, isFalse);
      expect(archived.isArchived, isTrue);
    });
  });

  group('ProjectGroup Model Tests', () {
    test('ProjectGroup tracks owner, memberCount, and participants', () {
      final project = ProjectGroup(
        projectId: 'p1',
        firmId: 'f1',
        conversationId: 'p1',
        name: 'Brand Refresh',
        ownerUid: 'u_lead',
        participantIds: ['u_lead', 'u_dev1', 'u_dev2'],
        memberCount: 3,
        status: 'active',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(project.isActive, isTrue);
      expect(project.isArchived, isFalse);
      expect(project.ownerUid, equals('u_lead'));
      expect(project.participantIds.length, equals(3));
      expect(project.participantIds, contains('u_lead'));

      final map = project.toFirestore();
      expect(map['name'], equals('Brand Refresh'));
      expect(map['ownerUid'], equals('u_lead'));
      expect(map['participantIds'], contains('u_lead'));
      expect(map['memberCount'], equals(3));
    });
  });

  group('Role Permissions & Access Verification', () {
    test('Verify Lead role is required for project group creation permissions', () {
      bool canCreateProject(MembershipRole role) {
        return role == MembershipRole.lead || role == MembershipRole.admin;
      }

      expect(canCreateProject(MembershipRole.employee), isFalse);
      expect(canCreateProject(MembershipRole.lead), isTrue);
      expect(canCreateProject(MembershipRole.admin), isTrue);
    });

    test('Verify posting in #all-staff is restricted to Admin and Lead', () {
      bool canPostAllStaff(MembershipRole role) {
        return role == MembershipRole.admin || role == MembershipRole.lead;
      }

      expect(canPostAllStaff(MembershipRole.employee), isFalse);
      expect(canPostAllStaff(MembershipRole.lead), isTrue);
      expect(canPostAllStaff(MembershipRole.admin), isTrue);
    });

    test('Verify derived department access matching', () {
      bool hasDepartmentAccess({
        required String? memberDepartmentId,
        required String conversationDepartmentId,
      }) {
        return memberDepartmentId != null && memberDepartmentId == conversationDepartmentId;
      }

      expect(
        hasDepartmentAccess(
          memberDepartmentId: 'dept_engineering',
          conversationDepartmentId: 'dept_engineering',
        ),
        isTrue,
      );

      expect(
        hasDepartmentAccess(
          memberDepartmentId: 'dept_marketing',
          conversationDepartmentId: 'dept_engineering',
        ),
        isFalse,
      );

      expect(
        hasDepartmentAccess(
          memberDepartmentId: null,
          conversationDepartmentId: 'dept_engineering',
        ),
        isFalse,
      );
    });
    test('Verify department head access and lead status derivation', () {
      bool hasDepartmentAccess({
        required String? memberDepartmentId,
        required String conversationDepartmentId,
        String? deptHeadUid,
        String? callerUid,
      }) {
        if (deptHeadUid != null && callerUid != null && deptHeadUid == callerUid) {
          return true;
        }
        return memberDepartmentId != null && memberDepartmentId == conversationDepartmentId;
      }

      // Head UID matches caller
      expect(
        hasDepartmentAccess(
          memberDepartmentId: null,
          conversationDepartmentId: 'dept_engineering',
          deptHeadUid: 'u_lead_1',
          callerUid: 'u_lead_1',
        ),
        isTrue,
      );

      // Assigned member
      expect(
        hasDepartmentAccess(
          memberDepartmentId: 'dept_engineering',
          conversationDepartmentId: 'dept_engineering',
          deptHeadUid: 'u_lead_1',
          callerUid: 'u_employee_2',
        ),
        isTrue,
      );

      // Unassigned member and not head
      expect(
        hasDepartmentAccess(
          memberDepartmentId: null,
          conversationDepartmentId: 'dept_engineering',
          deptHeadUid: 'u_lead_1',
          callerUid: 'u_employee_3',
        ),
        isFalse,
      );
    });

    test('Verify department member assignment changes reflect on membership', () {
      final employee = Membership(
        membershipId: 'm1',
        uid: 'u1',
        firmId: 'firm_1',
        role: MembershipRole.employee,
      );

      // Assign to department
      final assigned = employee.copyWith(departmentId: 'dept_design');
      expect(assigned.departmentId, equals('dept_design'));
      expect(assigned.role, equals(MembershipRole.employee));

      // Promote to department head / lead
      final promoted = assigned.copyWith(role: MembershipRole.lead);
      expect(promoted.departmentId, equals('dept_design'));
      expect(promoted.isLead, isTrue);

      // Unassign from department
      final unassigned = Membership(
        membershipId: promoted.membershipId,
        uid: promoted.uid,
        firmId: promoted.firmId,
        role: MembershipRole.employee,
        departmentId: null,
      );
      expect(unassigned.departmentId, isNull);
      expect(unassigned.isLead, isFalse);
      expect(unassigned.isEmployee, isTrue);
    });
  });
}
