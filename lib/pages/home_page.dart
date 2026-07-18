import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/db_service.dart';
import '../providers/firm/providers.dart';
import 'convo_page.dart';
import 'search_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FIX: Converted from StatelessWidget → StatefulWidget so that context.watch()
// can rebuild the widget whenever auth state changes (e.g. token becomes ready
// after login). context.read() in a StatelessWidget only runs once at build
// time, meaning the Firestore stream could launch before the auth token has
// propagated — causing permission-denied errors.
// ─────────────────────────────────────────────────────────────────────────────

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    // FIX: watch() instead of read() — rebuilds when auth state changes
    final auth = context.watch<AuthProvider>();
    final uid  = auth.currentUserId;
    final firm = ref.watch(currentFirmProvider);

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
        elevation: 0,
        title: Row(
          children: [
            if (firm?.logoUrl != null) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage(firm!.logoUrl!),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              firm?.name ?? 'ProntoChat',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            tooltip: 'New conversation',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserSearchPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.grey),
            tooltip: 'Sign out',
            onPressed: () => _confirmSignOut(context, auth),
          ),
        ],
      ),
      // FIX: Guard — don't open the Firestore stream until auth is FULLY
      // initialized. Checking uid == null alone isn't enough: Firebase can
      // fire _onAuthStateChanged with a user object before the token is
      // validated by Firestore, causing permission-denied. isInitializing
      // stays true until the full async sequence in _onAuthStateChanged
      // completes (profile load + lastSeen), guaranteeing the token is ready.
      body: uid == null || auth.isInitializing
          ? const Center(
              child: CircularProgressIndicator(
                color: Color.fromRGBO(41, 116, 188, 1),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: DBService.instance.streamConversations(uid),
              builder: (context, snapshot) {
                // ── Loading ────────────────────────────────────────────
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color.fromRGBO(41, 116, 188, 1),
                    ),
                  );
                }

                // ── Error ──────────────────────────────────────────────
                if (snapshot.hasError) {
                    debugPrint('🔥 FULL ERROR: ${snapshot.error}');
                    debugPrint('📚 FULL STACK:\n${snapshot.stackTrace}');
                    FlutterError.reportError(FlutterErrorDetails(
                      exception: snapshot.error!,
                      stack: snapshot.stackTrace,
                    ));

                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red[300], size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error.toString().split('\n').first}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                // ── Empty state ────────────────────────────────────────
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey[700]),
                        const SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the search icon to start one',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                // ── Conversation list ──────────────────────────────────
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => Divider(
                    color: Colors.grey[850],
                    height: 1,
                    indent: 76,
                  ),
                  itemBuilder: (context, index) {
                    final data =
                        docs[index].data() as Map<String, dynamic>;
                    return _ConversationTile(
                      data: data,
                      currentUid: uid, // FIX: uid is guaranteed non-null here
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromRGBO(41, 116, 188, 1),
        child: const Icon(Icons.edit, color: Colors.white),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserSearchPage()),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(
      BuildContext context, AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color.fromRGBO(40, 40, 40, 1),
        title:
            const Text('Sign out', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style:
                    TextStyle(color: Color.fromRGBO(41, 116, 188, 1))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) await auth.signOut();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Conversation tile — unchanged
// ─────────────────────────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.data,
    required this.currentUid,
  });

  final Map<String, dynamic> data;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    final String name        = data['name']        as String? ?? 'Unknown';
    final String image       = data['image']       as String? ?? '';
    final String lastMessage = data['lastMessage'] as String? ?? '';
    final int unseenCount    = (data['unseenCount'] as num?)?.toInt() ?? 0;
    final Timestamp? ts      = data['timestamp']   as Timestamp?;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: const Color.fromRGBO(41, 116, 188, 0.3),
        backgroundImage: image.isNotEmpty ? NetworkImage(image) : null,
        child: image.isEmpty
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Color.fromRGBO(41, 116, 188, 1),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              )
            : null,
      ),
      title: Text(
        name,
        style: TextStyle(
          color: Colors.white,
          fontWeight:
              unseenCount > 0 ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: unseenCount > 0 ? Colors.white70 : Colors.grey[600],
          fontWeight:
              unseenCount > 0 ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTimestamp(ts),
            style: TextStyle(
              fontSize: 12,
              color: unseenCount > 0
                  ? const Color.fromRGBO(41, 116, 188, 1)
                  : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          if (unseenCount > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(41, 116, 188, 1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unseenCount > 99 ? '99+' : '$unseenCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            const SizedBox(height: 18),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: data['chatId'] as String,
            otherUserId: _otherUid(data['chatId'] as String, currentUid),
            otherUserName: name,
            otherUserImage: image,
          ),
        ),
      ),
    );
  }

  String _otherUid(String conversationId, String myUid) {
    final parts = conversationId.split('_');
    if (parts.length != 2) return '';
    return parts[0] == myUid ? parts[1] : parts[0];
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final dt  = ts.toDate();
    final now = DateTime.now();
    final isToday = dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;
    if (isToday) {
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}';
  }
}