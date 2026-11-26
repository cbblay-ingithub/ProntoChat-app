import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/department.dart';
import '../../../models/firm.dart';
import '../../../models/membership.dart';
import '../../../models/notice_index_model.dart';
import '../../../models/notice_model.dart';
import '../../../models/project_group.dart';
import '../../../models/user.dart';
import '../../../providers/firm/providers.dart';
import '../../../screens/notices/notice_composer_screen.dart';
import '../../../services/audit_service.dart';
import '../../../services/db_service.dart';
import '../../../services/notices_service.dart';
import '../../../services/snackbar_service.dart';
import '../../../theme/pc_tokens.dart';

class NoticesGroupsTab extends ConsumerStatefulWidget {
  final int initialSubTabIndex;

  const NoticesGroupsTab({
    super.key,
    this.initialSubTabIndex = 0,
  });

  @override
  ConsumerState<NoticesGroupsTab> createState() => _NoticesGroupsTabState();
}

class _NoticesGroupsTabState extends ConsumerState<NoticesGroupsTab>
    with SingleTickerProviderStateMixin {
  static const Color _emerald = Color(0xFF059669);

  late TabController _tabController;

  String _noticeStatusFilter = 'all';
  NoticeType? _noticeTypeFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialSubTabIndex.clamp(0, 2),
    );
  }

  @override
  void didUpdateWidget(covariant NoticesGroupsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSubTabIndex != oldWidget.initialSubTabIndex) {
      _tabController.animateTo(widget.initialSubTabIndex.clamp(0, 2));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _hexToColor(
    String hexString, [
    Color fallback = PcTokens.defaultBrandBlue,
  ]) {
    try {
      String clean = hexString.toUpperCase().replaceAll('#', '');
      if (clean.length == 6) clean = 'FF$clean';
      if (clean.length == 8) {
        final val = int.tryParse(clean, radix: 16);
        if (val != null) return Color(val);
      }
    } catch (_) {}
    return fallback;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  Widget _styledDropdown<T>({
    required PcTokens tokens,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? label,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: tokens.surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.border),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: tokens.surface,
          style: TextStyle(color: tokens.textPrimary, fontSize: 13.5),
          icon: Icon(Icons.arrow_drop_down, color: tokens.textSecondary),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pcTokens;
    final firm = ref.watch(currentFirmProvider);
    if (firm == null) {
      return Center(child: CircularProgressIndicator(color: tokens.primary));
    }

    final activeAccent =
        PcTokens.readableAccentOnLight(_hexToColor(firm.primaryColor));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: tokens.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.all(isMobile ? 16 : 20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: activeAccent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.hub_outlined,
                                  color: activeAccent,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Notices & Groups Management',
                                      style: TextStyle(
                                        color: tokens.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Govern official firm notices, oversee department teams, and monitor cross-functional project groups.',
                                      style: TextStyle(
                                        color: tokens.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(color: tokens.border, height: 1),

                        TabBar(
                          controller: _tabController,
                          indicatorColor: activeAccent,
                          labelColor: activeAccent,
                          unselectedLabelColor: tokens.textSecondary,
                          dividerColor: Colors.transparent,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          tabs: const [
                            Tab(
                              icon: Icon(Icons.campaign_outlined, size: 18),
                              text: 'Notices Oversight',
                            ),
                            Tab(
                              icon: Icon(Icons.corporate_fare, size: 18),
                              text: 'Departments',
                            ),
                            Tab(
                              icon: Icon(Icons.work_outline, size: 18),
                              text: 'Project Groups',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) {
                      switch (_tabController.index) {
                        case 0:
                          return _buildNoticesSubTab(
                            context,
                            tokens,
                            firm,
                            activeAccent,
                            isMobile,
                          );
                        case 1:
                          return _buildDepartmentsSubTab(
                            context,
                            tokens,
                            firm,
                            activeAccent,
                            isMobile,
                          );
                        case 2:
                          return _buildProjectGroupsSubTab(
                            context,
                            tokens,
                            firm,
                            activeAccent,
                            isMobile,
                          );
                        default:
                          return const SizedBox.shrink();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SUB-TAB 1: NOTICES OVERSIGHT & GOVERNANCE
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildNoticesSubTab(
    BuildContext context,
    PcTokens tokens,
    Firm firm,
    Color activeAccent,
    bool isMobile,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign, color: activeAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Firm Notices Governance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _showManagePublishersDialog(context, firm.firmId),
                icon: Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: activeAccent,
                ),
                label: const Text('Publishers'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.textPrimary,
                  side: BorderSide(color: tokens.borderStrong),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                  final userSnap = await DBService.instance.getUserData(uid);
                  final userName = userSnap?['name'] as String? ?? 'Admin';
                  if (context.mounted) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NoticeComposerScreen(
                          firm: firm,
                          currentUid: uid,
                          currentUserName: userName,
                          currentUserRole: 'admin',
                          canTargetFirmWide: true,
                        ),
                      ),
                    );
                    if (mounted) setState(() {});
                  }
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Post Notice'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeAccent,
                  foregroundColor: PcTokens.contrastOn(activeAccent),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Metadata-only oversight: Admins observe reach statistics, audience targeting, and policy acknowledgements. Admin privacy invariant: notice bodies remain unread by non-recipient admins.',
            style: TextStyle(fontSize: 12, color: tokens.textSecondary),
          ),
          Divider(height: 24, color: tokens.border),

          Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: activeAccent,
                  ),
            ),
            child: Material(
              color: Colors.transparent,
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Allow Leads to Target Firm-Wide',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: tokens.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'When enabled, department leads can publish notices to all staff. When disabled, leads may only target their own department.',
                  style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                ),
                value: firm.leadsMayTargetBeyondOwnDepartment,
                onChanged: (bool value) async {
                  try {
                    await NoticesService.instance.updateLeadsMayTargetSetting(
                      firmId: firm.firmId,
                      allowed: value,
                    );
                    await AuditService.instance.logAction(
                      firmId: firm.firmId,
                      action: 'update_firm_setting',
                      targetType: 'setting',
                      targetId: 'leadsMayTargetBeyondOwnDepartment',
                      targetLabel: 'Allow Leads to Target Firm-Wide: $value',
                    );
                    ref.read(firmNotifierProvider.notifier).loadFirm(firm.firmId);
                    if (context.mounted) {
                      SnackbarService().showSnackbar(
                        'Firm notice target setting updated.',
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      SnackbarService().showSnackbar(
                        'Failed to update setting: $e',
                        isError: true,
                      );
                    }
                  }
                },
              ),
            ),
          ),
          Divider(height: 24, color: tokens.border),

          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Filter Records:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: tokens.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _noticeStatusFilter,
                    dropdownColor: tokens.surface,
                    style: TextStyle(color: tokens.textPrimary, fontSize: 12),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: tokens.textSecondary,
                      size: 18,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Status: All')),
                      DropdownMenuItem(
                        value: 'published',
                        child: Text('Status: Published'),
                      ),
                      DropdownMenuItem(
                        value: 'retracted',
                        child: Text('Status: Retracted'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _noticeStatusFilter = val);
                      }
                    },
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<NoticeType?>(
                    value: _noticeTypeFilter,
                    dropdownColor: tokens.surface,
                    style: TextStyle(color: tokens.textPrimary, fontSize: 12),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: tokens.textSecondary,
                      size: 18,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Type: All Types'),
                      ),
                      DropdownMenuItem(
                        value: NoticeType.announcement,
                        child: Text('Type: Announcement'),
                      ),
                      DropdownMenuItem(
                        value: NoticeType.urgent,
                        child: Text('Type: Urgent'),
                      ),
                      DropdownMenuItem(
                        value: NoticeType.policy,
                        child: Text('Type: Policy'),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _noticeTypeFilter = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          FutureBuilder<List<NoticeIndexModel>>(
            future: NoticesService.instance.fetchNoticeIndexList(
              firmId: firm.firmId,
              statusFilter: _noticeStatusFilter,
              typeFilter: _noticeTypeFilter,
              limit: 40,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: activeAccent),
                  ),
                );
              }

              final indexList = snapshot.data ?? [];

              if (indexList.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 28,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.border),
                  ),
                  child: Center(
                    child: Text(
                      'No notice records matching the selected filters.',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }

              return Material(
                color: Colors.transparent,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: indexList.length,
                  separatorBuilder: (_, _) =>
                      Divider(color: tokens.border, height: 1),
                  itemBuilder: (context, index) {
                    final item = indexList[index];
                    final isPolicy = item.isPolicy;
                    final isUrgent = item.isUrgent;
                    final isRetracted = item.isRetracted;

                    final iconBg = isUrgent
                        ? tokens.urgentBg
                        : isPolicy
                            ? tokens.projectSoft
                            : activeAccent.withValues(alpha: 0.12);
                    final iconFg = isUrgent
                        ? tokens.urgentText
                        : isPolicy
                            ? tokens.projectAccent
                            : activeAccent;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: iconBg,
                        child: Icon(
                          isUrgent
                              ? Icons.warning_amber_rounded
                              : isPolicy
                                  ? Icons.gavel
                                  : Icons.campaign_outlined,
                          color: iconFg,
                          size: 20,
                        ),
                      ),
                      title: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            item.authorName,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: isUrgent
                                  ? tokens.urgentBg
                                  : isPolicy
                                      ? tokens.projectSoft
                                      : tokens.surfaceSubtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.type.name.toUpperCase(),
                              style: TextStyle(
                                color: isUrgent
                                    ? tokens.urgentText
                                    : isPolicy
                                        ? tokens.projectAccent
                                        : tokens.textSecondary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: isRetracted
                                  ? tokens.urgentBg
                                  : _emerald.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.status.toUpperCase(),
                              style: TextStyle(
                                color:
                                    isRetracted ? tokens.urgentText : _emerald,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isPolicy)
                            Text(
                              'v${item.version}',
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Audience: ${item.audienceSummary} • Created: ${_formatDate(item.createdAt)}',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isPolicy)
                            IconButton(
                              icon: Icon(
                                Icons.checklist,
                                color: tokens.projectAccent,
                                size: 20,
                              ),
                              tooltip: 'Policy Acknowledgements Breakdown',
                              onPressed: () => _showPolicyAcksDialog(
                                context,
                                firm.firmId,
                                item,
                              ),
                            ),
                          IconButton(
                            icon: Icon(
                              Icons.people_outline,
                              color: activeAccent,
                              size: 20,
                            ),
                            tooltip: 'Calculate Audience Reach',
                            onPressed: () async {
                              final reach =
                                  await NoticesService.instance.computeReach(
                                firmId: firm.firmId,
                                audienceKeys: item.audienceKeys,
                              );
                              if (context.mounted) {
                                SnackbarService().showSnackbar(
                                  'Audience Reach for this notice: $reach active members.',
                                );
                              }
                            },
                          ),
                          if (!isRetracted)
                            IconButton(
                              icon: Icon(
                                Icons.cancel_outlined,
                                color: tokens.urgentText,
                                size: 20,
                              ),
                              tooltip: 'Retract Notice',
                              onPressed: () => _showRetractNoticeDialog(
                                context,
                                firm.firmId,
                                item.id,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SUB-TAB 2: DEPARTMENTS OVERSIGHT
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDepartmentsSubTab(
    BuildContext context,
    PcTokens tokens,
    Firm firm,
    Color activeAccent,
    bool isMobile,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.corporate_fare, color: activeAccent, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Departments & Department Chats',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () =>
                    _showCreateDepartmentDialog(context, firm.firmId),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Department'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeAccent,
                  foregroundColor: PcTokens.contrastOn(activeAccent),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Each active department has an automated group chat in the workspace. Click any department to filter staff or manage headship.',
            style: TextStyle(color: tokens.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),

          StreamBuilder<List<Department>>(
            stream: DBService.instance.streamDepartments(firm.firmId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: activeAccent),
                  ),
                );
              }

              final departments = snapshot.data ?? [];
              if (departments.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.corporate_fare_outlined,
                          size: 40,
                          color: tokens.textMuted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No departments established yet',
                          style: TextStyle(color: tokens.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create departments to organize teams and provision group chats.',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: departments.length,
                separatorBuilder: (_, _) =>
                    Divider(color: tokens.border, height: 1),
                itemBuilder: (context, index) {
                  final dept = departments[index];
                  final needsHead = dept.headUid == null && dept.isActive;

                  return InkWell(
                    onTap: () {
                      context.go('/admin/onboarding');
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                activeAccent.withValues(alpha: 0.12),
                            child: Icon(
                              Icons.folder_shared_outlined,
                              color: activeAccent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      dept.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: tokens.textPrimary,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: dept.isActive
                                            ? _emerald.withValues(alpha: 0.10)
                                            : tokens.surfaceSubtle,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        dept.status.toUpperCase(),
                                        style: TextStyle(
                                          color: dept.isActive
                                              ? _emerald
                                              : tokens.textMuted,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (needsHead)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tokens.warningSoft,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                            color: tokens.warningAccent
                                                .withValues(alpha: 0.35),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              size: 10,
                                              color: tokens.warningAccent,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              'Needs a Head',
                                              style: TextStyle(
                                                color: tokens.warningAccent,
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    FutureBuilder<int>(
                                      future: DBService.instance
                                          .getDepartmentHeadcount(
                                        firm.firmId,
                                        dept.deptId,
                                      ),
                                      builder: (context, countSnapshot) {
                                        final count = countSnapshot.data ?? 0;
                                        return Text(
                                          '$count active staff',
                                          style: TextStyle(
                                            color: tokens.textSecondary,
                                            fontSize: 12,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 12),
                                    if (dept.headUid != null)
                                      FutureBuilder<AppUser?>(
                                        future: DBService.instance
                                            .getUserDetails(dept.headUid!),
                                        builder: (context, headSnap) {
                                          final headName =
                                              headSnap.data?.name ??
                                                  'Assigned Head';
                                          return Flexible(
                                            child: Text(
                                              '• Head: $headName',
                                              style: TextStyle(
                                                color: activeAccent,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        },
                                      )
                                    else
                                      Text(
                                        '• No Head Assigned',
                                        style: TextStyle(
                                          color: tokens.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              color: tokens.textSecondary,
                            ),
                            color: tokens.surface,
                            onSelected: (action) {
                              if (action == 'members') {
                                _showManageDepartmentMembersDialog(
                                  context,
                                  firm.firmId,
                                  dept,
                                );
                              } else if (action == 'head') {
                                _showAssignDepartmentHeadDialog(
                                  context,
                                  firm.firmId,
                                  dept,
                                );
                              } else if (action == 'rename') {
                                _showRenameDepartmentDialog(
                                  context,
                                  firm.firmId,
                                  dept,
                                );
                              } else if (action == 'archive') {
                                _showArchiveDepartmentDialog(
                                  context,
                                  firm.firmId,
                                  dept,
                                );
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'members',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.people_outline,
                                      size: 16,
                                      color: tokens.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Assign / Manage Employees',
                                      style: TextStyle(
                                        color: tokens.textPrimary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'head',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.badge_outlined,
                                      size: 16,
                                      color: tokens.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Assign Department Head (Lead)',
                                      style: TextStyle(
                                        color: tokens.textPrimary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: tokens.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Rename Department',
                                      style: TextStyle(
                                        color: tokens.textPrimary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (dept.isActive) ...[
                                const PopupMenuDivider(),
                                PopupMenuItem(
                                  value: 'archive',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.archive_outlined,
                                        color: tokens.urgentText,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Archive Department',
                                        style: TextStyle(
                                          color: tokens.urgentText,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SUB-TAB 3: PROJECT GROUPS METADATA OVERSIGHT
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildProjectGroupsSubTab(
    BuildContext context,
    PcTokens tokens,
    Firm firm,
    Color activeAccent,
    bool isMobile,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.work_outline, color: activeAccent, size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Project Groups (Zero-Message Privacy Oversight)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Admins observe project names, owners, and headcount without reading private project messages.',
            style: TextStyle(color: tokens.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),

          StreamBuilder<List<ProjectGroup>>(
            stream:
                DBService.instance.streamProjectGroupsForAdmin(firm.firmId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: activeAccent),
                  ),
                );
              }

              final projects = snapshot.data ?? [];
              if (projects.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.work_off_outlined,
                          size: 40,
                          color: tokens.textMuted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No project groups created yet',
                          style: TextStyle(color: tokens.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Leads can create project groups for cross-functional collaboration.',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Material(
                color: Colors.transparent,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: projects.length,
                  separatorBuilder: (_, _) =>
                      Divider(color: tokens.border, height: 1),
                  itemBuilder: (context, index) {
                    final p = projects[index];

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: tokens.projectSoft,
                        child: Icon(
                          Icons.group_work,
                          color: tokens.projectAccent,
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            p.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: p.isActive
                                  ? tokens.projectSoft
                                  : tokens.surfaceSubtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              p.status.toUpperCase(),
                              style: TextStyle(
                                color: p.isActive
                                    ? tokens.projectAccent
                                    : tokens.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Row(
                        children: [
                          Text(
                            '${p.memberCount} member(s)',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          FutureBuilder<AppUser?>(
                            future: DBService.instance.getUserDetails(
                              p.ownerUid,
                            ),
                            builder: (context, ownerSnap) {
                              final ownerName =
                                  ownerSnap.data?.name ?? p.ownerUid;
                              return Flexible(
                                child: Text(
                                  '• Owner: $ownerName',
                                  style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      trailing: p.isActive
                          ? OutlinedButton.icon(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: tokens.surface,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: Text(
                                      'Archive Project ${p.name}?',
                                      style: TextStyle(
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                    content: Text(
                                      'Archiving will freeze this project group conversation.',
                                      style: TextStyle(
                                        color: tokens.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(
                                            color: tokens.textSecondary,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: tokens.urgentText,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Archive'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  try {
                                    await DBService.instance
                                        .archiveProjectGroup(
                                      firmId: firm.firmId,
                                      projectId: p.projectId,
                                      conversationId: p.conversationId,
                                    );
                                    await AuditService.instance.logAction(
                                      firmId: firm.firmId,
                                      action: 'archive_project',
                                      targetType: 'project',
                                      targetId: p.projectId,
                                      targetLabel: p.name,
                                    );
                                    SnackbarService().showSnackbar(
                                      'Project "${p.name}" archived.',
                                    );
                                  } catch (e) {
                                    SnackbarService().showSnackbar(
                                      'Error archiving project: $e',
                                      isError: true,
                                    );
                                  }
                                }
                              },
                              icon: const Icon(
                                Icons.archive_outlined,
                                size: 14,
                              ),
                              label: const Text('Archive'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: tokens.textSecondary,
                                side: BorderSide(color: tokens.borderStrong),
                              ),
                            )
                          : null,
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DIALOGS: CREATE DEPT, RENAME DEPT, ASSIGN HEAD, MANAGE MEMBERS, ARCHIVE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _showCreateDepartmentDialog(
    BuildContext context,
    String firmId,
  ) async {
    final tokens = context.pcTokens;
    final nameCtrl = TextEditingController();
    String? selectedHeadUid;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: tokens.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Create Department',
            style: TextStyle(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A dedicated group conversation will be automatically established for this department.',
                style: TextStyle(color: tokens.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: tokens.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Department Name',
                  hintText: 'e.g. Engineering, Sales, Marketing',
                ),
              ),
              const SizedBox(height: 14),
              StreamBuilder<List<Membership>>(
                stream: DBService.instance
                    .getMembershipsByStatus(firmId, 'approved'),
                builder: (context, snapshot) {
                  final members = snapshot.data ?? [];
                  return _styledDropdown<String?>(
                    tokens: tokens,
                    label: 'Department Head / Lead (Optional)',
                    value: selectedHeadUid,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Assign Later (No Head)'),
                      ),
                      ...members.map(
                        (m) => DropdownMenuItem<String?>(
                          value: m.uid,
                          child: FutureBuilder<AppUser?>(
                            future: DBService.instance.getUserDetails(m.uid),
                            builder: (context, userSnap) {
                              final name = userSnap.data?.name ?? m.uid;
                              return Text(
                                name,
                                style: TextStyle(color: tokens.textPrimary),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setDialogState(() => selectedHeadUid = val),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  SnackbarService().showSnackbar(
                    'Please enter a department name.',
                    isError: true,
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final newId = await DBService.instance.createDepartment(
                    firmId: firmId,
                    name: name,
                    headUid: selectedHeadUid,
                  );
                  await AuditService.instance.logAction(
                    firmId: firmId,
                    action: 'create_department',
                    targetType: 'department',
                    targetId: newId,
                    targetLabel: name,
                  );
                  SnackbarService().showSnackbar(
                    'Department "$name" created.',
                  );
                } catch (e) {
                  SnackbarService().showSnackbar(
                    'Error creating department: $e',
                    isError: true,
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameDepartmentDialog(
    BuildContext context,
    String firmId,
    Department dept,
  ) async {
    final tokens = context.pcTokens;
    final nameCtrl = TextEditingController(text: dept.name);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Rename Department',
          style: TextStyle(color: tokens.textPrimary),
        ),
        content: TextField(
          controller: nameCtrl,
          style: TextStyle(color: tokens.textPrimary),
          decoration: const InputDecoration(labelText: 'Department Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: tokens.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await DBService.instance.renameDepartment(
                  firmId,
                  dept.deptId,
                  dept.conversationId,
                  newName,
                );
                await AuditService.instance.logAction(
                  firmId: firmId,
                  action: 'rename_department',
                  targetType: 'department',
                  targetId: dept.deptId,
                  targetLabel: '${dept.name} -> $newName',
                );
                SnackbarService().showSnackbar(
                  'Department renamed to "$newName".',
                );
              } catch (e) {
                SnackbarService().showSnackbar(
                  'Error renaming department: $e',
                  isError: true,
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignDepartmentHeadDialog(
    BuildContext context,
    String firmId,
    Department dept,
  ) async {
    final tokens = context.pcTokens;
    String? selectedHeadUid = dept.headUid;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: tokens.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Assign Head: ${dept.name}',
            style: TextStyle(color: tokens.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<List<Membership>>(
                stream: DBService.instance
                    .getMembershipsByStatus(firmId, 'approved'),
                builder: (context, snapshot) {
                  final members = snapshot.data ?? [];
                  return _styledDropdown<String?>(
                    tokens: tokens,
                    label: 'Department Head / Lead',
                    value: selectedHeadUid,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No Head (Clear Head)'),
                      ),
                      ...members.map(
                        (m) => DropdownMenuItem<String?>(
                          value: m.uid,
                          child: FutureBuilder<AppUser?>(
                            future: DBService.instance.getUserDetails(m.uid),
                            builder: (context, userSnap) {
                              final name = userSnap.data?.name ?? m.uid;
                              return Text(
                                name,
                                style: TextStyle(color: tokens.textPrimary),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setDialogState(() => selectedHeadUid = val),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await DBService.instance.updateDepartmentHead(
                    firmId,
                    dept.deptId,
                    selectedHeadUid,
                  );
                  await AuditService.instance.logAction(
                    firmId: firmId,
                    action: 'assign_department_head',
                    targetType: 'department',
                    targetId: dept.deptId,
                    targetLabel:
                        '${dept.name} head -> ${selectedHeadUid ?? "None"}',
                  );
                  SnackbarService().showSnackbar('Department head updated.');
                } catch (e) {
                  SnackbarService().showSnackbar(
                    'Error updating head: $e',
                    isError: true,
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showManageDepartmentMembersDialog(
    BuildContext context,
    String firmId,
    Department dept,
  ) async {
    final tokens = context.pcTokens;
    final searchCtrl = TextEditingController();
    Set<String>? selectedUids;
    Set<String>? initialUids;
    String searchQuery = '';
    final Map<String, AppUser> userCache = {};
    bool isFetchingUsers = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return StreamBuilder<List<Membership>>(
            stream:
                DBService.instance.getMembershipsByStatus(firmId, 'approved'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  selectedUids == null) {
                return AlertDialog(
                  backgroundColor: tokens.surface,
                  content: SizedBox(
                    height: 120,
                    child: Center(
                      child: CircularProgressIndicator(color: tokens.primary),
                    ),
                  ),
                );
              }

              final allMembers = snapshot.data ?? [];
              if (selectedUids == null) {
                initialUids = allMembers
                    .where(
                      (m) =>
                          m.departmentId == dept.deptId ||
                          m.uid == dept.headUid,
                    )
                    .map((m) => m.uid)
                    .toSet();
                selectedUids = Set<String>.from(initialUids!);
              }

              if (!isFetchingUsers && userCache.length < allMembers.length) {
                isFetchingUsers = true;
                Future.wait(
                  allMembers
                      .where((m) => !userCache.containsKey(m.uid))
                      .map((m) async {
                    final u = await DBService.instance.getUserDetails(m.uid);
                    if (u != null) userCache[m.uid] = u;
                  }),
                ).then((_) {
                  if (ctx.mounted) setDialogState(() {});
                });
              }

              final filteredMembers = allMembers.where((m) {
                if (searchQuery.isEmpty) return true;
                final user = userCache[m.uid];
                final name = user?.name.toLowerCase() ?? '';
                final email = user?.email.toLowerCase() ?? '';
                return name.contains(searchQuery) ||
                    email.contains(searchQuery);
              }).toList();

              return AlertDialog(
                backgroundColor: tokens.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  'Manage Members: ${dept.name}',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: searchCtrl,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search staff by name or email...',
                          prefixIcon: Icon(
                            Icons.search,
                            size: 18,
                            color: tokens.textMuted,
                          ),
                        ),
                        onChanged: (val) => setDialogState(
                          () => searchQuery = val.trim().toLowerCase(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredMembers.length,
                          itemBuilder: (ctx, idx) {
                            final m = filteredMembers[idx];
                            final isHead = m.uid == dept.headUid;
                            final isSelected = selectedUids!.contains(m.uid);
                            final user = userCache[m.uid];
                            final name = user?.name ?? m.uid;

                            return CheckboxListTile(
                              value: isSelected,
                              activeColor: tokens.primary,
                              onChanged: isHead
                                  ? null
                                  : (checked) {
                                      setDialogState(() {
                                        if (checked == true) {
                                          selectedUids!.add(m.uid);
                                        } else {
                                          selectedUids!.remove(m.uid);
                                        }
                                      });
                                    },
                              title: Text(
                                name,
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                user?.email ?? '',
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        final assigned = selectedUids!.toList();
                        final unassigned =
                            initialUids!.difference(selectedUids!).toList();
                        await DBService.instance.updateDepartmentMembers(
                          firmId: firmId,
                          deptId: dept.deptId,
                          assignedUids: assigned,
                          unassignedUids: unassigned,
                        );
                        await AuditService.instance.logAction(
                          firmId: firmId,
                          action: 'update_dept_members',
                          targetType: 'department',
                          targetId: dept.deptId,
                          targetLabel: '${dept.name} members updated',
                        );
                        SnackbarService().showSnackbar(
                          'Updated department members for ${dept.name}.',
                        );
                      } catch (e) {
                        SnackbarService().showSnackbar(
                          'Error updating members: $e',
                          isError: true,
                        );
                      }
                    },
                    child: const Text('Save Members'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showArchiveDepartmentDialog(
    BuildContext context,
    String firmId,
    Department dept,
  ) async {
    final count =
        await DBService.instance.getDepartmentHeadcount(firmId, dept.deptId);
    if (!context.mounted) return;
    final tokens = context.pcTokens;

    if (count > 0) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: tokens.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Cannot Archive Department',
            style: TextStyle(color: tokens.textPrimary),
          ),
          content: Text(
            'This department currently has $count active staff members assigned. Reassign all members first.',
            style: TextStyle(color: tokens.textSecondary),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Archive ${dept.name}?',
          style: TextStyle(color: tokens.textPrimary),
        ),
        content: Text(
          'Archiving this department will freeze its group conversation.',
          style: TextStyle(color: tokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: tokens.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.urgentText,
              foregroundColor: Colors.white,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DBService.instance.archiveDepartment(firmId, dept.deptId);
        await AuditService.instance.logAction(
          firmId: firmId,
          action: 'archive_department',
          targetType: 'department',
          targetId: dept.deptId,
          targetLabel: dept.name,
        );
        SnackbarService().showSnackbar('Department "${dept.name}" archived.');
      } catch (e) {
        SnackbarService().showSnackbar('Error: $e', isError: true);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NOTICES DIALOGS: POLICY ACKS, PUBLISHERS, RETRACT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _showPolicyAcksDialog(
    BuildContext context,
    String firmId,
    NoticeIndexModel notice,
  ) async {
    final tokens = context.pcTokens;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return FutureBuilder<List<dynamic>>(
            future: Future.wait([
              NoticesService.instance.getAcknowledgedUsers(
                firmId: firmId,
                noticeId: notice.id,
                version: notice.version,
                limit: 100,
              ),
              NoticesService.instance.computeReach(
                firmId: firmId,
                audienceKeys: notice.audienceKeys,
              ),
            ]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return AlertDialog(
                  backgroundColor: tokens.surface,
                  content: SizedBox(
                    height: 120,
                    child: Center(
                      child: CircularProgressIndicator(color: tokens.primary),
                    ),
                  ),
                );
              }

              final List<NoticeAck> acks =
                  (snapshot.data?[0] as List<NoticeAck>?) ?? [];
              final int reach = (snapshot.data?[1] as int?) ?? 1;
              final double ratio =
                  reach > 0 ? (acks.length / reach).clamp(0.0, 1.0) : 0.0;
              final percent = (ratio * 100).toStringAsFixed(0);

              return AlertDialog(
                backgroundColor: tokens.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Icon(Icons.gavel, color: tokens.projectAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Policy Acknowledgements (v${notice.version})',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${acks.length} of $reach acknowledged ($percent%)',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: tokens.surfaceSubtle,
                          color: tokens.projectAccent,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: acks.isEmpty
                            ? Center(
                                child: Text(
                                  'No acknowledgements yet.',
                                  style: TextStyle(color: tokens.textSecondary),
                                ),
                              )
                            : Material(
                                color: Colors.transparent,
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: acks.length,
                                  separatorBuilder: (_, _) => Divider(
                                    height: 1,
                                    color: tokens.border,
                                  ),
                                  itemBuilder: (context, i) {
                                    final ack = acks[i];
                                    return ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.check_circle,
                                        color: _emerald,
                                        size: 18,
                                      ),
                                      title: Text(
                                        ack.userName ?? 'Member',
                                        style: TextStyle(
                                          color: tokens.textPrimary,
                                          fontSize: 13,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'v${ack.version} • ${_formatDate(ack.at)}',
                                        style: TextStyle(
                                          color: tokens.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showManagePublishersDialog(
    BuildContext context,
    String firmId,
  ) async {
    final tokens = context.pcTokens;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return StreamBuilder<List<Membership>>(
            stream:
                DBService.instance.getMembershipsByStatus(firmId, 'approved'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return AlertDialog(
                  backgroundColor: tokens.surface,
                  content: SizedBox(
                    height: 120,
                    child: Center(
                      child: CircularProgressIndicator(color: tokens.primary),
                    ),
                  ),
                );
              }

              final members = snapshot.data ?? [];
              final currentAdminUid =
                  FirebaseAuth.instance.currentUser?.uid ?? '';

              return AlertDialog(
                backgroundColor: tokens.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Icon(Icons.campaign, color: tokens.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Manage Notice Publishers',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 500,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 350),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: members.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: tokens.border),
                          itemBuilder: (context, index) {
                            final m = members[index];
                            final isLeadOrAdmin = m.isAdmin || m.isLead;
                            final isSelf = m.uid == currentAdminUid;

                            return FutureBuilder<AppUser?>(
                              future: DBService.instance.getUserDetails(m.uid),
                              builder: (context, userSnap) {
                                final name = userSnap.data?.name ?? m.uid;
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      color: tokens.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  subtitle: Text(
                                    userSnap.data?.email ?? '',
                                    style: TextStyle(
                                      color: tokens.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  trailing: isLeadOrAdmin
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                _emerald.withValues(alpha: 0.10),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Publisher (Role)',
                                            style: TextStyle(
                                              color: _emerald,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        )
                                      : Switch.adaptive(
                                          value: m.noticePublisher,
                                          onChanged: isSelf
                                              ? null
                                              : (val) async {
                                                  try {
                                                    await NoticesService.instance
                                                        .setNoticePublisher(
                                                      firmId: firmId,
                                                      memberUid: m.uid,
                                                      isPublisher: val,
                                                    );
                                                    SnackbarService()
                                                        .showSnackbar(
                                                      'Publisher updated for $name.',
                                                    );
                                                  } catch (e) {
                                                    SnackbarService()
                                                        .showSnackbar(
                                                      'Failed to update publisher: $e',
                                                      isError: true,
                                                    );
                                                  }
                                                },
                                        ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showRetractNoticeDialog(
    BuildContext context,
    String firmId,
    String noticeId,
  ) async {
    final tokens = context.pcTokens;
    final reasonCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Retract Notice?',
          style: TextStyle(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Retracting this notice hides it from staff active feeds.',
              style: TextStyle(color: tokens.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              style: TextStyle(color: tokens.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Retraction Reason (Optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: tokens.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.urgentText,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retract Notice'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final currentAdminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      try {
        await NoticesService.instance.retractNotice(
          firmId: firmId,
          noticeId: noticeId,
          retractedByUid: currentAdminUid,
          reason:
              reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : null,
        );
        await AuditService.instance.logAction(
          firmId: firmId,
          action: 'retract_notice',
          targetType: 'notice',
          targetId: noticeId,
          targetLabel: 'Notice $noticeId retracted',
        );
        if (mounted) setState(() {});
        SnackbarService().showSnackbar('Notice retracted.');
      } catch (e) {
        SnackbarService()
            .showSnackbar('Error retracting notice: $e', isError: true);
      }
    }
  }
}
