import 'package:flutter/material.dart';

import '../services/security_service.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({
    required this.security,
    required this.child,
    super.key,
  });

  final SecurityService security;
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  final pinController = TextEditingController();
  bool loading = true;
  bool locked = false;
  bool authenticating = false;
  String? error;
  AppLockMode mode = AppLockMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    await widget.security.applyStoredPrivacy();
    mode = await widget.security.mode();
    if (!mounted) return;
    setState(() {
      loading = false;
      locked = mode != AppLockMode.off;
    });
    if (locked && mode == AppLockMode.biometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      widget.security.markBackgrounded();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _handleResume();
    }
  }

  Future<void> _handleResume() async {
    mode = await widget.security.mode();
    final shouldLock = await widget.security.shouldLockOnResume();
    if (!mounted || mode == AppLockMode.off || !shouldLock) return;
    setState(() {
      locked = true;
      error = null;
      pinController.clear();
    });
    if (mode == AppLockMode.biometric) await _biometric();
  }

  Future<void> _biometric() async {
    if (authenticating || !mounted) return;
    setState(() {
      authenticating = true;
      error = null;
    });
    final ok = await widget.security.authenticateBiometric();
    if (!mounted) return;
    setState(() {
      authenticating = false;
      locked = !ok;
      if (!ok) error = 'Autenticazione non riuscita.';
    });
  }

  Future<void> _verifyPin() async {
    final ok = await widget.security.verifyPin(pinController.text);
    if (!mounted) return;
    if (ok) {
      setState(() {
        locked = false;
        error = null;
        pinController.clear();
      });
    } else {
      setState(() => error = 'PIN non corretto.');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!locked || mode == AppLockMode.off) return widget.child;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 44),
                  const SizedBox(height: 16),
                  Text(
                    'DadaFinanza è bloccata',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mode == AppLockMode.biometric
                        ? 'Usa la biometria del dispositivo per continuare.'
                        : 'Inserisci il PIN locale per continuare.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (mode == AppLockMode.pin) ...[
                    TextField(
                      controller: pinController,
                      autofocus: true,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      maxLength: 8,
                      decoration: const InputDecoration(
                        labelText: 'PIN',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _verifyPin(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _verifyPin,
                        child: const Text('Sblocca'),
                      ),
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: authenticating ? null : _biometric,
                        icon: const Icon(Icons.fingerprint_rounded),
                        label: Text(
                          authenticating ? 'Verifica…' : 'Sblocca',
                        ),
                      ),
                    ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
