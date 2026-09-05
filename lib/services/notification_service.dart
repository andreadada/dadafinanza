import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../app_state.dart';
import '../models/models.dart';

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin plugin;
  bool _initialized = false;
  String? _lastSignature;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const android = AndroidInitializationSettings('@drawable/ic_launcher');
    const settings = InitializationSettings(android: android);
    await plugin.initialize(settings: settings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (!Platform.isAndroid) return true;
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<void> sync(AppState state) async {
    await initialize();
    final enabled =
        (await state.database.getSetting('notifications_enabled')) == '1';
    if (!enabled) {
      if (_lastSignature != 'off') {
        await plugin.cancelAll();
        _lastSignature = 'off';
      }
      return;
    }

    final recurringEnabled =
        (await state.database.getSetting('notifications_recurring')) != '0';
    final budgetEnabled =
        (await state.database.getSetting('notifications_budget')) != '0';
    final goalEnabled =
        (await state.database.getSetting('notifications_goal')) != '0';
    final forecastEnabled =
        (await state.database.getSetting('notifications_forecast')) != '0';
    final advancesEnabled =
        (await state.database.getSetting('notifications_advances')) != '0';

    final signatureParts = <String>[
      '$recurringEnabled',
      '$budgetEnabled',
      '$goalEnabled',
      '$forecastEnabled',
      '$advancesEnabled',
    ];
    for (final item in state.recurring) {
      signatureParts.add(
        '${item.id}:${item.nextDate.millisecondsSinceEpoch}:${item.enabled}:${item.amount}:${item.toAccountId}',
      );
    }
    for (final item in state.budgets) {
      signatureParts.add(
        '${item.id}:${state.budgetProgressFor(item).toStringAsFixed(2)}',
      );
    }
    for (final item in state.goals) {
      signatureParts.add(
        '${item.id}:${item.currentAmount}:${item.completed}:${item.archived}',
      );
    }
    signatureParts.add(state.endOfMonthForecast.toStringAsFixed(2));
    for (final advance in state.advances) {
      signatureParts.add(
        'advance:${advance.id}:${state.advanceRemainingCents(advance.id)}:${advance.reminderDate?.millisecondsSinceEpoch}:${advance.dueDate?.millisecondsSinceEpoch}:${advance.closedKind}',
      );
    }
    final signature = signatureParts.join('|');
    if (_lastSignature == signature) return;
    _lastSignature = signature;

    await plugin.cancelAll();
    if (recurringEnabled) await _scheduleRecurring(state);
    if (budgetEnabled) await _notifyBudgetThresholds(state);
    if (goalEnabled) await _notifyGoalStatus(state);
    if (forecastEnabled) await _notifyLowForecast(state);
    if (advancesEnabled) await _scheduleAdvances(state);
  }

  Future<void> _scheduleRecurring(AppState state) async {
    final now = DateTime.now();
    for (final item in state.recurring.where((item) => item.enabled)) {
      final reminder = DateTime(
        item.nextDate.year,
        item.nextDate.month,
        item.nextDate.day,
        9,
      ).subtract(const Duration(days: 1));
      if (!reminder.isAfter(now)) continue;
      final amount = item.amount.toStringAsFixed(2).replaceAll('.', ',');
      final destination = item.type == TransactionType.transfer
          ? state.accountById(item.toAccountId)?.name
          : null;
      await plugin.zonedSchedule(
        id: 100000 + item.id,
        title: 'Scadenza domani',
        body: item.type == TransactionType.transfer && destination != null
            ? '${item.name}: $amount € verso $destination'
            : '${item.name}: $amount €',
        scheduledDate: tz.TZDateTime.from(reminder.toUtc(), tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'finance_due',
            'Scadenze',
            channelDescription: 'Promemoria per movimenti ricorrenti',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'recurring:${item.id}',
      );
    }
  }

  Future<void> _notifyBudgetThresholds(AppState state) async {
    for (final budget in state.budgets.where((item) => item.enabled)) {
      final progress = state.budgetProgressFor(budget);
      final level = progress >= 1
          ? 100
          : progress >= .8
          ? 80
          : 0;
      final key = 'notification_budget_${budget.id}_level';
      final previous =
          int.tryParse(await state.database.getSetting(key) ?? '') ?? 0;
      if (level == 0) {
        if (previous != 0) await state.database.setSetting(key, '0');
        continue;
      }
      if (level <= previous) continue;
      await plugin.show(
        id: 200000 + budget.id,
        title: level == 100 ? 'Budget raggiunto' : 'Budget all’80%',
        body: '${budget.name}: ${(progress * 100).round()}% del limite usato.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'finance_budget',
            'Budget',
            channelDescription: 'Soglie dei budget personali',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        payload: 'budget:${budget.id}',
      );
      await state.database.setSetting(key, '$level');
    }
  }

  Future<void> _notifyGoalStatus(AppState state) async {
    for (final goal in state.goals.where(
      (item) => !item.archived && !item.completed && item.targetDate != null,
    )) {
      final plan = state.goalPlan(goal);
      if (plan.status.name != 'slightlyBehind' &&
          plan.status.name != 'unrealistic') {
        continue;
      }
      final key = 'notification_goal_${goal.id}_state';
      if (await state.database.getSetting(key) == plan.status.name) continue;
      await plugin.show(
        id: 300000 + goal.id,
        title: 'Obiettivo da rivedere',
        body:
            '${goal.name}: con il ritmo attuale la scadenza potrebbe richiedere un aggiustamento.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'finance_goals',
            'Obiettivi',
            channelDescription: 'Aggiornamenti non invasivi sugli obiettivi',
            importance: Importance.low,
            priority: Priority.low,
          ),
        ),
        payload: 'goal:${goal.id}',
      );
      await state.database.setSetting(key, plan.status.name);
    }
  }

  Future<void> _scheduleAdvances(AppState state) async {
    final now = DateTime.now();
    for (final advance in state.advances) {
      final remainingCents = state.advanceRemainingCents(advance.id);
      if (advance.closedKind != null || remainingCents <= 0) continue;
      final person = state.personById(advance.personId);
      final due = advance.dueDate;
      final requested =
          advance.reminderDate ??
          (due == null ? null : due.subtract(const Duration(days: 1)));
      if (requested == null) continue;
      final reminder = DateTime(
        requested.year,
        requested.month,
        requested.day,
        9,
      );
      if (!reminder.isAfter(now)) {
        final overdueKey = 'notification_advance_${advance.id}_remaining';
        final previous = int.tryParse(
          await state.database.getSetting(overdueKey) ?? '',
        );
        if (previous == remainingCents) continue;
        final amount = (remainingCents / 100)
            .toStringAsFixed(2)
            .replaceAll('.', ',');
        await plugin.show(
          id: 500000 + advance.id,
          title: advance.direction.name == 'receivable'
              ? '${person?.name ?? 'Qualcuno'} deve ancora restituirti $amount €'
              : 'Devi ancora restituire $amount € a ${person?.name ?? 'qualcuno'}',
          body:
              'Apri Anticipi per registrare un rimborso o aggiornare il promemoria.',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'finance_advances',
              'Anticipi',
              channelDescription:
                  'Promemoria locali per soldi da ricevere o restituire',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
          ),
          payload: 'advance:${advance.id}',
        );
        await state.database.setSetting(overdueKey, '$remainingCents');
        continue;
      }
      final amount = (remainingCents / 100)
          .toStringAsFixed(2)
          .replaceAll('.', ',');
      await plugin.zonedSchedule(
        id: 500000 + advance.id,
        title: advance.direction.name == 'receivable'
            ? '${person?.name ?? 'Qualcuno'} deve restituirti $amount €'
            : 'Devi restituire $amount € a ${person?.name ?? 'qualcuno'}',
        body: due == null
            ? 'Promemoria Anticipi'
            : 'Scadenza ${due.day}/${due.month}/${due.year}',
        scheduledDate: tz.TZDateTime.from(reminder.toUtc(), tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'finance_advances',
            'Anticipi',
            channelDescription:
                'Promemoria locali per soldi da ricevere o restituire',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'advance:${advance.id}',
      );
    }
  }

  Future<void> _notifyLowForecast(AppState state) async {
    final thresholdRaw = await state.database.getSetting(
      'notifications_low_balance_threshold',
    );
    final threshold = double.tryParse(thresholdRaw ?? '') ?? 0;
    if (threshold <= 0 || state.endOfMonthForecast >= threshold) return;
    final month = '${DateTime.now().year}-${DateTime.now().month}';
    if (await state.database.getSetting('notification_forecast_month') ==
        month) {
      return;
    }
    await plugin.show(
      id: 400001,
      title: 'Saldo previsto basso',
      body:
          'La previsione di fine mese è sotto la soglia che hai impostato. Apri Pianifica per i dettagli.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'finance_forecast',
          'Previsioni',
          channelDescription: 'Avvisi locali sul cash-flow previsto',
          importance: Importance.low,
          priority: Priority.low,
        ),
      ),
      payload: 'forecast',
    );
    await state.database.setSetting('notification_forecast_month', month);
  }
}
