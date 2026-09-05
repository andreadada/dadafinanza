import 'package:home_widget/home_widget.dart';

import '../models/models.dart';

class WidgetService {
  static const summaryProvider =
      'com.dadafinanza.app.DadaFinanceWidgetProvider';
  static const balanceProvider =
      'com.dadafinanza.app.DadaBalanceWidgetProvider';
  static const quickProvider = 'com.dadafinanza.app.DadaQuickAddWidgetProvider';
  static const amountsProvider =
      'com.dadafinanza.app.DadaQuickAmountsWidgetProvider';

  Future<void> sync({
    required double balance,
    required List<Category> expenseCategories,
  }) async {
    await HomeWidget.saveWidgetData<String>(
      'balance',
      balance.toStringAsFixed(2),
    );
    final ordered = [...expenseCategories]
      ..sort((a, b) {
        final quickA = a.quickOrder ?? 999;
        final quickB = b.quickOrder ?? 999;
        if (quickA != quickB) return quickA.compareTo(quickB);
        if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    final quick = ordered.take(4).map((item) => item.name).toList();
    for (var index = 0; index < 4; index++) {
      await HomeWidget.saveWidgetData<String>(
        'quick_category_$index',
        index < quick.length ? quick[index] : 'Spesa',
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
      HomeWidget.updateWidget(
        androidName: 'DadaQuickAmountsWidgetProvider',
        qualifiedAndroidName: amountsProvider,
      ),
    ]);
  }
}
