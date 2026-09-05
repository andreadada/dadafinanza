import 'models.dart';

enum QuickCaptureSource {
  manual,
  preset,
  widget,
  voice,
  smartFinance,
  deepLink,
}

enum VoiceFieldSource { explicit, inferred, smartFinance, fallback }

enum VoiceIssueType {
  missingAmount,
  ambiguousAmount,
  ambiguousCategory,
  ambiguousAccount,
  unknownCategory,
  unknownAccount,
  unavailable,
  noSpeech,
}

class VoiceParseIssue {
  const VoiceParseIssue({
    required this.type,
    required this.message,
    this.candidateIds = const [],
  });

  final VoiceIssueType type;
  final String message;
  final List<int> candidateIds;
}

class TransactionDraft {
  const TransactionDraft({
    this.type = TransactionType.expense,
    this.amountCents,
    this.accountId,
    this.toAccountId,
    this.categoryId,
    this.date,
    this.note,
    this.tags = const [],
    this.source = QuickCaptureSource.manual,
    this.startVoice = false,
    this.fieldSources = const {},
  });

  final TransactionType type;
  final int? amountCents;
  final int? accountId;
  final int? toAccountId;
  final int? categoryId;
  final DateTime? date;
  final String? note;
  final List<String> tags;
  final QuickCaptureSource source;
  final bool startVoice;
  final Map<String, VoiceFieldSource> fieldSources;

  TransactionDraft copyWith({
    TransactionType? type,
    int? amountCents,
    int? accountId,
    int? toAccountId,
    int? categoryId,
    DateTime? date,
    String? note,
    List<String>? tags,
    QuickCaptureSource? source,
    bool? startVoice,
    Map<String, VoiceFieldSource>? fieldSources,
  }) => TransactionDraft(
    type: type ?? this.type,
    amountCents: amountCents ?? this.amountCents,
    accountId: accountId ?? this.accountId,
    toAccountId: toAccountId ?? this.toAccountId,
    categoryId: categoryId ?? this.categoryId,
    date: date ?? this.date,
    note: note ?? this.note,
    tags: tags ?? this.tags,
    source: source ?? this.source,
    startVoice: startVoice ?? this.startVoice,
    fieldSources: fieldSources ?? this.fieldSources,
  );
}

class VoiceParseResult {
  const VoiceParseResult({
    required this.transcript,
    required this.draft,
    this.issues = const [],
  });

  final String transcript;
  final TransactionDraft draft;
  final List<VoiceParseIssue> issues;

  bool get hasBlockingIssue => issues.any(
    (issue) =>
        issue.type == VoiceIssueType.missingAmount ||
        issue.type == VoiceIssueType.ambiguousAmount ||
        issue.type == VoiceIssueType.ambiguousCategory ||
        issue.type == VoiceIssueType.ambiguousAccount,
  );
}
