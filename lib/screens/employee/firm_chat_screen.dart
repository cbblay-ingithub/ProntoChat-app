import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/firm.dart';
import '../../services/db_service.dart';
import '../../widgets/chat/unified_chat_view.dart';

class FirmChatScreen extends StatefulWidget {
  final String firmId;
  final String uid;
  final String name;

  const FirmChatScreen({
    super.key,
    required this.firmId,
    required this.uid,
    required this.name,
  });

  @override
  State<FirmChatScreen> createState() => _FirmChatScreenState();
}

class _FirmChatScreenState extends State<FirmChatScreen> {
  @override
  void initState() {
    super.initState();
    DBService.instance.ensureGeneralChannel(widget.firmId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: DBService.instance.streamMember(widget.firmId, widget.uid),
      builder: (context, memberSnap) {
        final memberData = memberSnap.data?.data() ?? {};
        final userRole = memberData['role'] as String? ?? 'employee';

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('Firms').doc(widget.firmId).snapshots(),
          builder: (context, firmSnap) {
            Firm? firm;
            if (firmSnap.hasData && firmSnap.data!.exists) {
              firm = Firm.fromFirestore(firmSnap.data!);
            }
            final firmName = firm?.name ?? 'Workspace';

            return UnifiedChatView(
              kind: UnifiedChatKind.general,
              firmId: widget.firmId,
              firm: firm,
              conversationId: widget.firmId,
              title: firmName,
              subtitle: 'General Team Chat',
              currentUid: widget.uid,
              currentUserName: widget.name,
              currentUserRole: userRole,
              primaryColor: primaryColor,
              canPost: true,
            );
          },
        );
      },
    );
  }
}
