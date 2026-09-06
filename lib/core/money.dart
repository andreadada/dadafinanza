/// Integer minor-unit helpers used at persistence and validation boundaries.
///
/// DadaFinanza stores monetary values as cents in SQLite. Existing UI/domain
/// APIs still expose doubles for ergonomics, but every write is rounded once
/// through this utility before entering the ledger.
abstract final class Money {
  static const int scale = 100;

  static int toCents(num value) => (value * scale).round();

  static double fromCents(int cents) => cents / scale;

  static int? nullableToCents(num? value) =>
      value == null ? null : toCents(value);

  static double? nullableFromCents(Object? value) =>
      value == null ? null : fromCents((value as num).toInt());

  static int centsFromMap(
    Map<String, Object?> map,
    String centsKey,
    String legacyKey,
  ) {
    final cents = map[centsKey];
    if (cents is num) return cents.toInt();
    final legacy = map[legacyKey];
    return legacy is num ? toCents(legacy) : 0;
  }

  static double valueFromMap(
    Map<String, Object?> map,
    String centsKey,
    String legacyKey,
  ) => fromCents(centsFromMap(map, centsKey, legacyKey));

  /// Parses a compact arithmetic expression used by Quick Add.
  /// Supports +, -, *, / and decimal comma/dot without evaluating code.
  static double? parseExpression(String raw) {
    final input = raw.replaceAll(',', '.').replaceAll(' ', '');
    if (input.isEmpty || !RegExp(r'^[0-9.+\-*/]+$').hasMatch(input)) {
      return null;
    }
    final tokens = RegExp(r'(\d+(?:\.\d+)?|[+\-*/])')
        .allMatches(input)
        .map((match) => match.group(0)!)
        .toList();
    if (tokens.join() != input || tokens.isEmpty) return null;

    final values = <double>[];
    final ops = <String>[];
    int precedence(String op) => (op == '*' || op == '/') ? 2 : 1;
    bool apply() {
      if (values.length < 2 || ops.isEmpty) return false;
      final b = values.removeLast();
      final a = values.removeLast();
      final op = ops.removeLast();
      final result = switch (op) {
        '+' => a + b,
        '-' => a - b,
        '*' => a * b,
        '/' when b != 0 => a / b,
        _ => double.nan,
      };
      if (!result.isFinite) return false;
      values.add(result);
      return true;
    }

    var expectNumber = true;
    for (final token in tokens) {
      final number = double.tryParse(token);
      if (expectNumber) {
        if (number == null) return null;
        values.add(number);
      } else {
        if (number != null) return null;
        while (ops.isNotEmpty && precedence(ops.last) >= precedence(token)) {
          if (!apply()) return null;
        }
        ops.add(token);
      }
      expectNumber = !expectNumber;
    }
    if (expectNumber) return null;
    while (ops.isNotEmpty) {
      if (!apply()) return null;
    }
    if (values.length != 1) return null;
    return fromCents(toCents(values.single));
  }
}
