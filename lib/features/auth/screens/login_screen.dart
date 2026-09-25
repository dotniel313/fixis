// FIXIS PRO v1.1.1 - Login OTP optimizado para profesionales aprobados
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../providers/auth_repository.dart';
import 'customer_signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _codeSent = false;
  bool _otpRequestInFlight = false;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_otpRequestInFlight || _resendSeconds > 0) return;

    final repo = ref.read(authRepositoryProvider);
    final email = repo.normalizeEmail(_emailController.text);
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un correo válido.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _otpRequestInFlight = true;
    });

    // Start the protection window BEFORE waiting for Supabase.
    // A 504 may still represent an email request that was accepted upstream.
    _startResendCooldown();

    try {
      await repo.sendOtp(email);
      if (mounted) {
        setState(() {
          _emailController.text = email;
          _codeSent = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Código enviado. Usa únicamente el correo más reciente.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final deliveryUncertain =
            e is AuthFlowException && e.deliveryUncertain;
        if (!deliveryUncertain) {
          _resetResendCooldown();
        }
        setState(() {
          _isLoading = false;
          if (deliveryUncertain) {
            _emailController.text = email;
            _codeSent = true;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _otpRequestInFlight = false);
      } else {
        _otpRequestInFlight = false;
      }
    }
  }

  Future<void> _verifyCode() async {
    final repo = ref.read(authRepositoryProvider);
    final email = repo.normalizeEmail(_emailController.text);
    final code = _codeController.text.trim();
    
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El código debe tener 6 dígitos.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Verificamos OTP con Supabase.
      await repo.verifyOtp(email, code);

      // v1.6.1: el Auth Gate resuelve el rol real (customer/professional).
      repo.clearAccessCache();

      if (mounted) {
        ref.invalidate(appAccessProvider);
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
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

  void _resetResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 0);
  }

  Future<void> _resendCode() async {
    if (_resendSeconds > 0 || _isLoading || _otpRequestInFlight) return;
    final repo = ref.read(authRepositoryProvider);
    final email = repo.normalizeEmail(_emailController.text);

    setState(() {
      _isLoading = true;
      _otpRequestInFlight = true;
    });
    _startResendCooldown();

    try {
      await repo.sendOtp(email);
      _codeController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nuevo código enviado. El código anterior ya no debe usarse.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (e is! AuthFlowException || !e.deliveryUncertain) {
        _resetResendCooldown();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _otpRequestInFlight = false;
        });
      } else {
        _otpRequestInFlight = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              // Logo de la App
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.handyman, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 32),
              
              Text(
                _codeSent ? 'Ingresa tu código' : 'Bienvenido a FIXIS',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.darkSlate),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _codeSent 
                    ? 'Escribe el código de 6 dígitos que enviamos a\n${_emailController.text}'
                    : 'Ingresa tu correo para acceder a tu cuenta.',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Formulario Dinámico (Email o Código)
              if (!_codeSent) ...[
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  decoration: InputDecoration(
                    hintText: 'ejemplo@correo.com',
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: (_isLoading || _otpRequestInFlight || _resendSeconds > 0)
                      ? null
                      : _sendCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _resendSeconds > 0
                              ? 'Espera ${_resendSeconds}s'
                              : 'Enviar Código de Acceso',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ] else ...[
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '000000',
                    counterText: '',
                    filled: true,
                    fillColor: Colors.orange.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primaryOrange, width: 2)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primaryOrange, width: 2)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Verificar y Entrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                TextButton(
                  onPressed: (_isLoading || _resendSeconds > 0) ? null : _resendCode,
                  child: Text(
                    _resendSeconds > 0
                        ? 'Reenviar código en 00:${_resendSeconds.toString().padLeft(2, '0')}'
                        : 'Reenviar código',
                  ),
                ),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          _resendTimer?.cancel();
                          setState(() {
                            _codeSent = false;
                            _codeController.clear();
                            _resendSeconds = 0;
                          });
                        },
                  child: const Text('Usar otro correo', style: TextStyle(color: Colors.grey)),
                )
              ],
              if (!_codeSent) ...[
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CustomerSignupScreen()),
                    );
                  },
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Soy cliente: crear cuenta'),
                ),
              ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
