import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../services/db_service.dart';
import '../../theme/pc_tokens.dart';

class ChatSearchSheet extends StatefulWidget {
  final String? firmId;
  final String conversationId;
  final List<ChatMessage> cachedMessages;
  final List<Map<String, String>> participants;
  final Color primaryColor;
  final ValueChanged<ChatMessage> onSelectMessage;

  const ChatSearchSheet({
    super.key,
    this.firmId,
    required this.conversationId,
    required this.cachedMessages,
    required this.participants,
    required this.primaryColor,
    required this.onSelectMessage,
  });

  @override
  State<ChatSearchSheet> createState() => _ChatSearchSheetState();
}

class _ChatSearchSheetState extends State<ChatSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  String? _selectedSenderId;
  DateTimeRange? _selectedDateRange;

  bool _isSearching = false;
  bool _isSearchingOlder = false;
  int _olderDocsReadCount = 0;
  static const int kMaxOlderDocsBudget = 300;
  DocumentSnapshot? _lastOlderDoc;
  bool _reachedOlderBudgetOrEnd = false;

  List<ChatMessage> _results = [];
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    _debounceTimer?.cancel();

    if (query.length < 3) {
      setState(() {
        _currentQuery = query;
        _results = [];
        _isSearching = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    setState(() {
      _currentQuery = query;
      _isSearching = true;
    });

    final lowerQuery = query.toLowerCase();
    final queryWords = lowerQuery
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2)
        .toList();

    final Map<String, ChatMessage> resultMap = {};

    for (final msg in widget.cachedMessages) {
      if (msg.deleted) continue;
      if (_matchesFilters(msg, lowerQuery, queryWords)) {
        resultMap[msg.messageId] = msg;
      }
    }

    if (queryWords.isNotEmpty) {
      try {
        final firstWord = queryWords.first;
        final serverDocs = await DBService.instance.searchMessagesServer(
          firmId: widget.firmId,
          conversationId: widget.conversationId,
          queryWord: firstWord,
          limit: 20,
        );

        for (final doc in serverDocs) {
          final msg = ChatMessage.fromMap(doc.data(), doc.id);
          if (msg.deleted) continue;
          if (_matchesFilters(msg, lowerQuery, queryWords)) {
            resultMap[msg.messageId] = msg;
          }
        }
      } catch (e) {
        debugPrint('Notice server search: $e');
      }
    }

    final sortedResults = resultMap.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (mounted) {
      setState(() {
        _results = sortedResults;
        _isSearching = false;
      });
    }
  }

  bool _matchesFilters(
    ChatMessage msg,
    String rawQuery,
    List<String> queryWords,
  ) {
    if (_selectedSenderId != null && msg.senderId != _selectedSenderId) {
      return false;
    }

    if (_selectedDateRange != null) {
      final msgDate = msg.timestamp;
      final start = _selectedDateRange!.start;
      final end = _selectedDateRange!.end.add(const Duration(days: 1));
      if (msgDate.isBefore(start) || msgDate.isAfter(end)) {
        return false;
      }
    }

    final String contentToMatch = (msg.type == 'poll' && msg.poll != null)
        ? '${msg.text} ${msg.poll!.question} ${msg.poll!.options.map((o) => o.text).join(' ')}'
            .toLowerCase()
        : msg.text.toLowerCase();

    if (contentToMatch.contains(rawQuery)) return true;

    if (queryWords.isNotEmpty &&
        queryWords.every((w) => contentToMatch.contains(w))) {
      return true;
    }

    return false;
  }

  Future<void> _searchOlderHistory() async {
    if (_isSearchingOlder || _reachedOlderBudgetOrEnd) return;
    setState(() => _isSearchingOlder = true);

    try {
      const int batchSize = 50;
      final docs = await DBService.instance.searchOlderMessagesHistory(
        firmId: widget.firmId,
        conversationId: widget.conversationId,
        lastVisibleDoc: _lastOlderDoc,
        limit: batchSize,
      );

      _olderDocsReadCount += docs.length;
      if (docs.isEmpty || _olderDocsReadCount >= kMaxOlderDocsBudget) {
        _reachedOlderBudgetOrEnd = true;
      }
      if (docs.isNotEmpty) {
        _lastOlderDoc = docs.last;
      }

      final lowerQuery = _currentQuery.toLowerCase();
      final queryWords = lowerQuery
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 2)
          .toList();

      final Map<String, ChatMessage> currentMap = {
        for (final m in _results) m.messageId: m,
      };
      for (final doc in docs) {
        final msg = ChatMessage.fromMap(doc.data(), doc.id);
        if (msg.deleted) continue;
        if (_matchesFilters(msg, lowerQuery, queryWords)) {
          currentMap[msg.messageId] = msg;
        }
      }

      final sorted = currentMap.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (mounted) {
        setState(() {
          _results = sorted;
        });
      }
    } catch (e) {
      debugPrint('Notice search older messages: $e');
    } finally {
      if (mounted) setState(() => _isSearchingOlder = false);
    }
  }

  Widget _buildHighlightedSnippet(String text, String query, PcTokens tokens) {
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: tokens.textSecondary, fontSize: 13),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: tokens.textSecondary, fontSize: 13),
      );
    }

    int startSnippet = (index - 25).clamp(0, text.length);
    int endSnippet = (index + query.length + 35).clamp(0, text.length);

    final prefix = startSnippet > 0 ? '...' : '';
    final suffix = endSnippet < text.length ? '...' : '';

    final snippetText = text.substring(startSnippet, endSnippet);
    final snippetLower = snippetText.toLowerCase();
    final matchStartInSnippet = snippetLower.indexOf(lowerQuery);

    if (matchStartInSnippet == -1) {
      return Text(
        prefix + snippetText + suffix,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: tokens.textSecondary, fontSize: 13),
      );
    }

    final before = snippetText.substring(0, matchStartInSnippet);
    final match = snippetText.substring(
      matchStartInSnippet,
      matchStartInSnippet + query.length,
    );
    final after = snippetText.substring(matchStartInSnippet + query.length);

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(color: tokens.textSecondary, fontSize: 13),
        children: [
          if (prefix.isNotEmpty) TextSpan(text: prefix),
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: TextStyle(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w700,
              backgroundColor: tokens.warningSoft,
            ),
          ),
          TextSpan(text: after),
          if (suffix.isNotEmpty) TextSpan(text: suffix),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pcTokens;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.85,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: tokens.borderStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tokens.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: tokens.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'Search inside this chat (min 3 chars)...',
                              hintStyle: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 13,
                              ),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() {
                                _results = [];
                                _currentQuery = '';
                              });
                            },
                            child: Icon(
                              Icons.close_rounded,
                              color: tokens.textMuted,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: tokens.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                PopupMenuButton<String?>(
                  tooltip: 'Filter by sender',
                  color: tokens.surface,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedSenderId != null
                          ? tokens.primarySoft
                          : tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedSenderId != null
                            ? tokens.primaryBorder
                            : tokens.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 14,
                          color: _selectedSenderId != null
                              ? tokens.primary
                              : tokens.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedSenderId != null
                              ? (widget.participants.firstWhere(
                                    (p) => p['uid'] == _selectedSenderId,
                                    orElse: () => {'name': 'Member'},
                                  )['name'] ??
                                  'Member')
                              : 'Sender',
                          style: TextStyle(
                            color: _selectedSenderId != null
                                ? tokens.primary
                                : tokens.textSecondary,
                            fontSize: 12,
                            fontWeight: _selectedSenderId != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 16,
                          color: tokens.textMuted,
                        ),
                      ],
                    ),
                  ),
                  onSelected: (val) {
                    setState(() => _selectedSenderId = val);
                    if (_currentQuery.length >= 3) {
                      _executeSearch(_currentQuery);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem<String?>(
                      value: null,
                      child: Text(
                        'All Senders',
                        style: TextStyle(color: tokens.textPrimary),
                      ),
                    ),
                    ...widget.participants.map(
                      (p) => PopupMenuItem<String?>(
                        value: p['uid'],
                        child: Text(
                          p['name'] ?? 'Colleague',
                          style: TextStyle(color: tokens.textPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _selectedDateRange = picked);
                      if (_currentQuery.length >= 3) {
                        _executeSearch(_currentQuery);
                      }
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedDateRange != null
                          ? tokens.primarySoft
                          : tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedDateRange != null
                            ? tokens.primaryBorder
                            : tokens.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 13,
                          color: _selectedDateRange != null
                              ? tokens.primary
                              : tokens.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedDateRange != null
                              ? '${_selectedDateRange!.start.month}/${_selectedDateRange!.start.day} - ${_selectedDateRange!.end.month}/${_selectedDateRange!.end.day}'
                              : 'Date Range',
                          style: TextStyle(
                            color: _selectedDateRange != null
                                ? tokens.primary
                                : tokens.textSecondary,
                            fontSize: 12,
                            fontWeight: _selectedDateRange != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        if (_selectedDateRange != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() => _selectedDateRange = null);
                              if (_currentQuery.length >= 3) {
                                _executeSearch(_currentQuery);
                              }
                            },
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: tokens.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Divider(color: tokens.border, height: 1),
          ),
          Expanded(
            child: _isSearching
                ? Center(
                    child: CircularProgressIndicator(
                      color: widget.primaryColor,
                    ),
                  )
                : _currentQuery.length < 3
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 46,
                              color: tokens.textMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Type at least 3 characters to search',
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Searches local messages first, then server index',
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.find_in_page_outlined,
                                  size: 46,
                                  color: tokens.textMuted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No messages matching "$_currentQuery"',
                                  style: TextStyle(
                                    color: tokens.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (!_reachedOlderBudgetOrEnd)
                                  ElevatedButton.icon(
                                    onPressed: _searchOlderHistory,
                                    icon: const Icon(Icons.history, size: 16),
                                    label: Text(
                                      _isSearchingOlder
                                          ? 'Searching older messages...'
                                          : 'Search older messages (limit $kMaxOlderDocsBudget docs)',
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _results.length + 1,
                            separatorBuilder: (_, _) =>
                                Divider(color: tokens.border, height: 1),
                            itemBuilder: (ctx, index) {
                              if (index == _results.length) {
                                if (_reachedOlderBudgetOrEnd) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Center(
                                      child: Text(
                                        'Search budget cap reached ($_olderDocsReadCount docs read).',
                                        style: TextStyle(
                                          color: tokens.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 20,
                                  ),
                                  child: OutlinedButton.icon(
                                    onPressed: _isSearchingOlder
                                        ? null
                                        : _searchOlderHistory,
                                    icon: _isSearchingOlder
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.history, size: 16),
                                    label: Text(
                                      _isSearchingOlder
                                          ? 'Reading older history...'
                                          : 'Search older messages (read $_olderDocsReadCount/$kMaxOlderDocsBudget)',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                );
                              }

                              final msg = _results[index];
                              final isPoll = msg.type == 'poll';
                              final textToShow = isPoll
                                  ? '📊 ${msg.poll?.question ?? msg.text}'
                                  : msg.text;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isPoll
                                      ? tokens.projectSoft
                                      : tokens.primarySoft,
                                  child: Icon(
                                    isPoll
                                        ? Icons.poll_rounded
                                        : Icons.chat_bubble_outline_rounded,
                                    color: isPoll
                                        ? tokens.projectAccent
                                        : widget.primaryColor,
                                    size: 18,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        msg.senderName.isNotEmpty
                                            ? msg.senderName
                                            : 'Colleague',
                                        style: TextStyle(
                                          color: tokens.textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${msg.timestamp.month}/${msg.timestamp.day} ${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        color: tokens.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: _buildHighlightedSnippet(
                                    textToShow,
                                    _currentQuery,
                                    tokens,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  widget.onSelectMessage(msg);
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
