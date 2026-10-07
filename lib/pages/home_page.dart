import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import '../models/firm.dart';
import '../providers/auth_provider.dart';
import '../providers/firm/providers.dart';
import 'employee/employee_home_tab.dart';
import 'employee/employee_chats_tab.dart';
import 'employee/employee_directory_tab.dart';
import 'employee/employee_profile_tab.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    if (index >= 0 && index < 4) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = provider.Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    // Check if auth is currently initializing or authenticating
    if (auth.isInitializing || auth.isAuthenticating) {
      return const Scaffold(
        backgroundColor: Color.fromRGBO(28, 27, 27, 1),
        body: Center(
          child: CircularProgressIndicator(
            color: Color.fromRGBO(41, 116, 188, 1),
          ),
        ),
      );
    }

    // Resolve user & firm context
    final String uid = auth.currentUserId ?? 'emp_alex_101';
    final String userName = auth.currentUserName.isNotEmpty ? auth.currentUserName : 'Alex Morgan';
    final String userEmail = (auth.currentUserEmail != null && auth.currentUserEmail!.isNotEmpty)
        ? auth.currentUserEmail!
        : 'alex.morgan@workspace.com';
    final String? userImage = auth.currentUserImage.isNotEmpty ? auth.currentUserImage : null;

    final Firm? activeFirm = ref.watch(currentFirmProvider);
    if (activeFirm == null) {
      final membershipData = ref.watch(myMembershipStreamProvider).value?.data();
      final memberFirmId = membershipData?['firmId'] as String?;
      if (memberFirmId != null && memberFirmId.isNotEmpty) {
        ref.read(firmNotifierProvider.notifier).loadFirm(memberFirmId);
        return const Scaffold(
          backgroundColor: Color.fromRGBO(28, 27, 27, 1),
          body: Center(
            child: CircularProgressIndicator(
              color: Color.fromRGBO(41, 116, 188, 1),
            ),
          ),
        );
      }
    }

    final Firm firm = activeFirm ??
        Firm(
          firmId: 'firm_workspace_101',
          name: 'ProntoChat Workspace',
          primaryColor: '#2974BC',
          adminId: 'admin_101',
          createdAt: DateTime.now(),
        );

    final List<Widget> tabs = [
      EmployeeHomeTab(
        uid: uid,
        userName: userName,
        firm: firm,
        onNavigateToTab: _navigateToTab,
      ),
      EmployeeChatsTab(
        uid: uid,
        userName: userName,
        firm: firm,
      ),
      EmployeeDirectoryTab(
        uid: uid,
        userName: userName,
        userImage: userImage,
        firm: firm,
      ),
      EmployeeProfileTab(
        uid: uid,
        userName: userName,
        email: userEmail,
        firm: firm,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color.fromRGBO(22, 22, 22, 1),
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _navigateToTab,
          backgroundColor: const Color.fromRGBO(22, 22, 22, 1),
          indicatorColor: primaryColor.withValues(alpha: 0.22),
          elevation: 0,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined, color: Colors.grey),
              selectedIcon: Icon(Icons.home, color: primaryColor),
              label: 'Home',
            ),
            NavigationDestination(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.grey),
              selectedIcon: Icon(Icons.chat_bubble, color: primaryColor),
              label: 'Chats',
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_outline, color: Colors.grey),
              selectedIcon: Icon(Icons.people, color: primaryColor),
              label: 'Directory',
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline, color: Colors.grey),
              selectedIcon: Icon(Icons.person, color: primaryColor),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}