import '../widgets/chat/unified_chat_view.dart';

/// Represents an active channel, project group, or direct conversation
/// selected inside the multi-pane Web/Desktop Employee Workspace shell.
class ActiveChatSelection {
  final UnifiedChatKind kind;
  final String conversationId;
  final String title;
  final String? subtitle;
  final String? otherUserId;
  final String? otherUserImage;
  final String? departmentId;
  final String? projectId;
  final String? projectOwnerUid;

  const ActiveChatSelection({
    required this.kind,
    required this.conversationId,
    required this.title,
    this.subtitle,
    this.otherUserId,
    this.otherUserImage,
    this.departmentId,
    this.projectId,
    this.projectOwnerUid,
  });

  factory ActiveChatSelection.general(String firmId, String firmName) {
    return ActiveChatSelection(
      kind: UnifiedChatKind.general,
      conversationId: firmId,
      title: firmName,
      subtitle: 'General Team Chat',
    );
  }

  factory ActiveChatSelection.allStaff() {
    return const ActiveChatSelection(
      kind: UnifiedChatKind.allStaff,
      conversationId: 'all_staff',
      title: '#all-staff',
      subtitle: 'Official announcements',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActiveChatSelection &&
        other.kind == kind &&
        other.conversationId == conversationId;
  }

  @override
  int get hashCode => Object.hash(kind, conversationId);
}
