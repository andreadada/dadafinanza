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

    final amount = _parseAmount(normalized);
    if (amount.ambiguous) {
      issues.add(
        const VoiceParseIssue(
          type: VoiceIssueType.ambiguousAmount,
          message: 'Ho riconosciuto più importi. Scegli quello corretto.',
        ),
      );
    } else if (amount.cents == null) {
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

    final categoryMatch = _matchEntity<Category>(
      normalized,
      categories,
      (item) => item.name,
      (item) => item.id,
    );
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
    final activeAccounts = accounts
        .where((item) => !item.isSystem && !item.isArchived && !item.isLocked)
        .toList();
    int? accountId;
    int? toAccountId;

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
        if (toAccountId != null)
          sources['toAccount'] = VoiceFieldSource.explicit;
      }
    } else {
      final accountMatch = _matchEntity<Account>(
        normalized,
        activeAccounts,
        (item) => item.name,
        (item) => item.id,
      );
      if (accountMatch.ambiguous) {
        issues.add(
          VoiceParseIssue(
            type: VoiceIssueType.ambiguousAccount,
            message: 'Più conti corrispondono a ciò che hai detto.',
            candidateIds: accountMatch.candidates,
          ),
        );
      } else if (accountMatch.id != null) {
        accountId = accountMatch.id;
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
        amountCents: amount.cents,
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
    final monetary = <int>[];
    final euroPattern = RegExp(
      r'(?:€\s*)?([a-z]+|\d+(?:[\.,]\d{1,2})?)\s*(?:euro|eur|€)(?:\s+e\s+([a-z]+|\d{1,2}))?',
    );
    for (final match in euroPattern.allMatches(input)) {
      final euros = _parseEuroToken(match.group(1));
      if (euros == null) continue;
      final cents = _parseNumberToken(match.group(2)) ?? 0;
      monetary.add(euros.$1 * 100 + (euros.$2 ?? cents).clamp(0, 99));
    }

    final prefixEuro = RegExp(r'€\s*(\d+(?:[\.,]\d{1,2})?)');
    for (final match in prefixEuro.allMatches(input)) {
      final value = _decimalToCents(match.group(1)!);
      if (value != null) monetary.add(value);
    }

    final unique = monetary.where((value) => value > 0).toSet();
    if (unique.length == 1) return _AmountParse(cents: unique.single);
    if (unique.length > 1) return const _AmountParse(ambiguous: true);

    final bare = RegExp(r'\b\d+(?:[\.,]\d{1,2})?\b')
        .allMatches(input)
        .map((match) => match.group(0)!)
        .where((raw) => !_looksLikeDateNumber(input, raw))
        .map(_decimalToCents)
        .whereType<int>()
        .where((value) => value > 0)
        .toSet();
    if (bare.length == 1) return _AmountParse(cents: bare.single);
    if (bare.length > 1) return const _AmountParse(ambiguous: true);
    return const _AmountParse();
  }

  (int, int?)? _parseEuroToken(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.contains(',') || raw.contains('.')) {
      final cents = _decimalToCents(raw);
      if (cents == null) return null;
      return (cents ~/ 100, cents % 100);
    }
    final value = _parseNumberToken(raw);
    return value == null ? null : (value, null);
  }

  int? _decimalToCents(String raw) {
    final value = double.tryParse(raw.replaceAll(',', '.'));
    return value == null ? null : (value * 100).round();
  }

  bool _looksLikeDateNumber(String input, String raw) {
    const months = [
      'gennaio',
      'febbraio',
      'marzo',
      'aprile',
      'maggio',
      'giugno',
      'luglio',
      'agosto',
      'settembre',
      'ottobre',
      'novembre',
      'dicembre',
    ];
    return months.any((month) => input.contains('$raw $month'));
  }

  int? _parseNumberToken(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final direct = int.tryParse(raw);
    if (direct != null) return direct;
    final word = _stripAccents(raw.toLowerCase());
    const values = {
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
    final exact = values[word];
    if (exact != null) return exact;
    const tens = {
      'vent': 20,
      'trent': 30,
      'quarant': 40,
      'cinquant': 50,
      'sessant': 60,
      'settant': 70,
      'ottant': 80,
      'novant': 90,
    };
    for (final entry in tens.entries) {
      if (!word.startsWith(entry.key)) continue;
      final suffix = word.substring(entry.key.length);
      final unit = values[suffix];
      if (unit != null && unit < 10) return entry.value + unit;
    }
    return null;
  }

  _EntityMatch _matchEntity<T>(
    String input,
    List<T> items,
    String Function(T item) label,
    int Function(T item) id,
  ) {
    final scored = <_ScoredEntity<T>>[];
    for (final item in items) {
      final name = _normalize(label(item));
      if (name.isEmpty) continue;
      final score = _entityScore(input, name);
      if (score >= .72) scored.add(_ScoredEntity(item, name, score));
    }
    if (scored.isEmpty) return const _EntityMatch();
    scored.sort((a, b) => b.score.compareTo(a.score));
    final top = scored.first;

    final prefixAlternatives = scored.where((candidate) {
      if (identical(candidate, top)) return false;
      return candidate.name.startsWith('${top.name} ') ||
          top.name.startsWith('${candidate.name} ');
    }).toList();
    if (prefixAlternatives.isNotEmpty && top.score >= .88) {
      return _EntityMatch(
        ambiguous: true,
        candidates: [
          id(top.item),
          ...prefixAlternatives.map((item) => id(item.item)),
        ],
      );
    }

    final close = scored.where((item) => top.score - item.score < .12).toList();
    if (close.length > 1) {
      return _EntityMatch(
        ambiguous: true,
        candidates: close.map((item) => id(item.item)).toList(),
      );
    }
    return _EntityMatch(id: id(top.item));
  }

  double _entityScore(String input, String name) {
    final phrase = RegExp(r'(?:^| )' + RegExp.escape(name) + r'(?: |$)');
    if (phrase.hasMatch(input)) return 1;
    final nameTokens = name.split(' ').where((item) => item.length > 1).toSet();
    if (nameTokens.isEmpty) return 0;
    final inputTokens = input.split(' ').toSet();
    final overlap =
        nameTokens.where(inputTokens.contains).length / nameTokens.length;
    if (overlap == 1) return nameTokens.length > 1 ? .92 : .88;
    return overlap * .78;
  }

  _TransferMatch _matchTransferAccounts(String input, List<Account> accounts) {
    final fromPart = RegExp(
      r'\bda\s+(.+?)(?=\s+a\s+|\s+verso\s+|$)',
    ).firstMatch(input)?.group(1);
    final toPart = RegExp(
      r'\b(?:a|verso)\s+(.+?)(?=\s+(?:oggi|ieri|domani|lunedi|martedi|mercoledi|giovedi|venerdi|sabato|domenica)|$)',
    ).firstMatch(input)?.group(1);
    final from = fromPart == null
        ? const _EntityMatch()
        : _matchEntity<Account>(
            fromPart,
            accounts,
            (item) => item.name,
            (item) => item.id,
          );
    final to = toPart == null
        ? const _EntityMatch()
        : _matchEntity<Account>(
            toPart,
            accounts,
            (item) => item.name,
            (item) => item.id,
          );
    if (from.ambiguous || to.ambiguous) {
      return _TransferMatch(
        ambiguous: true,
        candidates: {...from.candidates, ...to.candidates}.toList(),
      );
    }
    return _TransferMatch(fromId: from.id, toId: to.id);
  }

  _DateParse _parseDate(String input, DateTime now) {
    final current = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );
    if (RegExp(r'\bieri\b').hasMatch(input)) {
      return _DateParse(current.subtract(const Duration(days: 1)), true);
    }
    if (RegExp(r'\bdomani\b').hasMatch(input)) {
      return _DateParse(current.add(const Duration(days: 1)), true);
    }
    if (RegExp(r'\boggi\b').hasMatch(input)) return _DateParse(current, true);

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
      if (!RegExp(r'\b' + entry.key + r'\b').hasMatch(input)) continue;
      var delta = entry.value - now.weekday;
      if (delta > 0) delta -= 7;
      return _DateParse(current.add(Duration(days: delta)), true);
    }

    const months = {
      'gennaio': 1,
      'febbraio': 2,
      'marzo': 3,
      'aprile': 4,
      'maggio': 5,
      'giugno': 6,
      'luglio': 7,
      'agosto': 8,
      'settembre': 9,
      'ottobre': 10,
      'novembre': 11,
      'dicembre': 12,
    };
    for (final entry in months.entries) {
      final match = RegExp(
        r'\b(?:il\s+)?(\d{1,2})\s+' + entry.key + r'\b',
      ).firstMatch(input);
      if (match == null) continue;
      final day = int.parse(match.group(1)!);
      if (day < 1 || day > 31) continue;
      final candidate = DateTime(
        now.year,
        entry.value,
        day,
        now.hour,
        now.minute,
      );
      return _DateParse(candidate, true);
    }
    return _DateParse(current, false);
  }

  String? _extractNote(
    String original, {
    required String normalized,
    required List<Account> accounts,
    required List<Category> categories,
  }) {
    final merchant = RegExp(
      r"\b(?:al|alla|presso)\s+([A-Za-zÀ-ÿ0-9'’&. -]+?)(?=\s+(?:con|nel|sul|su|oggi|ieri|domani)\b|,|$)",
      caseSensitive: false,
    ).firstMatch(original)?.group(1)?.trim();
    if (merchant != null && merchant.length >= 2) return merchant;

    if (original.contains(',')) {
      final tail = original.split(',').last.trim();
      if (tail.length >= 2 &&
          !_containsOnlyKnownEntity(tail, accounts, categories)) {
        return tail;
      }
    }

    final words = normalized.split(' ');
    const commands = {
      'segna',
      'in',
      'per',
      'nel',
      'conto',
      'con',
      'su',
      'sul',
      'oggi',
      'ieri',
      'domani',
      'euro',
      'eur',
      'ho',
      'speso',
      'spesa',
      'pagato',
      'entrata',
      'ricevuto',
      'incasso',
      'accredito',
      'stipendio',
      'trasferisci',
      'trasferimento',
      'sposta',
      'sposto',
      'giroconto',
      'da',
      'a',
      'di',
      'un',
      'una',
      'il',
      'la',
      'al',
      'alla',
      'e',
    };
    final entities = <String>{
      for (final account in accounts) ..._normalize(account.name).split(' '),
      for (final category in categories)
        ..._normalize(category.name).split(' '),
    };
    final remaining = words.where((word) {
      if (word.length < 2 ||
          commands.contains(word) ||
          entities.contains(word)) {
        return false;
      }
      if (RegExp(r'^\d+(?:[\.,]\d+)?€?$').hasMatch(word)) return false;
      if (_parseNumberToken(word) != null) return false;
      return true;
    }).toList();
    if (remaining.isEmpty) return null;
    return remaining.join(' ');
  }

  bool _containsOnlyKnownEntity(
    String text,
    List<Account> accounts,
    List<Category> categories,
  ) {
    final value = _normalize(text);
    return accounts.any((item) => _normalize(item.name) == value) ||
        categories.any((item) => _normalize(item.name) == value);
  }

  bool _containsAny(String input, List<String> values) => values.any((value) {
    final matcher = RegExp(r'(?:^| )' + RegExp.escape(value) + r'(?: |$)');
    return matcher.hasMatch(input);
  });

  String _normalize(String value) => _stripAccents(value.toLowerCase())
      .replaceAll('’', "'")
      .replaceAll(RegExp(r"[^a-z0-9€'.,]+"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _stripAccents(String value) {
    const from = 'àáâäèéêëìíîïòóôöùúûü';
    const to = 'aaaaeeeeiiiioooouuuu';
    var output = value;
    for (var index = 0; index < from.length; index++) {
      output = output.replaceAll(from[index], to[index]);
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
  const _EntityMatch({
    this.id,
    this.ambiguous = false,
    this.candidates = const [],
  });
  final int? id;
  final bool ambiguous;
  final List<int> candidates;
}

class _TransferMatch {
  const _TransferMatch({
    this.fromId,
    this.toId,
    this.ambiguous = false,
    this.candidates = const [],
  });
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

class _ScoredEntity<T> {
  const _ScoredEntity(this.item, this.name, this.score);
  final T item;
  final String name;
  final double score;
}
