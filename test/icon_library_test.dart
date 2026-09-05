import 'package:dadafinanza/widgets/ui_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('category icon library is broad and grouped', () {
    expect(categoryIconOptions.length, greaterThanOrEqualTo(80));
    final groups = categoryIconOptions.map((item) => item.group).toSet();
    expect(groups.length, greaterThanOrEqualTo(8));
    expect(
      groups,
      containsAll(<String>{
        'Quotidiano',
        'Trasporti e viaggi',
        'Salute e persona',
        'Shopping e tempo libero',
        'Lavoro e formazione',
        'Famiglia e social',
        'Utenze e casa',
        'Finanza e entrate',
      }),
    );
  });

  test('category icon keys are unique and searchable labels are present', () {
    final keys = categoryIconOptions.map((item) => item.key).toList();
    expect(keys.toSet().length, keys.length);
    expect(
      categoryIconOptions.every(
        (item) => item.label.trim().isNotEmpty && item.group.trim().isNotEmpty,
      ),
      isTrue,
    );
  });

  test('account icon library covers common account families', () {
    expect(accountIconOptions.length, greaterThanOrEqualTo(20));
    final groups = accountIconOptions.map((item) => item.group).toSet();
    expect(
      groups,
      containsAll(<String>{
        'Uso quotidiano',
        'Banche e carte',
        'Risparmio e investimenti',
        'Scopo',
      }),
    );
    final keys = accountIconOptions.map((item) => item.key).toList();
    expect(keys.toSet().length, keys.length);
  });
}
