import 'package:flutter_test/flutter_test.dart';
import 'package:pronto_chat/models/poll_model.dart';
import 'package:pronto_chat/models/mention_inbox_item.dart';
import 'package:pronto_chat/utils/search_token_util.dart';

void main() {
  group('Search Token Generator (Part A)', () {
    test('generates lowercase tokens >= 2 chars, strips punctuation, caps at 30', () {
      const text = 'Hello world! This is a test: searching in-app messages quickly & cleanly...';
      final tokens = SearchTokenUtil.generateTokens(text: text);

      expect(tokens.contains('hello'), isTrue);
      expect(tokens.contains('world'), isTrue);
      expect(tokens.contains('searching'), isTrue);
      expect(tokens.contains('messages'), isTrue);
      expect(tokens.contains('app'), isTrue);
      // Single character token should be filtered out
      expect(tokens.contains('a'), isFalse);
      expect(tokens.length, lessThanOrEqualTo(30));
    });

    test('indexes poll question and option labels for searchability', () {
      final poll = PollModel(
        question: 'What time is the team lunch?',
        options: const [
          PollOption(id: 'opt_1', text: '12:00 PM Pizza'),
          PollOption(id: 'opt_2', text: '1:00 PM Sushi Bar'),
        ],
        optionIds: const ['opt_1', 'opt_2'],
        createdBy: 'user_alice',
      );

      final tokens = SearchTokenUtil.generateTokens(text: 'Hey team, vote below!', poll: poll);
      expect(tokens.contains('lunch'), isTrue);
      expect(tokens.contains('pizza'), isTrue);
      expect(tokens.contains('sushi'), isTrue);
    });
  });

  group('Mentions Inbox Models (Part B)', () {
    test('serializes and deserializes MentionInboxItem properly', () {
      final now = DateTime.now();
      final item = MentionInboxItem(
        messageId: 'msg_999',
        conversationId: 'dept_engineering',
        senderId: 'user_bob',
        senderName: 'Bob Builder',
        snippet: 'Hey @Alice check out this commit!',
        createdAt: now,
        read: false,
      );

      final map = item.toMap();
      expect(map['messageId'], 'msg_999');
      expect(map['conversationId'], 'dept_engineering');
      expect(map['read'], false);
      expect(map['senderName'], 'Bob Builder');

      final restored = MentionInboxItem.fromMap('msg_999', map);
      expect(restored.messageId, 'msg_999');
      expect(restored.conversationId, 'dept_engineering');
      expect(restored.read, false);
      expect(restored.snippet, 'Hey @Alice check out this commit!');
    });
  });

  group('Poll Models & Vote Validation (Part C)', () {
    test('serializes and deserializes PollModel correctly', () {
      final poll = PollModel(
        question: 'Next sprint priority?',
        options: const [
          PollOption(id: 'opt_feat', text: 'New Features'),
          PollOption(id: 'opt_bugs', text: 'Bug Squashing'),
          PollOption(id: 'opt_perf', text: 'Performance Tuning'),
        ],
        optionIds: const ['opt_feat', 'opt_bugs', 'opt_perf'],
        createdBy: 'user_lead',
        allowMultiple: false,
        closedAt: null,
      );

      final map = poll.toMap();
      expect(map['question'], 'Next sprint priority?');
      expect((map['options'] as List).length, 3);
      expect(map['allowMultiple'], false);
      expect(map['closedAt'], isNull);

      final restored = PollModel.fromMap(map);
      expect(restored.question, 'Next sprint priority?');
      expect(restored.options.length, 3);
      expect(restored.options[1].text, 'Bug Squashing');
      expect(restored.isClosed, isFalse);
    });

    test('enforces closed state when closedAt is set or closesAt expires', () {
      final past = DateTime.now().subtract(const Duration(minutes: 5));
      final closedPoll = PollModel(
        question: 'Closed poll test',
        options: const [
          PollOption(id: 'opt_1', text: 'A'),
          PollOption(id: 'opt_2', text: 'B'),
        ],
        optionIds: const ['opt_1', 'opt_2'],
        createdBy: 'user_lead',
        closedAt: past,
      );

      expect(closedPoll.isClosed, isTrue);

      final expiredPoll = PollModel(
        question: 'Expired poll test',
        options: const [
          PollOption(id: 'opt_1', text: 'A'),
          PollOption(id: 'opt_2', text: 'B'),
        ],
        optionIds: const ['opt_1', 'opt_2'],
        createdBy: 'user_lead',
        closesAt: past,
      );

      expect(expiredPoll.isClosed, isTrue);
    });

    test('serializes PollVote properly', () {
      final now = DateTime.now();
      final vote = PollVote(
        uid: 'user_charlie',
        optionIds: const ['opt_feat'],
        votedAt: now,
      );

      final map = vote.toMap();
      expect(map['optionIds'], ['opt_feat']);

      final restored = PollVote.fromMap('user_charlie', map);
      expect(restored.uid, 'user_charlie');
      expect(restored.optionIds, ['opt_feat']);
    });
  });
}
