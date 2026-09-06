import 'package:dadafinanza/core/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quick amount expressions support all four arithmetic operators', () {
    expect(Money.parseExpression('12,50 + 4,20'), 16.70);
    expect(Money.parseExpression('20 - 3,50'), 16.50);
    expect(Money.parseExpression('7 * 3'), 21);
    expect(Money.parseExpression('8 / 4'), 2);
    expect(Money.parseExpression('7 × 3'), 21);
    expect(Money.parseExpression('8 ÷ 4'), 2);
    expect(Money.parseExpression('20 − 3,50'), 16.50);
    expect(Money.parseExpression('10 + 2 * 3'), 16);
  });
}
