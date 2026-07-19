import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/firm/providers.dart';
import '../screens/employee/firm_chat_screen.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final uid  = auth.currentUserId;
    final firm = ref.watch(currentFirmProvider);

    if (uid == null || firm == null) {
      return const Scaffold(
        backgroundColor: Color.fromRGBO(28, 27, 27, 1),
        body: Center(
          child: CircularProgressIndicator(
            color: Color.fromRGBO(41, 116, 188, 1),
          ),
        ),
      );
    }

    return FirmChatScreen(
      firmId: firm.firmId,
      uid: uid,
      name: auth.currentUserName,
    );
  }
}