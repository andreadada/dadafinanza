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
import 'services/quick_capture_deep_link_service.dart';
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
  const deepLinks = QuickCaptureDeepLinkService();
  StreamSubscription<Uri?>? _widgetSubscription;
  Timer? _notificationDebounce;
  bool? _lastWidgetPrivacy;

  @override
  void initState() {
    super.initState();
    _widgetSubscription = HomeWidget.widgetClicked.listen(
      (uri) => unawaited(_handleWidgetUri(uri)),
    );
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

  Future<void> _handleWidgetUri(Uri? uri) async {
    if (uri == null) return;
    final draft = await deepLinks.fromUri(widget.state, uri);
    if (draft == null) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => QuickAddPage(initialDraft: draft),
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
      HomeWidget.updateWidget(
        androidName: 'DadaQuickAddWidgetProvider',
        qualifiedAndroidName: 'com.dadafinanza.app.DadaQuickAddWidgetProvider',
      ),
      HomeWidget.updateWidget(
        androidName: 'DadaQuickAmountsWidgetProvider',
        qualifiedAndroidName: 'com.dadafinanza.app.DadaQuickAmountsWidgetProvider',
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
