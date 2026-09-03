import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:home_widget/home_widget.dart';

import 'app_state.dart';
import 'data/app_database.dart';
import 'screens/quick_add_page.dart';
import 'screens/root_screen.dart';
import 'theme/app_theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  await database.init();
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
  StreamSubscription<Uri?>? _widgetSubscription;

  @override
  void initState() {
    super.initState();
    _widgetSubscription = HomeWidget.widgetClicked.listen(_handleWidgetUri);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _handleWidgetUri(await HomeWidget.initiallyLaunchedFromHomeWidget());
    });
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null || uri.scheme != 'dadafinanza') return;
    if (uri.host == 'quick-add') {
      final category = uri.queryParameters['category'];
      final typeName = uri.queryParameters['type'];
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => QuickAddPage(
            initialCategoryName: category,
            initialTypeName: typeName,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _widgetSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
        notifier: widget.state,
        child: MaterialApp(
          title: 'DadaFinanza',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          darkTheme: AppTheme.dark(),
          supportedLocales: const [Locale('it', 'IT')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const RootScreen(),
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
