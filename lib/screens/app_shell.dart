import 'package:flutter/material.dart';

import '../main.dart';
import '../models/models.dart';
import '../models/quick_capture_models.dart';
import '../services/quick_preset_service.dart';
import '../widgets/finance_quick_action.dart';
import '../widgets/ui_helpers.dart';
import 'advances_screen.dart';
import 'canonical_shell.dart';
import 'home_screen.dart';
import 'planning_screens.dart';
import 'quick_add_page.dart';
import 'root_screen.dart' show TransactionsScreen;

/// The single navigation shell exposed by DadaFinanza.
///
/// Legacy RootScreen/HomeScreen classes remain only as implementation debt for
/// shared screens and are never used as an application entry point.
class DadaAppShell extends StatefulWidget {
  const DadaAppShell({super.key});

  @override
  State<DadaAppShell> createState() => _DadaAppShellState();
}

class _DadaAppShellState extends State<DadaAppShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [
      DadaHomeScreen(),
      TransactionsScreen(),
      CanonicalAnalyticsScreen(),
      PlanningScreen(),
    ];
    return Scaffold(
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
        onDestinationSelected: (value) => setState(() => index = value),
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
    );
  }

  Future<void> _open(
    TransactionType type, {
    QuickPreset? preset,
    bool voice = false,
  }) async {
    final state = AppScope.of(context);
    int? accountId = preset?.accountId;
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
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.handshake_outlined),
                title: const Text('Anticipo'),
                subtitle: const Text('Soldi da ricevere o da restituire'),
                onTap: () => Navigator.pop(sheetContext, 'advance'),
              ),
              if (presets.isNotEmpty) ...[
                const SizedBox(height: 20),
                const SectionTitle('Preset'),
                ...presets
                    .take(6)
                    .map(
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
    if (choice == 'advance') {
      await showAdvanceEditor(context);
    } else if (choice is QuickPreset) {
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
