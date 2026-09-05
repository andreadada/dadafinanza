import 'package:flutter/material.dart';

import '../services/security_service.dart';
import '../widgets/ui_helpers.dart';

class LocalPrivacyScreen extends StatefulWidget {
  const LocalPrivacyScreen({super.key});

  @override
  State<LocalPrivacyScreen> createState() => _LocalPrivacyScreenState();
}

class _LocalPrivacyScreenState extends State<LocalPrivacyScreen> {
  final security = SecurityService();
  final pin = TextEditingController();
  final pinConfirm = TextEditingController();
  AppLockMode mode = AppLockMode.off;
  AppLockTimeout timeout = AppLockTimeout.immediate;
  bool secureRecent = false;
  bool biometricAvailable = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait<Object>([
      security.mode(),
      security.timeout(),
      security.secureRecentApps(),
      security.biometricAvailable(),
    ]);
    if (!mounted) return;
    setState(() {
      mode = values[0] as AppLockMode;
      timeout = values[1] as AppLockTimeout;
      secureRecent = values[2] as bool;
      biometricAvailable = values[3] as bool;
      loading = false;
    });
  }

  @override
  void dispose() {
    pin.dispose();
    pinConfirm.dispose();
    super.dispose();
  }

  Future<void> _setMode(AppLockMode value) async {
    if (value == AppLockMode.biometric) {
      if (!biometricAvailable) {
        _message(
          'Biometria non disponibile o non configurata sul dispositivo.',
        );
        return;
      }
      final ok = await security.authenticateBiometric();
      if (!ok) return;
    }
    if (value == AppLockMode.pin && !await security.hasPin()) {
      final created = await _createPin();
      if (!created) return;
    }
    await security.setMode(value);
    if (!mounted) return;
    setState(() => mode = value);
  }

  Future<bool> _createPin() async {
    pin.clear();
    pinConfirm.clear();
    final saved =
        await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (sheetContext) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Imposta PIN locale',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text('Usa da 4 a 8 cifre. Il PIN resta sul dispositivo.'),
                const SizedBox(height: 16),
                TextField(
                  controller: pin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  decoration: const InputDecoration(labelText: 'PIN'),
                ),
                TextField(
                  controller: pinConfirm,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  decoration: const InputDecoration(labelText: 'Conferma PIN'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      if (pin.text != pinConfirm.text ||
                          !RegExp(r'^\d{4,8}$').hasMatch(pin.text)) {
                        return;
                      }
                      await security.setPin(pin.text);
                      if (sheetContext.mounted) {
                        Navigator.pop(sheetContext, true);
                      }
                    },
                    child: const Text('Salva PIN'),
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;
    return saved;
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy locale')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                const SectionTitle('Blocco app'),
                _ModeTile(
                  icon: Icons.lock_open_rounded,
                  title: 'Disattivato',
                  subtitle: 'Apre DadaFinanza senza autenticazione.',
                  selected: mode == AppLockMode.off,
                  onTap: () => _setMode(AppLockMode.off),
                ),
                _ModeTile(
                  icon: Icons.fingerprint_rounded,
                  title: 'Biometria',
                  subtitle: biometricAvailable
                      ? 'Usa impronta o biometria configurata nel dispositivo.'
                      : 'Non disponibile su questo dispositivo.',
                  selected: mode == AppLockMode.biometric,
                  onTap: biometricAvailable
                      ? () => _setMode(AppLockMode.biometric)
                      : null,
                ),
                _ModeTile(
                  icon: Icons.pin_outlined,
                  title: 'PIN locale',
                  subtitle: 'Fallback semplice da 4 a 8 cifre.',
                  selected: mode == AppLockMode.pin,
                  onTap: () => _setMode(AppLockMode.pin),
                ),
                if (mode != AppLockMode.off) ...[
                  const SizedBox(height: 28),
                  const SectionTitle('Blocca dopo'),
                  ...AppLockTimeout.values.map(
                    (value) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      minVerticalPadding: 8,
                      leading: Icon(
                        value == timeout
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                      ),
                      title: Text(value.label),
                      onTap: () async {
                        await security.setTimeout(value);
                        if (mounted) setState(() => timeout = value);
                      },
                    ),
                  ),
                  if (mode == AppLockMode.pin)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.password_rounded),
                      title: const Text('Cambia PIN'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _createPin,
                    ),
                ],
                const SizedBox(height: 28),
                const SectionTitle('Schermata recenti'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.screenshot_monitor_outlined),
                  title: const Text('Nascondi contenuti sensibili'),
                  subtitle: const Text(
                    'Su Android impedisce screenshot e anteprima dell’app nelle schermate recenti.',
                  ),
                  value: secureRecent,
                  onChanged: (value) async {
                    await security.setSecureRecentApps(value);
                    if (mounted) setState(() => secureRecent = value);
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Dati, PIN e preferenze restano locali. Nessun account o server è coinvolto.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: 10,
    enabled: onTap != null,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: Icon(
      selected ? Icons.check_circle_rounded : Icons.circle_outlined,
    ),
    onTap: onTap,
  );
}
