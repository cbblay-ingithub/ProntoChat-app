import 'package:cloud_firestore/cloud_firestore.dart';

class PollOption {
  final String id;
  final String text;

  const PollOption({
    required this.id,
    required this.text,
  });

  factory PollOption.fromMap(Map<String, dynamic> map) {
    return PollOption(
      id: map['id'] as String? ?? '',
      text: map['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text.length > 80 ? text.substring(0, 80) : text,
    };
  }
}

class PollModel {
  final String question;
  final List<PollOption> options;
  final List<String> optionIds;
  final bool allowMultiple;
  final DateTime? closesAt;
  final DateTime? closedAt;
  final String createdBy;

  const PollModel({
    required this.question,
    required this.options,
    required this.optionIds,
    this.allowMultiple = false,
    this.closesAt,
    this.closedAt,
    required this.createdBy,
  });

  bool get isClosed {
    if (closedAt != null) return true;
    if (closesAt != null && DateTime.now().isAfter(closesAt!)) return true;
    return false;
  }

  factory PollModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawOptions = map['options'];
    final List<PollOption> parsedOptions = [];
    if (rawOptions is List) {
      for (final item in rawOptions) {
        if (item is Map) {
          parsedOptions.add(PollOption.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    final rawOptionIds = map['optionIds'];
    final List<String> parsedIds = [];
    if (rawOptionIds is List) {
      parsedIds.addAll(rawOptionIds.map((e) => e.toString()));
    } else {
      parsedIds.addAll(parsedOptions.map((o) => o.id));
    }

    return PollModel(
      question: map['question'] as String? ?? '',
      options: parsedOptions,
      optionIds: parsedIds,
      allowMultiple: map['allowMultiple'] == true,
      closesAt: parseDate(map['closesAt']),
      closedAt: parseDate(map['closedAt']),
      createdBy: map['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question.length > 200 ? question.substring(0, 200) : question,
      'options': options.map((o) => o.toMap()).toList(),
      'optionIds': optionIds.isNotEmpty ? optionIds : options.map((o) => o.id).toList(),
      'allowMultiple': allowMultiple,
      if (closesAt != null) 'closesAt': Timestamp.fromDate(closesAt!),
      if (closedAt != null) 'closedAt': Timestamp.fromDate(closedAt!),
      'createdBy': createdBy,
    };
  }

  PollModel copyWith({
    String? question,
    List<PollOption>? options,
    List<String>? optionIds,
    bool? allowMultiple,
    DateTime? closesAt,
    DateTime? closedAt,
    String? createdBy,
  }) {
    return PollModel(
      question: question ?? this.question,
      options: options ?? this.options,
      optionIds: optionIds ?? this.optionIds,
      allowMultiple: allowMultiple ?? this.allowMultiple,
      closesAt: closesAt ?? this.closesAt,
      closedAt: closedAt ?? this.closedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

class PollVote {
  final String uid;
  final List<String> optionIds;
  final DateTime votedAt;

  const PollVote({
    required this.uid,
    required this.optionIds,
    required this.votedAt,
  });

  factory PollVote.fromMap(String uid, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawIds = map['optionIds'];
    final List<String> parsedIds = [];
    if (rawIds is List) {
      parsedIds.addAll(rawIds.map((e) => e.toString()));
    }

    return PollVote(
      uid: uid,
      optionIds: parsedIds,
      votedAt: parseDate(map['votedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'optionIds': optionIds,
      'votedAt': FieldValue.serverTimestamp(),
    };
  }
}
