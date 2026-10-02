import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'models/chat_message.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Try initializing Firebase, but don't fail if offline or running in mock mode
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase init note (standalone test mode): $e');
  }

  runApp(
    const ProviderScope(
      child: MessagingTestApp(),
    ),
  );
}

class MessagingTestApp extends StatefulWidget {
  const MessagingTestApp({super.key});

  @override
  State<MessagingTestApp> createState() => _MessagingTestAppState();
}

class _MessagingTestAppState extends State<MessagingTestApp> {
  Color _brandColor = const Color(0xFF2974BC); // Pronto Blue
  String _activeTab = 'team'; // 'team' or 'direct'

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProntoChat - Messaging Test Suite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color.fromRGBO(28, 27, 27, 1),
        colorScheme: ColorScheme.dark(
          primary: _brandColor,
          secondary: _brandColor.withValues(alpha: 0.8),
          surface: const Color.fromRGBO(38, 37, 37, 1),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromRGBO(28, 27, 27, 1),
          elevation: 0,
        ),
      ),
      home: Scaffold(
        body: Column(
          children: [
            // Top Test Banner & Controls
            _buildTestControlHeader(),

            // Chat View
            Expanded(
              child: _activeTab == 'team'
                  ? TeamChatTestHarness(brandColor: _brandColor)
                  : DirectChatTestHarness(brandColor: _brandColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestControlHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(20, 20, 20, 1),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: Colors.greenAccent),
                      SizedBox(width: 4),
                      Text(
                        'TEST MODE: MESSAGING HARNESS',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Channel selector
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'team',
                      label: Text('Team Chat'),
                      icon: Icon(Icons.groups, size: 16),
                    ),
                    ButtonSegment(
                      value: 'direct',
                      label: Text('1-on-1 DM'),
                      icon: Icon(Icons.person, size: 16),
                    ),
                  ],
                  selected: {_activeTab},
                  onSelectionChanged: (set) {
                    setState(() => _activeTab = set.first);
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Tenant Brand Theme:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                _colorChip(const Color(0xFF2974BC), 'Pronto Blue'),
                const SizedBox(width: 6),
                _colorChip(const Color(0xFF10B981), 'Emerald'),
                const SizedBox(width: 6),
                _colorChip(const Color(0xFF8B5CF6), 'Purple'),
                const SizedBox(width: 6),
                _colorChip(const Color(0xFFF43F5E), 'Rose'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorChip(Color color, String name) {
    final isSelected = _brandColor == color;
    return InkWell(
      onTap: () => setState(() => _brandColor = color),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isSelected ? 0.3 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 5, backgroundColor: color),
            const SizedBox(width: 5),
            Text(
              name,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEAM CHAT HARNESS (FirmChatScreen UI & Logic)
// ─────────────────────────────────────────────────────────────────────────────
class TeamChatTestHarness extends StatefulWidget {
  final Color brandColor;

  const TeamChatTestHarness({super.key, required this.brandColor});

  @override
  State<TeamChatTestHarness> createState() => _TeamChatTestHarnessState();
}

class _TeamChatTestHarnessState extends State<TeamChatTestHarness> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _currentUid = 'user_alex_101';
  final String _currentUserName = 'Alex Morgan';

  // Seed sample team conversation
  late List<ChatMessage> _messages;
  bool _autoReply = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _messages = [
      ChatMessage(
        messageId: 'm4',
        senderId: 'user_sarah_102',
        senderName: 'Sarah Jenkins',
        text: 'The new multi-tenant branding tokens look great! Ready for testing.',
        timestamp: now.subtract(const Duration(minutes: 2)),
      ),
      ChatMessage(
        messageId: 'm3',
        senderId: 'user_david_103',
        senderName: 'David Kim (Engineering)',
        text: 'CSV bulk onboarding and deep link listeners are live on staging.',
        timestamp: now.subtract(const Duration(minutes: 5)),
      ),
      ChatMessage(
        messageId: 'm2',
        senderId: _currentUid,
        senderName: _currentUserName,
        text: 'Awesome work team! Let\'s verify real-time message streaming now.',
        timestamp: now.subtract(const Duration(minutes: 8)),
      ),
      ChatMessage(
        messageId: 'm1',
        senderId: 'user_sarah_102',
        senderName: 'Sarah Jenkins',
        text: 'Welcome to the Acme Corp workspace!',
        timestamp: now.subtract(const Duration(minutes: 15)),
      ),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    final newMsg = ChatMessage(
      messageId: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _currentUid,
      senderName: _currentUserName,
      text: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.insert(0, newMsg); // Reverse order for reverse list
    });

    _scrollToBottom();

    // Automated colleague simulation reply if enabled
    if (_autoReply) {
      Timer(const Duration(seconds: 1), () {
        if (!mounted) return;
        final replies = [
          'Received! Looks crystal clear on my end.',
          'Got it! Synchronized perfectly.',
          'Great point, I\'ll update the ticket accordingly 👍',
          'Testing confirmation: message delivery latency < 100ms.',
        ];
        final replyText = replies[_messages.length % replies.length];
        setState(() {
          _messages.insert(
            0,
            ChatMessage(
              messageId: 'bot_${DateTime.now().millisecondsSinceEpoch}',
              senderId: 'user_sarah_102',
              senderName: 'Sarah Jenkins',
              text: replyText,
              timestamp: DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Firm Header Bar (as in FirmChatScreen)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color.fromRGBO(28, 27, 27, 1),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: widget.brandColor.withValues(alpha: 0.2),
                child: Text(
                  'A',
                  style: TextStyle(
                    color: widget.brandColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acme Corp Workspace',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '#general • 3 members online',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
              const Spacer(),
              // Auto-reply switch
              Tooltip(
                message: 'Auto-reply simulation from colleague',
                child: Row(
                  children: [
                    Text(
                      'Bot Reply: ',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                    Switch(
                      value: _autoReply,
                      activeThumbColor: widget.brandColor,
                      onChanged: (val) => setState(() => _autoReply = val),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white12),

        // Message List
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isMine = msg.senderId == _currentUid;
              return _buildMessageRow(msg, isMine);
            },
          ),
        ),

        // Input Bar
        _buildInputArea(),
      ],
    );
  }

  Widget _buildMessageRow(ChatMessage msg, bool isMine) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMine)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                msg.senderName,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isMine ? widget.brandColor : Colors.grey[850],
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMine ? const Radius.circular(16) : Radius.zero,
                    bottomRight: isMine ? Radius.zero : const Radius.circular(16),
                  ),
                ),
                child: Text(
                  msg.text,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
            child: Text(
              _formatTime(msg.timestamp),
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color.fromRGBO(20, 20, 20, 1),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type a message in Acme Corp...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: const Color.fromRGBO(32, 32, 32, 1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: widget.brandColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIRECT 1-ON-1 CHAT HARNESS (ChatPage UI & Logic)
// ─────────────────────────────────────────────────────────────────────────────
class DirectChatTestHarness extends StatefulWidget {
  final Color brandColor;

  const DirectChatTestHarness({super.key, required this.brandColor});

  @override
  State<DirectChatTestHarness> createState() => _DirectChatTestHarnessState();
}

class _DirectChatTestHarnessState extends State<DirectChatTestHarness> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _directMessages = [
    {
      'sender': 'Sarah Jenkins',
      'isMine': false,
      'text': 'Hi Alex, did you check the updated design tokens?',
      'time': '10:42 AM',
      'seen': true,
    },
    {
      'sender': 'Alex Morgan',
      'isMine': true,
      'text': 'Yes! The responsive layout and dark themes look super clean.',
      'time': '10:44 AM',
      'seen': true,
    },
  ];

  void _sendDirectMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _directMessages.add({
        'sender': 'Alex Morgan',
        'isMine': true,
        'text': text,
        'time': 'Just now',
        'seen': false,
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Auto-reply
    Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _directMessages.add({
          'sender': 'Sarah Jenkins',
          'isMine': false,
          'text': 'Acknowledged! Testing the direct channel sync.',
          'time': 'Just now',
          'seen': true,
        });
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1-on-1 Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color.fromRGBO(28, 27, 27, 1),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.purple,
                child: Text('SJ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sarah Jenkins',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      CircleAvatar(radius: 4, backgroundColor: Colors.greenAccent),
                      SizedBox(width: 4),
                      Text('Online', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.call_outlined, color: Colors.grey),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.videocam_outlined, color: Colors.grey),
                onPressed: () {},
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white12),

        // Messages
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _directMessages.length,
            itemBuilder: (context, index) {
              final msg = _directMessages[index];
              final isMine = msg['isMine'] as bool;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.72,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMine ? widget.brandColor : Colors.grey[850],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            msg['text'] as String,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                msg['time'] as String,
                                style: TextStyle(color: Colors.grey[400], fontSize: 10),
                              ),
                              if (isMine) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  (msg['seen'] as bool) ? Icons.done_all : Icons.done,
                                  size: 13,
                                  color: (msg['seen'] as bool) ? Colors.blueAccent : Colors.grey,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Input Area
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color.fromRGBO(20, 20, 20, 1),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Direct message Sarah...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: const Color.fromRGBO(32, 32, 32, 1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendDirectMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: widget.brandColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendDirectMessage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
