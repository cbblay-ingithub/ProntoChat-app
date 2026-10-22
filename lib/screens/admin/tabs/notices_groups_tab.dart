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
  late TabController _tabController;

  // Notice filters
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

  Color _hexToColor(String hexString, [Color fallback = const Color(0xFF295CB4)]) {
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

  @override
  Widget build(BuildContext context) {
    final firm = ref.watch(currentFirmProvider);
    if (firm == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final primaryColor = _hexToColor(firm.primaryColor);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card with Tabs
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1D1D),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
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
                              color: primaryColor.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.hub_outlined, color: primaryColor, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Notices & Groups Management',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Govern official firm notices, oversee department teams, and monitor cross-functional project groups.',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(color: Colors.white.withOpacity(0.06), height: 1),

                    // Tab Bar
                    TabBar(
                      controller: _tabController,
                      indicatorColor: primaryColor,
                      labelColor: primaryColor,
                      unselectedLabelColor: Colors.grey[400],
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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

              // Tab Views
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  switch (_tabController.index) {
                    case 0:
                      return _buildNoticesSubTab(context, firm, primaryColor, isMobile);
                    case 1:
                      return _buildDepartmentsSubTab(context, firm, primaryColor, isMobile);
                    case 2:
                      return _buildProjectGroupsSubTab(context, firm, primaryColor, isMobile);
                    default:
                      return const SizedBox.shrink();
                  }
                },
              ),
            ],
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
    Firm firm,
    Color primaryColor,
    bool isMobile,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1D1D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Bar: Title, Publishers & Post Notice
          Row(
            children: [
              Icon(Icons.campaign, color: primaryColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Firm Notices Governance',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showManagePublishersDialog(context, firm.firmId),
                icon: const Icon(Icons.shield_outlined, size: 16),
                label: const Text('Publishers'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Metadata-only oversight: Admins observe reach statistics, audience targeting, and policy acknowledgements. Admin privacy invariant: notice bodies remain unread by non-recipient admins.',
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
          const Divider(height: 24),

          // Setting: Allow Leads to Target Firm-Wide
          Material(
            color: Colors.transparent,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              activeColor: primaryColor,
              title: const Text(
                'Allow Leads to Target Firm-Wide',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
              ),
              subtitle: const Text(
                'When enabled, department leads can publish notices to all staff. When disabled, leads may only target their own department.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
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
                    SnackbarService().showSnackbar('Firm notice target setting updated.');
                  }
                } catch (e) {
                  if (context.mounted) {
                    SnackbarService().showSnackbar('Failed to update setting: $e', isError: true);
                  }
                }
              },
            ),
          ),
          const Divider(height: 24),

          // Filters Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Filter Records:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              DropdownButton<String>(
                value: _noticeStatusFilter,
                dropdownColor: const Color(0xFF222121),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Status: All')),
                  DropdownMenuItem(value: 'published', child: Text('Status: Published')),
                  DropdownMenuItem(value: 'retracted', child: Text('Status: Retracted')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _noticeStatusFilter = val);
                },
              ),
              DropdownButton<NoticeType?>(
                value: _noticeTypeFilter,
                dropdownColor: const Color(0xFF222121),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Type: All Types')),
                  DropdownMenuItem(value: NoticeType.announcement, child: Text('Type: Announcement')),
                  DropdownMenuItem(value: NoticeType.urgent, child: Text('Type: Urgent')),
                  DropdownMenuItem(value: NoticeType.policy, child: Text('Type: Policy')),
                ],
                onChanged: (val) {
                  setState(() => _noticeTypeFilter = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Notice Metadata List
          FutureBuilder<List<NoticeIndexModel>>(
            future: NoticesService.instance.fetchNoticeIndexList(
              firmId: firm.firmId,
              statusFilter: _noticeStatusFilter,
              typeFilter: _noticeTypeFilter,
              limit: 40,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final indexList = snapshot.data ?? [];

              if (indexList.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161515),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'No notice records matching the selected filters.',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
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
                  separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.04), height: 1),
                  itemBuilder: (context, index) {
                    final item = indexList[index];
                    final isPolicy = item.isPolicy;
                    final isUrgent = item.isUrgent;
                    final isRetracted = item.isRetracted;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      leading: CircleAvatar(
                      backgroundColor: isUrgent
                          ? Colors.redAccent.withOpacity(0.18)
                          : isPolicy
                              ? Colors.indigoAccent.withOpacity(0.18)
                              : primaryColor.withOpacity(0.18),
                      child: Icon(
                        isUrgent
                            ? Icons.warning_amber_rounded
                            : isPolicy
                                ? Icons.gavel
                                : Icons.campaign_outlined,
                        color: isUrgent
                            ? Colors.redAccent
                            : isPolicy
                                ? Colors.indigoAccent
                                : primaryColor,
                        size: 20,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          item.authorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isUrgent
                                ? Colors.redAccent.withOpacity(0.2)
                                : isPolicy
                                    ? Colors.indigoAccent.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.type.name.toUpperCase(),
                            style: TextStyle(
                              color: isUrgent
                                  ? Colors.redAccent
                                  : isPolicy
                                      ? Colors.indigoAccent
                                      : Colors.grey[300],
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isRetracted ? Colors.red.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.status.toUpperCase(),
                            style: TextStyle(
                              color: isRetracted ? Colors.redAccent : Colors.greenAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isPolicy) ...[
                          const SizedBox(width: 6),
                          Text('v${item.version}', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                        ],
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Audience: ${item.audienceSummary} • Created: ${_formatDate(item.createdAt)}',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPolicy)
                          IconButton(
                            icon: const Icon(Icons.checklist, color: Colors.indigoAccent, size: 20),
                            tooltip: 'Policy Acknowledgements Breakdown',
                            onPressed: () => _showPolicyAcksDialog(context, firm.firmId, item),
                          ),
                        IconButton(
                          icon: const Icon(Icons.people_outline, color: Colors.blueAccent, size: 20),
                          tooltip: 'Calculate Audience Reach',
                          onPressed: () async {
                            final reach = await NoticesService.instance.computeReach(
                              firmId: firm.firmId,
                              audienceKeys: item.audienceKeys,
                            );
                            if (context.mounted) {
                              SnackbarService().showSnackbar('Audience Reach for this notice: $reach active members.');
                            }
                          },
                        ),
                        if (!isRetracted)
                          IconButton(
                            icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 20),
                            tooltip: 'Retract Notice',
                            onPressed: () => _showRetractNoticeDialog(context, firm.firmId, item.id),
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
    Firm firm,
    Color primaryColor,
    bool isMobile,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1D1D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.corporate_fare, color: primaryColor, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Departments & Department Chats',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateDepartmentDialog(context, firm.firmId),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Department'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Each active department has an automated group chat in the mobile app. Click any department to filter staff or manage headship.',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          const SizedBox(height: 16),

          StreamBuilder<List<Department>>(
            stream: DBService.instance.streamDepartments(firm.firmId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
              }

              final departments = snapshot.data ?? [];
              if (departments.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(Icons.corporate_fare_outlined, size: 40, color: Colors.grey[600]),
                        const SizedBox(height: 8),
                        Text('No departments established yet', style: TextStyle(color: Colors.grey[400])),
                        const SizedBox(height: 4),
                        Text('Create departments to organize teams and provision group chats.',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: departments.length,
                separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.04), height: 1),
                itemBuilder: (context, index) {
                  final dept = departments[index];
                  final needsHead = dept.headUid == null && dept.isActive;

                  return InkWell(
                    onTap: () {
                      // Row click navigates to Onboarding Tab filtered by department
                      context.go('/admin/onboarding');
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: primaryColor.withOpacity(0.15),
                            child: Icon(Icons.folder_shared_outlined, color: primaryColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(dept.name, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: dept.isActive ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        dept.status.toUpperCase(),
                                        style: TextStyle(
                                          color: dept.isActive ? Colors.greenAccent : Colors.grey,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (needsHead) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.warning_amber_rounded, size: 10, color: Colors.amberAccent),
                                            SizedBox(width: 3),
                                            Text(
                                              'Needs a Head',
                                              style: TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    FutureBuilder<int>(
                                      future: DBService.instance.getDepartmentHeadcount(firm.firmId, dept.deptId),
                                      builder: (context, countSnapshot) {
                                        final count = countSnapshot.data ?? 0;
                                        return Text(
                                          '$count active staff',
                                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 12),
                                    if (dept.headUid != null)
                                      FutureBuilder<AppUser?>(
                                        future: DBService.instance.getUserDetails(dept.headUid!),
                                        builder: (context, headSnap) {
                                          final headName = headSnap.data?.name ?? 'Assigned Head';
                                          return Text(
                                            '• Head: $headName',
                                            style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                                          );
                                        },
                                      )
                                    else
                                      Text(
                                        '• No Head Assigned',
                                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                            color: const Color(0xFF222121),
                            onSelected: (action) {
                              if (action == 'members') {
                                _showManageDepartmentMembersDialog(context, firm.firmId, dept);
                              } else if (action == 'head') {
                                _showAssignDepartmentHeadDialog(context, firm.firmId, dept);
                              } else if (action == 'rename') {
                                _showRenameDepartmentDialog(context, firm.firmId, dept);
                              } else if (action == 'archive') {
                                _showArchiveDepartmentDialog(context, firm.firmId, dept);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'members',
                                child: Row(
                                  children: [
                                    Icon(Icons.people_outline, size: 16, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('Assign / Manage Employees', style: TextStyle(color: Colors.white, fontSize: 13)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'head',
                                child: Row(
                                  children: [
                                    Icon(Icons.badge_outlined, size: 16, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('Assign Department Head (Lead)', style: TextStyle(color: Colors.white, fontSize: 13)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 16, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('Rename Department', style: TextStyle(color: Colors.white, fontSize: 13)),
                                  ],
                                ),
                              ),
                              if (dept.isActive) ...[
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'archive',
                                  child: Row(
                                    children: [
                                      Icon(Icons.archive_outlined, color: Colors.redAccent, size: 16),
                                      SizedBox(width: 8),
                                      Text('Archive Department', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
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
    Firm firm,
    Color primaryColor,
    bool isMobile,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1D1D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.work_outline, color: primaryColor, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Project Groups (Zero-Message Privacy Oversight)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Admins observe project names, owners, and headcount without reading private project messages.',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          const SizedBox(height: 16),

          StreamBuilder<List<ProjectGroup>>(
            stream: DBService.instance.streamProjectGroupsForAdmin(firm.firmId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
              }

              final projects = snapshot.data ?? [];
              if (projects.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(Icons.work_off_outlined, size: 40, color: Colors.grey[600]),
                        const SizedBox(height: 8),
                        Text('No project groups created yet', style: TextStyle(color: Colors.grey[400])),
                        const SizedBox(height: 4),
                        Text('Leads can create project groups for cross-functional collaboration.',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
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
                  separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.04), height: 1),
                  itemBuilder: (context, index) {
                    final p = projects[index];

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                      backgroundColor: Colors.purple.withOpacity(0.15),
                      child: const Icon(Icons.group_work, color: Colors.purpleAccent, size: 20),
                    ),
                    title: Row(
                      children: [
                        Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: p.isActive ? Colors.purple.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            p.status.toUpperCase(),
                            style: TextStyle(
                              color: p.isActive ? Colors.purpleAccent : Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        Text('${p.memberCount} member(s)', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                        const SizedBox(width: 12),
                        FutureBuilder<AppUser?>(
                          future: DBService.instance.getUserDetails(p.ownerUid),
                          builder: (context, ownerSnap) {
                            final ownerName = ownerSnap.data?.name ?? p.ownerUid;
                            return Text('• Owner: $ownerName', style: TextStyle(color: Colors.grey[400], fontSize: 12));
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
                                  backgroundColor: const Color(0xFF222121),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: Text('Archive Project ${p.name}?'),
                                  content: const Text(
                                    'Archiving will freeze this project group conversation.',
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                      child: const Text('Archive'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                try {
                                  await DBService.instance.archiveProjectGroup(
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
                                  SnackbarService().showSnackbar('Project "${p.name}" archived.');
                                } catch (e) {
                                  SnackbarService().showSnackbar('Error archiving project: $e', isError: true);
                                }
                              }
                            },
                            icon: const Icon(Icons.archive_outlined, size: 14),
                            label: const Text('Archive'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[400],
                              side: BorderSide(color: Colors.grey[700]!),
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

  Future<void> _showCreateDepartmentDialog(BuildContext context, String firmId) async {
    final nameCtrl = TextEditingController();
    String? selectedHeadUid;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF222121),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Create Department', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A dedicated group conversation will be automatically established for this department in the mobile app.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Department Name',
                  hintText: 'e.g. Engineering, Sales, Marketing',
                  filled: true,
                  fillColor: const Color(0xFF161515),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              StreamBuilder<List<Membership>>(
                stream: DBService.instance.getMembershipsByStatus(firmId, 'approved'),
                builder: (context, snapshot) {
                  final members = snapshot.data ?? [];
                  return DropdownButtonFormField<String?>(
                    value: selectedHeadUid,
                    dropdownColor: const Color(0xFF222121),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Department Head / Lead (Optional)',
                      filled: true,
                      fillColor: const Color(0xFF161515),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Assign Later (No Head)')),
                      ...members.map(
                        (m) => DropdownMenuItem<String?>(
                          value: m.uid,
                          child: FutureBuilder<AppUser?>(
                            future: DBService.instance.getUserDetails(m.uid),
                            builder: (context, userSnap) {
                              final name = userSnap.data?.name ?? m.uid;
                              return Text(name, style: const TextStyle(color: Colors.white));
                            },
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) => setDialogState(() => selectedHeadUid = val),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  SnackbarService().showSnackbar('Please enter a department name.', isError: true);
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
                  SnackbarService().showSnackbar('Department "$name" created.');
                } catch (e) {
                  SnackbarService().showSnackbar('Error creating department: $e', isError: true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameDepartmentDialog(BuildContext context, String firmId, Department dept) async {
    final nameCtrl = TextEditingController(text: dept.name);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222121),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Department'),
        content: TextField(
          controller: nameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Department Name',
            filled: true,
            fillColor: const Color(0xFF161515),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await DBService.instance.renameDepartment(firmId, dept.deptId, dept.conversationId, newName);
                await AuditService.instance.logAction(
                  firmId: firmId,
                  action: 'rename_department',
                  targetType: 'department',
                  targetId: dept.deptId,
                  targetLabel: '${dept.name} -> $newName',
                );
                SnackbarService().showSnackbar('Department renamed to "$newName".');
              } catch (e) {
                SnackbarService().showSnackbar('Error renaming department: $e', isError: true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignDepartmentHeadDialog(BuildContext context, String firmId, Department dept) async {
    String? selectedHeadUid = dept.headUid;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF222121),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Assign Head: ${dept.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<List<Membership>>(
                stream: DBService.instance.getMembershipsByStatus(firmId, 'approved'),
                builder: (context, snapshot) {
                  final members = snapshot.data ?? [];
                  return DropdownButtonFormField<String?>(
                    value: selectedHeadUid,
                    dropdownColor: const Color(0xFF222121),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Department Head / Lead',
                      filled: true,
                      fillColor: const Color(0xFF161515),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('No Head (Clear Head)')),
                      ...members.map(
                        (m) => DropdownMenuItem<String?>(
                          value: m.uid,
                          child: FutureBuilder<AppUser?>(
                            future: DBService.instance.getUserDetails(m.uid),
                            builder: (context, userSnap) {
                              final name = userSnap.data?.name ?? m.uid;
                              return Text(name, style: const TextStyle(color: Colors.white));
                            },
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) => setDialogState(() => selectedHeadUid = val),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await DBService.instance.updateDepartmentHead(firmId, dept.deptId, selectedHeadUid);
                  await AuditService.instance.logAction(
                    firmId: firmId,
                    action: 'assign_department_head',
                    targetType: 'department',
                    targetId: dept.deptId,
                    targetLabel: '${dept.name} head -> ${selectedHeadUid ?? "None"}',
                  );
                  SnackbarService().showSnackbar('Department head updated.');
                } catch (e) {
                  SnackbarService().showSnackbar('Error updating head: $e', isError: true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showManageDepartmentMembersDialog(BuildContext context, String firmId, Department dept) async {
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
            stream: DBService.instance.getMembershipsByStatus(firmId, 'approved'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && selectedUids == null) {
                return const AlertDialog(
                  backgroundColor: Color(0xFF222121),
                  content: SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
                );
              }

              final allMembers = snapshot.data ?? [];
              if (selectedUids == null) {
                initialUids = allMembers
                    .where((m) => m.departmentId == dept.deptId || m.uid == dept.headUid)
                    .map((m) => m.uid)
                    .toSet();
                selectedUids = Set<String>.from(initialUids!);
              }

              if (!isFetchingUsers && userCache.length < allMembers.length) {
                isFetchingUsers = true;
                Future.wait(
                  allMembers.where((m) => !userCache.containsKey(m.uid)).map((m) async {
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
                return name.contains(searchQuery) || email.contains(searchQuery);
              }).toList();

              return AlertDialog(
                backgroundColor: const Color(0xFF222121),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text('Manage Members: ${dept.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: searchCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search staff by name or email...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          filled: true,
                          fillColor: const Color(0xFF161515),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) => setDialogState(() => searchQuery = val.trim().toLowerCase()),
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
                              activeColor: Colors.blueAccent,
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
                              title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                              subtitle: Text(user?.email ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        final assigned = selectedUids!.toList();
                        final unassigned = initialUids!.difference(selectedUids!).toList();
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
                        SnackbarService().showSnackbar('Updated department members for ${dept.name}.');
                      } catch (e) {
                        SnackbarService().showSnackbar('Error updating members: $e', isError: true);
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

  Future<void> _showArchiveDepartmentDialog(BuildContext context, String firmId, Department dept) async {
    final count = await DBService.instance.getDepartmentHeadcount(firmId, dept.deptId);
    if (!context.mounted) return;

    if (count > 0) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF222121),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cannot Archive Department'),
          content: Text('This department currently has $count active staff members assigned. Reassign all members first.'),
          actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Understood'))],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222121),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Archive ${dept.name}?'),
        content: const Text('Archiving this department will freeze its group conversation.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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

  Future<void> _showPolicyAcksDialog(BuildContext context, String firmId, NoticeIndexModel notice) async {
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
                return const AlertDialog(
                  backgroundColor: Color(0xFF222121),
                  content: SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
                );
              }

              final List<NoticeAck> acks = (snapshot.data?[0] as List<NoticeAck>?) ?? [];
              final int reach = (snapshot.data?[1] as int?) ?? 1;
              final double ratio = reach > 0 ? (acks.length / reach).clamp(0.0, 1.0) : 0.0;
              final percent = (ratio * 100).toStringAsFixed(0);

              return AlertDialog(
                backgroundColor: const Color(0xFF222121),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    const Icon(Icons.gavel, color: Colors.indigoAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Policy Acknowledgements (v${notice.version})',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${acks.length} of $reach acknowledged ($percent%)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: Colors.white12,
                          color: Colors.indigoAccent,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: acks.isEmpty
                            ? Center(child: Text('No acknowledgements yet.', style: TextStyle(color: Colors.grey[400])))
                            : Material(
                                color: Colors.transparent,
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: acks.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                                  itemBuilder: (context, i) {
                                    final ack = acks[i];
                                    return ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                                      title: Text(ack.userName ?? 'Member', style: const TextStyle(color: Colors.white, fontSize: 13)),
                                      subtitle: Text('v${ack.version} • ${_formatDate(ack.at)}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showManagePublishersDialog(BuildContext context, String firmId) async {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return StreamBuilder<List<Membership>>(
            stream: DBService.instance.getMembershipsByStatus(firmId, 'approved'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AlertDialog(
                  backgroundColor: Color(0xFF222121),
                  content: SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
                );
              }

              final members = snapshot.data ?? [];
              final currentAdminUid = FirebaseAuth.instance.currentUser?.uid ?? '';

              return AlertDialog(
                backgroundColor: const Color(0xFF222121),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.campaign, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Manage Notice Publishers',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
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
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
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
                                  title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                  subtitle: Text(userSnap.data?.email ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                  trailing: isLeadOrAdmin
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text('Publisher (Role)',
                                              style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                        )
                                      : Switch.adaptive(
                                          value: m.noticePublisher,
                                          activeColor: Colors.blueAccent,
                                          onChanged: isSelf
                                              ? null
                                              : (val) async {
                                                  try {
                                                    await NoticesService.instance.setNoticePublisher(
                                                      firmId: firmId,
                                                      memberUid: m.uid,
                                                      isPublisher: val,
                                                    );
                                                    SnackbarService().showSnackbar('Publisher updated for $name.');
                                                  } catch (e) {
                                                    SnackbarService().showSnackbar('Failed to update publisher: $e', isError: true);
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
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showRetractNoticeDialog(BuildContext context, String firmId, String noticeId) async {
    final reasonCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222121),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Retract Notice?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Retracting this notice hides it from staff active feeds.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Retraction Reason (Optional)',
                filled: true,
                fillColor: const Color(0xFF161515),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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
          reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : null,
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
        SnackbarService().showSnackbar('Error retracting notice: $e', isError: true);
      }
    }
  }
}
