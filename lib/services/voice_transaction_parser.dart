import '../models/models.dart';
import '../models/quick_capture_models.dart';

class VoiceTransactionParser {
  const VoiceTransactionParser();

  VoiceParseResult parse(
    String transcript, {
    required List<Account> accounts,
    required List<Category> categories,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final normalized = _normalize(transcript);
    final issues = <VoiceParseIssue>[];
    final sources = <String, VoiceFieldSource>{};

    final amountResult = _parseAmount(normalized);
    if (amountResult.ambiguous) {
      issues.add(
        const VoiceParseIssue(
          type: VoiceIssueType.ambiguousAmount,
          message: 'Ho riconosciuto più importi. Scegli quello corretto.',
        ),
      );
    } else if (amountResult.cents == null) {
      issues.add(
        const VoiceParseIssue(
          type: VoiceIssueType.missingAmount,
          message: 'Non ho capito l’importo.',
        ),
      );
    } else {
      sources['amount'] = VoiceFieldSource.explicit;
    }

    var type = _explicitType(normalized);
    if (type != null) sources['type'] = VoiceFieldSource.explicit;

    final categoryMatch = _matchCategory(normalized, categories);
    int? categoryId;
    if (categoryMatch.ambiguous) {
      issues.add(
        VoiceParseIssue(
          type: VoiceIssueType.ambiguousCategory,
          message: 'Più categorie corrispondono a ciò che hai detto.',
          candidateIds: categoryMatch.candidates,
        ),
      );
    } else if (categoryMatch.id != null) {
      categoryId = categoryMatch.id;
      sources['category'] = VoiceFieldSource.explicit;
      type ??= categories.firstWhere((item) => item.id == categoryId).type;
      sources.putIfAbsent('type', () => VoiceFieldSource.inferred);
    }

    type ??= TransactionType.expense;

    int? accountId;
    int? toAccountId;
    final activeAccounts = accounts
        .where((item) => !item.isSystem && !item.isArchived && !item.isLocked)
        .toList();
    if (type == TransactionType.transfer) {
      final transfer = _matchTransferAccounts(normalized, activeAccounts);
      if (transfer.ambiguous) {
        issues.add(
          VoiceParseIssue(
            type: VoiceIssueType.ambiguousAccount,
            message: 'Non è chiaro quali conti usare per il trasferimento.',
            candidateIds: transfer.candidates,
          ),
        );
      } else {
        accountId = transfer.fromId;
        toAccountId = transfer.toId;
        if (accountId != null) sources['account'] = VoiceFieldSource.explicit;
        if (toAccountId != null) {
          sources['toAccount'] = VoiceFieldSource.explicit;
        }
      }
    } else {
      final match = _matchEntity(normalized, activeAccounts, (item) => item.name);
      if (match.ambiguous) {
        issues.add(
          VoiceParseIssue(
            type: VoiceIssueType.ambiguousAccount,
            message: 'Più conti corrispondono a ciò che hai detto.',
            candidateIds: match.candidates,
          ),
        );
      } else if (match.id != null) {
        accountId = match.id;
        sources['account'] = VoiceFieldSource.explicit;
      }
    }

    final parsedDate = _parseDate(normalized, reference);
    if (parsedDate.explicit) sources['date'] = VoiceFieldSource.explicit;

    final note = _extractNote(
      transcript,
      normalized: normalized,
      accounts: activeAccounts,
      categories: categories,
    );
    if (note != null) sources['note'] = VoiceFieldSource.explicit;

    return VoiceParseResult(
      transcript: transcript,
      issues: issues,
      draft: TransactionDraft(
        type: type,
        amountCents: amountResult.cents,
        accountId: accountId,
        toAccountId: toAccountId,
        categoryId: categoryId,
        date: parsedDate.value,
        note: note,
        source: QuickCaptureSource.voice,
        fieldSources: sources,
      ),
    );
  }

  TransactionType? _explicitType(String input) {
    if (_containsAny(input, const [
      'trasferisci',
      'trasferimento',
      'sposta',
      'sposto',
      'giroconto',
    ])) {
      return TransactionType.transfer;
    }
    if (_containsAny(input, const [
      'entrata',
      'ricevuto',
      'ho ricevuto',
      'incasso',
      'accredito',
      'stipendio',
    ])) {
      return TransactionType.income;
    }
    if (_containsAny(input, const [
      'spesa',
      'speso',
      'ho speso',
      'pagato',
      'ho pagato',
      'uscita',
    ])) {
      return TransactionType.expense;
    }
    return null;
  }

  _AmountParse _parseAmount(String input) {
    final values = <int>{};
    final numeric = RegExp(r'(?:€\s*)?(\d{1,9}(?:[\.,]\d{1,2})?)(?:\s*€|\s*euro|\s*eur)?');
    for (final match in numeric.allMatches(input)) {
      final raw = match.group(1)!;
      final value = double.tryParse(raw.replaceAll(',', '.'));
      if (value != null && value > 0) values.add((value * 100).round());
    }

    final euroWords = RegExp(
      r'\b([a-zà-ù]+|\d+)\s+euro(?:\s+e\s+([a-zà-ù]+|\d+))?\b',
    );
    for (final match in euroWords.allMatches(input)) {
      final euros = _parseNumberToken(match.group(1));
      final cents = _parseNumberToken(match.group(2));
      if (euros != null && euros >= 0) {
        values.add(euros * 100 + (cents ?? 0).clamp(0, 99));
      }
    }

    if (values.isEmpty) return const _AmountParse();
    if (values.length > 1) return const _AmountParse(ambiguous: true);
    return _AmountParse(cents: values.single);
  }

  int? _parseNumberToken(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final direct = int.tryParse(raw);
    if (direct != null) return direct;
    final word = _stripAccents(raw.toLowerCase());
    const base = {
      'zero': 0,
      'un': 1,
      'uno': 1,
      'una': 1,
      'due': 2,
      'tre': 3,
      'quattro': 4,
      'cinque': 5,
      'sei': 6,
      'sette': 7,
      'otto': 8,
      'nove': 9,
      'dieci': 10,
      'undici': 11,
      'dodici': 12,
      'tredici': 13,
      'quattordici': 14,
      'quindici': 15,
      'sedici': 16,
      'diciassette': 17,
      'diciotto': 18,
      'diciannove': 19,
      'venti': 20,
      'trenta': 30,
      'quaranta': 40,
      'cinquanta': 50,
      'sessanta': 60,
      'settanta': 70,
      'ottanta': 80,
      'novanta': 90,
      'cento': 100,
    };
    final exact = base[word];
    if (exact != null) return exact;
    for (final entry in const {
      'vent': 20,
      'trent': 30,
      'quarant': 40,
      'cinquant': 50,
      'sessant': 60,
      'settant': 70,
      'ottant': 80,
      'novant': 90,
    }.entries) {
      if (!word.startsWith(entry.key)) continue;
      final suffix = word.substring(entry.key.length);
      final unit = base[suffix] ??
          base[suffix == 'uno' ? 'uno' : suffix == 'otto' ? 'otto' : suffix];
      if (unit != null && unit < 10) return entry.value + unit;
    }
    return null;
  }

  _CategoryMatch _matchCategory(String input, List<Category> categories) {
    final match = _matchEntity(input, categories, (item) => item.name);
    return _CategoryMatch(
      id: match.id,
      ambiguous: match.ambiguous,
      candidates: match.candidates,
    );
  }

  _EntityMatch _matchEntity<T>(
    String input,
    List<T> items,
    String Function(T item) label,
  ) {
    final scored = <(int, double)>[];
    for (var index = 0; index < items.length; index++) {
      final name = _normalize(label(items[index]));
      if (name.isEmpty) continue;
      final score = _entityScore(input, name);
      if (score >= .78) scored.add((index, score));
    }
    if (scored.isEmpty) return const _EntityMatch();
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final top = scored.first;
    final tied = scored.where((item) => (top.$2 - item.$2).abs() < .08).toList();
    int idOf(T item) => switch (item) {
          Account account => account.id,
          Category category => category.id,
          _ => throw StateError('Unsupported voice entity'),
        };
    if (tied.length > 1) {
      return _EntityMatch(
        ambiguous: true,
        candidates: tied.map((item) => idOf(items[item.$1])).toList(),
      );
    }
    return _EntityMatch(id: idOf(items[top.$1]));
  }

  double _entityScore(String input, String name) {
    if (RegExp('(?:^| )${RegExp.escape(name)}(?: |\\$)').hasMatch(input)) {
      return 1;
    }
    final nameTokens = name.split(' ').where((item) => item.length > 1).toSet();
    if (nameTokens.isEmpty) return 0;
    final inputTokens = input.split(' ').toSet();
    final overlap = nameTokens.where(inputTokens.contains).length / nameTokens.length;
    if (overlap == 1 && nameTokens.length > 1) return .92;
    if (overlap == 1 && nameTokens.single.length >= 4) return .88;
    return overlap * .7;
  }

  _TransferMatch _matchTransferAccounts(String input, List<Account> accounts) {
    final fromPart = RegExp(r'\bda\s+(.+?)(?=\s+a\s+|\s+verso\s+|$)').firstMatch(input)?.group(1);
    final toPart = RegExp(r'\b(?:a|verso)\s+(.+?)(?=\s+(?:oggi|ieri|domani)|$)').firstMatch(input)?.group(1);
    final from = fromPart == null
        ? const _EntityMatch()
        : _matchEntity(fromPart, accounts, (item) => item.name);
    final to = toPart == null
        ? const _EntityMatch()
        : _matchEntity(toPart, accounts, (item) => item.name);
    if (from.ambiguous || to.ambiguous) {
      return _TransferMatch(
        ambiguous: true,
        candidates: {...from.candidates, ...to.candidates}.toList(),
      );
    }
    return _TransferMatch(fromId: from.id, toId: to.id);
  }

  _DateParse _parseDate(String input, DateTime now) {
    final today = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    if (RegExp(r'\bieri\b').hasMatch(input)) {
      return _DateParse(today.subtract(const Duration(days: 1)), true);
    }
    if (RegExp(r'\bdomani\b').hasMatch(input)) {
      return _DateParse(today.add(const Duration(days: 1)), true);
    }
    if (RegExp(r'\boggi\b').hasMatch(input)) return _DateParse(today, true);

    const weekdays = {
      'lunedi': DateTime.monday,
      'martedi': DateTime.tuesday,
      'mercoledi': DateTime.wednesday,
      'giovedi': DateTime.thursday,
      'venerdi': DateTime.friday,
      'sabato': DateTime.saturday,
      'domenica': DateTime.sunday,
    };
    for (final entry in weekdays.entries) {
      if (!RegExp('\\b${entry.key}\\b').hasMatch(input)) continue;
      var delta = entry.value - now.weekday;
      if (delta > 0) delta -= 7;
      return _DateParse(today.add(Duration(days: delta)), true);
    }
    return _DateParse(today, false);
  }

  String? _extractNote(
    String original, {
    required String normalized,
    required List<Account> accounts,
    required List<Category> categories,
  }) {
    final merchant = RegExp(
      r"\b(?:al|alla|da|dal|presso)\s+([A-Za-zÀ-ÿ0-9'’&. -]+?)(?=\s+(?:con|nel|sul|su|oggi|ieri|domani|da|a)\b|,|$)",
      caseSensitive: false,
    ).firstMatch(original)?.group(1)?.trim();
    if (merchant != null && merchant.length >= 2) return merchant;

    final commaTail = original.contains(',') ? original.split(',').last.trim() : null;
    if (commaTail != null && commaTail.length >= 2 && !_containsOnlyKnownEntity(commaTail, accounts, categories)) {
      return commaTail;
    }

    final knownWords = <String>{
      'segna', 'in', 'per', 'nel', 'conto', 'con', 'su', 'sul', 'oggi', 'ieri',
      'domani', 'euro', 'eur', 'ho', 'speso', 'spesa', 'pagato', 'entrata',
      'ricevuto', 'incasso', 'accredito', 'trasferisci', 'trasferimento', 'sposta',
      'sposto', 'giroconto', 'da', 'a', 'di', 'un', 'una', 'il', 'la', 'al', 'alla',
    };
    final entityTokens = <String>{
      for (final account in accounts) ..._normalize(account.name).split(' '),
      for (final category in categories) ..._normalize(category.name).split(' '),
    };
    final tokens = normalized
        .split(' ')
        .where((token) =>
            token.length > 1 &&
            !knownWords.contains(token) &&
            !entityTokens.contains(token) &&
            !RegExp(r'^\d+(?:[\.,]\d+)?$').hasMatch(token) &&
            _parseNumberToken(token) == null)
        .toList();
    if (tokens.isEmpty) return null;
    return tokens.join(' ');
  }

  bool _containsOnlyKnownEntity(
    String text,
    List<Account> accounts,
    List<Category> categories,
  ) {
    final normalized = _normalize(text);
    return accounts.any((item) => _normalize(item.name) == normalized) ||
        categories.any((item) => _normalize(item.name) == normalized);
  }

  bool _containsAny(String input, List<String> values) => values.any(
        (value) => RegExp('(?:^| )${RegExp.escape(value)}(?: |\\$)').hasMatch(input),
      );

  String _normalize(String value) => _stripAccents(value.toLowerCase())
      .replaceAll('’', "'")
      .replaceAll(RegExp(r"[^a-z0-9€'.,]+"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _stripAccents(String value) {
    const from = 'àáâäèéêëìíîïòóôöùúûü';
    const to = 'aaaaeeeeiiiioooouuuu';
    var output = value;
    for (var i = 0; i < from.length; i++) {
      output = output.replaceAll(from[i], to[i]);
    }
    return output;
  }
}

class _AmountParse {
  const _AmountParse({this.cents, this.ambiguous = false});
  final int? cents;
  final bool ambiguous;
}

class _EntityMatch {
  const _EntityMatch({this.id, this.ambiguous = false, this.candidates = const []});
  final int? id;
  final bool ambiguous;
  final List<int> candidates;
}

class _CategoryMatch {
  const _CategoryMatch({this.id, this.ambiguous = false, this.candidates = const []});
  final int? id;
  final bool ambiguous;
  final List<int> candidates;
}

class _TransferMatch {
  const _TransferMatch({this.fromId, this.toId, this.ambiguous = false, this.candidates = const []});
  final int? fromId;
  final int? toId;
  final bool ambiguous;
  final List<int> candidates;
}

class _DateParse {
  const _DateParse(this.value, this.explicit);
  final DateTime value;
  final bool explicit;
}
