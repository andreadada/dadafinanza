import 'package:home_widget/home_widget.dart';

import '../models/models.dart';

class WidgetService {
  static const summaryProvider =
      'com.dadafinanza.app.DadaFinanceWidgetProvider';
  static const balanceProvider =
      'com.dadafinanza.app.DadaBalanceWidgetProvider';
  static const quickProvider =
      'com.dadafinanza.app.DadaQuickAddWidgetProvider';

  Future<void> sync({
    required double balance,
    required List<Category> expenseCategories,
  }) async {
    await HomeWidget.saveWidgetData<String>(
      'balance',
      balance.toStringAsFixed(2),
    );
    final quick = expenseCategories.take(4).map((c) => c.name).toList();
    for (var i = 0; i < 4; i++) {
      await HomeWidget.saveWidgetData<String>(
        'quick_category_$i',
        i < quick.length ? quick[i] : 'Spesa',
      );
    }

    await Future.wait([
      HomeWidget.updateWidget(
        androidName: 'DadaFinanceWidgetProvider',
        qualifiedAndroidName: summaryProvider,
      ),
      HomeWidget.updateWidget(
        androidName: 'DadaBalanceWidgetProvider',
        qualifiedAndroidName: balanceProvider,
      ),
      HomeWidget.updateWidget(
        androidName: 'DadaQuickAddWidgetProvider',
        qualifiedAndroidName: quickProvider,
      ),
    ]);
  }
}
