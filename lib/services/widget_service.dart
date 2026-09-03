import 'package:home_widget/home_widget.dart';

import '../models/models.dart';

class WidgetService {
  static const qualifiedProvider = 'com.dadafinanza.app.DadaFinanceWidgetProvider';

  Future<void> sync({
    required double balance,
    required List<Category> expenseCategories,
  }) async {
    await HomeWidget.saveWidgetData<String>('balance', balance.toStringAsFixed(2));
    final quick = expenseCategories
        .where((c) => c.quickOrder != null)
        .take(4)
        .map((c) => c.name)
        .toList();
    for (var i = 0; i < 4; i++) {
      await HomeWidget.saveWidgetData<String>(
        'quick_category_$i',
        i < quick.length ? quick[i] : 'Spesa',
      );
    }
    await HomeWidget.updateWidget(
      androidName: 'DadaFinanceWidgetProvider',
      qualifiedAndroidName: qualifiedProvider,
    );
  }
}
