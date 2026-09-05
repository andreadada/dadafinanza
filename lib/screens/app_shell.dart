import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/models.dart';
import '../models/quick_capture_models.dart';
import '../services/quick_preset_service.dart';
import '../widgets/finance_quick_action.dart';
import '../widgets/ui_helpers.dart';
import 'account_analytics_screen.dart';
import 'expert_transactions_screen.dart';
import 'home_screen.dart';
import 'planning_screens.dart';
import 'quick_add_page.dart';

/// The single navigation shell exposed by DadaFinanza.
///
/// Home, Movimenti and Analisi share one account scope. `null` means Totale.
/// Pianifica intentionally remains global because budgets, goals and planning
/// can span more than one account.
class DadaAppShell extends StatefulWidget {
  const DadaAppShell({super.key});

  @override
  State<DadaAppShell> createState() => _DadaAppShellState();
}

class _DadaAppShellState extends State<DadaAppShell> {
  int index = 0;
  int? selectedAccountId;
  final List<int> _tabHistory = [0];
  DateTime? _lastHomeBack;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scopedAccountId = selectedAccountId != null &&
            state.activeAccounts.any((item) => item.id == selectedAccountId)
        ? selectedAccountId
        : null;
    final pages = [
      DadaHomeScreen(
        selectedAccountId: scopedAccountId,
        onAccountChanged: _setAccountScope,
      ),
      ExpertTransactionsScreen(
        selectedAccountId: scopedAccountId,
        onAccountChanged: _setAccountScope,
      ),
      AccountAnalyticsScreen(
        selectedAccountId: scopedAccountId,
        onAccountChanged: _setAccountScope,
      ),
      const PlanningScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handleBack,
      child: Scaffold(
        body: SafeArea(
          child: IndexedStack(index: index, children: pages),
        ),
        floatingActionButton: GestureDetector(
          onLongPress: _showQuickMenu,
          child: FloatingActionButton(
            tooltip: 'Nuovo movimento. Tieni premuto per voce e preset.',
            onPressed: () => _open(TransactionType.expense),
            child: const Icon(Icons.add_rounded),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: _selectTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Movimenti',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Analisi',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note_rounded),
              label: 'Pianifica',
            ),
          ],
        ),
      ),
    );
  }

  void _setAccountScope(int? accountId) {
    if (selectedAccountId == accountId) return;
    setState(() => selectedAccountId = accountId);
  }

  void _selectTab(int value) {
    if (value == index) return;
    setState(() {
      index = value;
      _tabHistory.remove(value);
      _tabHistory.add(value);
    });
  }

  Future<void> _handleBack(bool didPop, Object? result) async {
    if (didPop) return;

    if (_tabHistory.length > 1) {
      setState(() {
        _tabHistory.removeLast();
        index = _tabHistory.last;
      });
      return;
    }

    if (index != 0) {
      setState(() {
        index = 0;
        _tabHistory
          ..clear()
          ..add(0);
      });
      return;
    }

    final now = DateTime.now();
    if (_lastHomeBack != null &&
        now.difference(_lastHomeBack!) < const Duration(seconds: 2)) {
      await SystemNavigator.pop();
      return;
    }
    _lastHomeBack = now;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Premi di nuovo Indietro per uscire da DadaFinanza.'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  Future<void> _open(
    TransactionType type, {
    QuickPreset? preset,
    bool voice = false,
  }) async {
    final state = AppScope.of(context);
    int? accountId = preset?.accountId ?? selectedAccountId;
    int? destinationId = preset?.toAccountId;
    if (accountId == null) {
      final key = switch (type) {
        TransactionType.expense => 'preferred_expense_account',
        TransactionType.income => 'preferred_income_account',
        TransactionType.transfer => 'preferred_transfer_source',
      };
      accountId = int.tryParse(await state.database.getSetting(key) ?? '');
    }
    if (type == TransactionType.transfer && destinationId == null) {
      destinationId = int.tryParse(
        await state.database.getSetting('preferred_transfer_destination') ?? '',
      );
      if (destinationId == accountId) destinationId = null;
    }
    if (!mounted) return;
    final draft = TransactionDraft(
      type: type,
      amountCents: preset?.amount == null
          ? null
          : (preset!.amount! * 100).round(),
      accountId: accountId,
      toAccountId: destinationId,
      categoryId: type == TransactionType.transfer ? null : preset?.categoryId,
      source: voice
          ? QuickCaptureSource.voice
          : preset == null
              ? QuickCaptureSource.manual
              : QuickCaptureSource.preset,
      startVoice: voice,
    );
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuickAddPage(initialDraft: draft)),
    );
  }

  Future<void> _showQuickMenu() async {
    final state = AppScope.of(context);
    final presets = await QuickPresetService(
      state.database,
    ).all(enabledOnly: true);
    if (!mounted) return;
    final choice = await showModalBottomSheet<Object>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nuovo movimento',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FinanceQuickAction(
                      icon: Icons.arrow_upward_rounded,
                      label: 'Spesa',
                      onTap: () =>
                          Navigator.pop(sheetContext, TransactionType.expense),
                    ),
                  ),
                  Expanded(
                    child: FinanceQuickAction(
                      icon: Icons.arrow_downward_rounded,
                      label: 'Entrata',
                      onTap: () =>
                          Navigator.pop(sheetContext, TransactionType.income),
                    ),
                  ),
                  Expanded(
                    child: FinanceQuickAction(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Trasferisci',
                      onTap: () =>
                          Navigator.pop(sheetContext, TransactionType.transfer),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FinanceQuickAction(
                icon: Icons.mic_none_rounded,
                label: 'Voce',
                onTap: () => Navigator.pop(sheetContext, const _VoiceChoice()),
              ),
              if (presets.isNotEmpty) ...[
                const SizedBox(height: 20),
                const SectionTitle('Preset'),
                ...presets.take(6).map(
                  (preset) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bookmark_outline_rounded),
                    title: Text(preset.name),
                    subtitle: Text(
                      [
                        preset.type.label,
                        if (preset.amount != null)
                          moneyFor(state, preset.amount!),
                      ].join(' · '),
                    ),
                    onTap: () => Navigator.pop(sheetContext, preset),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice is QuickPreset) {
      await _open(choice.type, preset: choice);
    } else if (choice is TransactionType) {
      await _open(choice);
    } else if (choice is _VoiceChoice) {
      await _open(TransactionType.expense, voice: true);
    }
  }
}

class _VoiceChoice {
  const _VoiceChoice();
}
