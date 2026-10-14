import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../services/db_service.dart';

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

    // ── STAGE 1: Device-first search in memory (0 Firestore reads) ─────────
    final Map<String, ChatMessage> resultMap = {};

    for (final msg in widget.cachedMessages) {
      if (msg.deleted) continue;
      if (_matchesFilters(msg, lowerQuery, queryWords)) {
        resultMap[msg.messageId] = msg;
      }
    }

    // ── STAGE 2: Server query by searchTokens (20 docs per batch) ─────────
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

  bool _matchesFilters(ChatMessage msg, String rawQuery, List<String> queryWords) {
    // 1. Sender filter
    if (_selectedSenderId != null && msg.senderId != _selectedSenderId) {
      return false;
    }

    // 2. Date range filter
    if (_selectedDateRange != null) {
      final msgDate = msg.timestamp;
      final start = _selectedDateRange!.start;
      final end = _selectedDateRange!.end.add(const Duration(days: 1));
      if (msgDate.isBefore(start) || msgDate.isAfter(end)) {
        return false;
      }
    }

    // 3. Text & poll matches
    final String contentToMatch = (msg.type == 'poll' && msg.poll != null)
        ? '${msg.text} ${msg.poll!.question} ${msg.poll!.options.map((o) => o.text).join(' ')}'.toLowerCase()
        : msg.text.toLowerCase();

    // Check substring match
    if (contentToMatch.contains(rawQuery)) return true;

    // Check token set matches
    if (queryWords.isNotEmpty && queryWords.every((w) => contentToMatch.contains(w))) {
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
      final queryWords = lowerQuery.split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();

      final Map<String, ChatMessage> currentMap = {for (final m in _results) m.messageId: m};
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

  Widget _buildHighlightedSnippet(String text, String query) {
    if (query.isEmpty) {
      return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13));
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) {
      return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13));
    }

    int startSnippet = (index - 25).clamp(0, text.length);
    int endSnippet = (index + query.length + 35).clamp(0, text.length);

    final prefix = startSnippet > 0 ? '...' : '';
    final suffix = endSnippet < text.length ? '...' : '';

    final snippetText = text.substring(startSnippet, endSnippet);
    final snippetLower = snippetText.toLowerCase();
    final matchStartInSnippet = snippetLower.indexOf(lowerQuery);

    if (matchStartInSnippet == -1) {
      return Text(prefix + snippetText + suffix, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13));
    }

    final before = snippetText.substring(0, matchStartInSnippet);
    final match = snippetText.substring(matchStartInSnippet, matchStartInSnippet + query.length);
    final after = snippetText.substring(matchStartInSnippet + query.length);

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(color: Colors.white70, fontSize: 13),
        children: [
          if (prefix.isNotEmpty) TextSpan(text: prefix),
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: const TextStyle(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
              backgroundColor: Color(0x33FFD700),
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color.fromRGBO(24, 23, 24, 1),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Search input bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(38, 37, 40, 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Search inside this chat (min 3 chars)...',
                              hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                              border: InputBorder.none,
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
                            child: const Icon(Icons.close, color: Colors.grey, size: 18),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Filters Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                // Sender Filter
                PopupMenuButton<String?>(
                  tooltip: 'Filter by sender',
                  color: const Color.fromRGBO(38, 37, 40, 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedSenderId != null
                          ? widget.primaryColor.withOpacity(0.2)
                          : const Color.fromRGBO(34, 33, 35, 1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedSenderId != null ? widget.primaryColor : Colors.white12,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person,
                          size: 14,
                          color: _selectedSenderId != null ? widget.primaryColor : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedSenderId != null
                              ? (widget.participants.firstWhere(
                                  (p) => p['uid'] == _selectedSenderId,
                                  orElse: () => {'name': 'Member'},
                                )['name'] ?? 'Member')
                              : 'Sender',
                          style: TextStyle(
                            color: _selectedSenderId != null ? Colors.white : Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                  onSelected: (val) {
                    setState(() => _selectedSenderId = val);
                    if (_currentQuery.length >= 3) _executeSearch(_currentQuery);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem<String?>(
                      value: null,
                      child: Text('All Senders', style: TextStyle(color: Colors.white)),
                    ),
                    ...widget.participants.map(
                      (p) => PopupMenuItem<String?>(
                        value: p['uid'],
                        child: Text(p['name'] ?? 'Colleague', style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),

                // Date Filter
                GestureDetector(
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: widget.primaryColor,
                              surface: const Color.fromRGBO(34, 33, 35, 1),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() => _selectedDateRange = picked);
                      if (_currentQuery.length >= 3) _executeSearch(_currentQuery);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedDateRange != null
                          ? widget.primaryColor.withOpacity(0.2)
                          : const Color.fromRGBO(34, 33, 35, 1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedDateRange != null ? widget.primaryColor : Colors.white12,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 13,
                          color: _selectedDateRange != null ? widget.primaryColor : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedDateRange != null
                              ? '${_selectedDateRange!.start.month}/${_selectedDateRange!.start.day} - ${_selectedDateRange!.end.month}/${_selectedDateRange!.end.day}'
                              : 'Date Range',
                          style: TextStyle(
                            color: _selectedDateRange != null ? Colors.white : Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                        if (_selectedDateRange != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() => _selectedDateRange = null);
                              if (_currentQuery.length >= 3) _executeSearch(_currentQuery);
                            },
                            child: const Icon(Icons.close, size: 14, color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 12),

          // Search state & Results list
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _currentQuery.length < 3
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search, size: 48, color: Colors.grey[700]),
                            const SizedBox(height: 12),
                            Text(
                              'Type at least 3 characters to search',
                              style: TextStyle(color: Colors.grey[500], fontSize: 14),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Searches local messages first, then server index',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.find_in_page_outlined, size: 48, color: Colors.grey[600]),
                                const SizedBox(height: 12),
                                Text(
                                  'No messages matching "$_currentQuery"',
                                  style: const TextStyle(color: Colors.white70, fontSize: 14),
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
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: widget.primaryColor.withOpacity(0.3),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _results.length + 1,
                            separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                            itemBuilder: (ctx, index) {
                              if (index == _results.length) {
                                // Bottom footer for Stage 3 search
                                if (_reachedOlderBudgetOrEnd) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Center(
                                      child: Text(
                                        'Search budget cap reached ($_olderDocsReadCount docs read).',
                                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                      ),
                                    ),
                                  );
                                }

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                                  child: OutlinedButton.icon(
                                    onPressed: _isSearchingOlder ? null : _searchOlderHistory,
                                    icon: _isSearchingOlder
                                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Icon(Icons.history, size: 16),
                                    label: Text(
                                      _isSearchingOlder
                                          ? 'Reading older history...'
                                          : 'Search older messages (read $_olderDocsReadCount/$kMaxOlderDocsBudget)',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.grey[400],
                                      side: const BorderSide(color: Colors.white12),
                                    ),
                                  ),
                                );
                              }

                              final msg = _results[index];
                              final isPoll = msg.type == 'poll';
                              final textToShow = isPoll ? '📊 ${msg.poll?.question ?? msg.text}' : msg.text;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isPoll ? Colors.purpleAccent.withOpacity(0.2) : widget.primaryColor.withOpacity(0.2),
                                  child: Icon(
                                    isPoll ? Icons.poll : Icons.chat_bubble_outline,
                                    color: isPoll ? Colors.purpleAccent : widget.primaryColor,
                                    size: 18,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        msg.senderName.isNotEmpty ? msg.senderName : 'Colleague',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${msg.timestamp.month}/${msg.timestamp.day} ${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: _buildHighlightedSnippet(textToShow, _currentQuery),
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
