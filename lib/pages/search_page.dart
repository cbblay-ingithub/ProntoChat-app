import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/db_service.dart';
import '../theme/pc_tokens.dart';
import 'convo_page.dart';

class UserSearchPage extends StatefulWidget {
  const UserSearchPage({super.key});

  @override
  State<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _creatingConvFor;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    _search(query);
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);

    final currentUid = context.read<AuthProvider>().currentUserId!;
    final results = await DBService.instance.searchUsers(query);
    final filtered = results.where((u) => u['uid'] != currentUid).toList();

    if (mounted) {
      setState(() {
        _results = filtered;
        _isLoading = false;
        _hasSearched = true;
      });
    }
  }

  Future<void> _openOrCreateChat(
    BuildContext context,
    Map<String, dynamic> otherUser,
  ) async {
    final auth = context.read<AuthProvider>();
    setState(() => _creatingConvFor = otherUser['uid'] as String);

    try {
      final conversationId = await DBService.instance.createConversation(
        currentUid: auth.currentUserId!,
        otherUid: otherUser['uid'] as String,
        currentUserName: auth.currentUserName,
        currentUserImage: auth.currentUserImage,
        otherUserName: otherUser['name'] as String? ?? '',
        otherUserImage: otherUser['image'] as String? ?? '',
      );

      if (!context.mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversationId,
            otherUserId: otherUser['uid'] as String,
            otherUserName: otherUser['name'] as String? ?? '',
            otherUserImage: otherUser['image'] as String? ?? '',
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open chat. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creatingConvFor = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pcTokens;

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        backgroundColor: tokens.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: tokens.border),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: tokens.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(color: tokens.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search by name…',
            hintStyle: TextStyle(color: tokens.textMuted),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear_rounded, color: tokens.textMuted),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _results = [];
                  _hasSearched = false;
                });
              },
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _buildBody(tokens),
        ),
      ),
    );
  }

  Widget _buildBody(PcTokens tokens) {
    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_rounded, size: 52, color: tokens.textMuted),
            const SizedBox(height: 12),
            Text(
              'Search for someone to chat with',
              style: TextStyle(color: tokens.textMuted, fontSize: 15),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: tokens.primary),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          'No users found for "${_searchController.text}"',
          style: TextStyle(color: tokens.textMuted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final user = _results[index];
        final uid = user['uid'] as String? ?? '';
        final name = user['name'] as String? ?? 'Unknown';
        final image = user['image'] as String? ?? '';
        final isCreating = _creatingConvFor == uid;

        return Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tokens.border),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: tokens.primarySoft,
              backgroundImage: image.isNotEmpty ? NetworkImage(image) : null,
              child: image.isEmpty
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: tokens.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            title: Text(
              name,
              style: TextStyle(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              user['email'] as String? ?? '',
              style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
            ),
            trailing: isCreating
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tokens.primary,
                    ),
                  )
                : Icon(Icons.chevron_right_rounded, color: tokens.textMuted),
            onTap: isCreating ? null : () => _openOrCreateChat(context, user),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
}
