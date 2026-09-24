import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../providers/auth_repository.dart';

class CustomerSignupScreen extends ConsumerStatefulWidget {
  const CustomerSignupScreen({super.key});

  @override
  ConsumerState<CustomerSignupScreen> createState() => _CustomerSignupScreenState();
}

class _CustomerSignupScreenState extends ConsumerState<CustomerSignupScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _sent = false;
  bool _loading = false;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _code.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    final repo = ref.read(authRepositoryProvider);
    final normalizedEmail = repo.normalizeEmail(_email.text);
    if (_name.text.trim().length < 2 || !normalizedEmail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa tu nombre y un correo válido.')));
      return;
    }
    setState(() => _loading = true);
    try {
      await repo.sendCustomerSignupOtp(
            email: normalizedEmail,
            fullName: _name.text.trim(),
            phone: _phone.text.trim(),
          );
      if (!mounted) return;
      _email.text = normalizedEmail;
      setState(() => _sent = true);
      _startResendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código enviado. Usa únicamente el correo más reciente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    if (_code.text.trim().length != 6) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.verifyOtp(repo.normalizeEmail(_email.text), _code.text.trim());
      final profile = await repo.getAccessProfile(forceRefresh: true);
      if (profile?['role'] != 'customer') {
        // The email may already belong to an admin or professional. Only
        // disclose that after the user has proved access to the mailbox.
        await repo.signOut();
        if (!mounted) return;
        setState(() {
          _sent = false;
          _code.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este correo ya pertenece a otra cuenta. Inicia sesión desde la pantalla anterior.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      repo.clearAccessCache();
      ref.invalidate(appAccessProvider);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  Future<void> _resend() async {
    if (_loading || _resendSeconds > 0) return;
    final repo = ref.read(authRepositoryProvider);
    final normalizedEmail = repo.normalizeEmail(_email.text);

    setState(() => _loading = true);
    try {
      await repo.sendCustomerSignupOtp(
        email: normalizedEmail,
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
      );
      _code.clear();
      if (!mounted) return;
      _startResendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nuevo código enviado. Usa únicamente el correo más reciente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta cliente')),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.home_repair_service, size: 58, color: AppTheme.primaryOrange),
            const SizedBox(height: 18),
            Text(_sent ? 'Verifica tu correo' : 'Únete a FIXIS', textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(_sent ? 'Ingresa el código enviado a ${_email.text.trim()}.' : 'Crea tu cuenta para solicitar y administrar servicios.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 28),
            if (!_sent) ...[
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre completo')),
              const SizedBox(height: 14),
              TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono (opcional)')),
              const SizedBox(height: 14),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo electrónico')),
              const SizedBox(height: 24),
              FilledButton(onPressed: _loading ? null : _send, child: const Text('Enviar código')),
            ] else ...[
              TextField(controller: _code, keyboardType: TextInputType.number, maxLength: 6, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: 'Código', counterText: '')),
              const SizedBox(height: 20),
              FilledButton(onPressed: _loading ? null : _verify, child: const Text('Crear cuenta y entrar')),
              const SizedBox(height: 8),
              TextButton(
                onPressed: (_loading || _resendSeconds > 0) ? null : _resend,
                child: Text(
                  _resendSeconds > 0
                      ? 'Reenviar código en 00:${_resendSeconds.toString().padLeft(2, '0')}'
                      : 'Reenviar código',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
