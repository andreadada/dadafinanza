import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:home_widget/home_widget.dart';

import 'app_state.dart';
import 'data/app_database.dart';
import 'models/models.dart';
import 'screens/canonical_shell.dart';
import 'screens/quick_add_page.dart';
import 'services/finance_schema_service.dart';
import 'services/notification_service.dart';
import 'services/recurring_execution_service.dart';
import 'services/security_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_lock_gate.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  await database.init();
  await FinanceSchemaService(database).ensure();
  await const RecurringExecutionService().processDue(database);
  final state = AppState(database);
  await state.load();
  runApp(DadaFinanzaApp(state: state));
}

class DadaFinanzaApp extends StatefulWidget {
  const DadaFinanzaApp({required this.state, super.key});
  final AppState state;

  @override
  State<DadaFinanzaApp> createState() => _DadaFinanzaAppState();
}

class _DadaFinanzaAppState extends State<DadaFinanzaApp> {
  final security = SecurityService();
  final notificationService = NotificationService();
  StreamSubscription<Uri?>? _widgetSubscription;
  Timer? _notificationDebounce;
  bool? _lastWidgetPrivacy;

  @override
  void initState() {
    super.initState();
    _widgetSubscription = HomeWidget.widgetClicked.listen(_handleWidgetUri);
    widget.state.addListener(_handleStateChanged);
    _handleStateChanged();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) async => _handleWidgetUri(
        await HomeWidget.initiallyLaunchedFromHomeWidget(),
      ),
    );
  }

  void _handleStateChanged() {
    _syncWidgetPrivacy();
    _notificationDebounce?.cancel();
    _notificationDebounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(notificationService.sync(widget.state)),
    );
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null || uri.scheme != 'dadafinanza' || uri.host != 'quick-add') {
      return;
    }
    final accountId = int.tryParse(uri.queryParameters['account'] ?? '');
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => QuickAddPage(
          initialCategoryName: uri.queryParameters['category'],
          initialTypeName: uri.queryParameters['type'],
          initialAccountId: accountId,
        ),
      ),
    );
  }

  void _syncWidgetPrivacy() {
    final hidden = widget.state.hideBalance;
    if (_lastWidgetPrivacy == hidden) return;
    _lastWidgetPrivacy = hidden;
    unawaited(_writeWidgetPrivacy(hidden));
  }

  Future<void> _writeWidgetPrivacy(bool hidden) async {
    await HomeWidget.saveWidgetData<bool>('hide_balance', hidden);
    await Future.wait([
      HomeWidget.updateWidget(
        androidName: 'DadaFinanceWidgetProvider',
        qualifiedAndroidName: 'com.dadafinanza.app.DadaFinanceWidgetProvider',
      ),
      HomeWidget.updateWidget(
        androidName: 'DadaBalanceWidgetProvider',
        qualifiedAndroidName: 'com.dadafinanza.app.DadaBalanceWidgetProvider',
      ),
    ]);
  }

  @override
  void dispose() {
    widget.state.removeListener(_handleStateChanged);
    _notificationDebounce?.cancel();
    _widgetSubscription?.cancel();
    super.dispose();
  }

  ThemeMode get _themeMode => switch (widget.state.themePreference) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      };

  @override
  Widget build(BuildContext context) => AppScope(
        notifier: widget.state,
        child: AnimatedBuilder(
          animation: widget.state,
          builder: (context, _) => MaterialApp(
            title: 'DadaFinanza',
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _themeMode,
            supportedLocales: const [Locale('it', 'IT')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: AppLockGate(
              security: security,
              child: const CanonicalRootScreen(),
            ),
          ),
        ),
      );
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({required super.notifier, required super.child, super.key});

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!.notifier!;
  }
}
