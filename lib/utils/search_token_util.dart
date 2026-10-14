import '../models/poll_model.dart';

class SearchTokenUtil {
  /// Generates de-duplicated, lowercase, punctuation-stripped search tokens.
  /// Minimum token length is 2. Capped at [maxTokens] (default 30).
  static List<String> generateTokens({
    required String text,
    PollModel? poll,
    int minLength = 2,
    int maxTokens = 30,
  }) {
    final StringBuffer combined = StringBuffer(text);
    if (poll != null) {
      combined.write(' ');
      combined.write(poll.question);
      for (final opt in poll.options) {
        combined.write(' ');
        combined.write(opt.text);
      }
    }

    final raw = combined.toString().toLowerCase();
    // Replace non-alphanumeric chars with spaces to strip punctuation
    final cleaned = raw.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    final words = cleaned.split(RegExp(r'\s+'));

    final Set<String> tokenSet = {};
    for (final word in words) {
      final trimmed = word.trim();
      if (trimmed.length >= minLength) {
        tokenSet.add(trimmed);
        if (tokenSet.length >= maxTokens) break;
      }
    }

    return tokenSet.toList();
  }
}
