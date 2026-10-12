import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/firm.dart';
import '../providers/auth_provider.dart';
import '../widgets/chat/unified_chat_view.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserImage,
    this.firmId,
    this.firm,
  });

  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserImage;
  final String? firmId;
  final Firm? firm;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final currentUid = auth.currentUserId ?? '';
    final currentUserName = auth.user?.displayName ?? 'You';

    return UnifiedChatView(
      kind: UnifiedChatKind.direct,
      firmId: firmId ?? firm?.firmId,
      firm: firm,
      conversationId: conversationId,
      title: otherUserName,
      otherUserId: otherUserId,
      otherUserImage: otherUserImage,
      currentUid: currentUid,
      currentUserName: currentUserName,
      currentUserRole: 'employee',
      primaryColor: const Color.fromRGBO(41, 116, 188, 1),
    );
  }
}