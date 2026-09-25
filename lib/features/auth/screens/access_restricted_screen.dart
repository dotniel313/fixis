// FIXIS PRO v1.1.0 - Estados de acceso restringido del profesional
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../providers/auth_repository.dart';

class AccessRestrictedScreen extends ConsumerStatefulWidget {
  final ProfessionalAccessStatus status;
  final Map<String, dynamic>? profile;
  final VoidCallback? onRetry;

  const AccessRestrictedScreen({
    super.key,
    required this.status,
    this.profile,
    this.onRetry,
  });

  @override
  ConsumerState<AccessRestrictedScreen> createState() =>
      _AccessRestrictedScreenState();
}

class _AccessRestrictedScreenState
    extends ConsumerState<AccessRestrictedScreen> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    await ref.read(authRepositoryProvider).signOut();
    if (!mounted) return;
    ref.invalidate(appAccessProvider);
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  _AccessCopy get _copy {
    switch (widget.status) {
      case ProfessionalAccessStatus.profileNotFound:
        return const _AccessCopy(
          icon: Icons.person_search_rounded,
          title: 'Perfil no disponible',
          message:
              'Tu usuario existe, pero todavía no encontramos un perfil profesional asociado. Contacta a soporte para completar la activación.',
        );
      case ProfessionalAccessStatus.notProfessional:
        return const _AccessCopy(
          icon: Icons.badge_outlined,
          title: 'Acceso solo para FIXIS',
          message:
              'Esta aplicación está reservada para profesionales registrados como FIXIS.',
        );
      case ProfessionalAccessStatus.pendingVerification:
        return const _AccessCopy(
          icon: Icons.hourglass_top_rounded,
          title: 'Verificación en proceso',
          message:
              'Tu registro fue recibido y todavía está siendo validado. Podrás aceptar trabajos cuando tu perfil sea aprobado.',
        );
      case ProfessionalAccessStatus.rejectedVerification:
        return const _AccessCopy(
          icon: Icons.assignment_late_outlined,
          title: 'Verificación no aprobada',
          message:
              'Tu verificación requiere revisión. Contacta a soporte para conocer los pasos necesarios.',
        );
      case ProfessionalAccessStatus.suspended:
        return const _AccessCopy(
          icon: Icons.pause_circle_outline_rounded,
          title: 'Cuenta suspendida',
          message:
              'Tu cuenta está temporalmente suspendida y no puede aceptar nuevos servicios.',
        );
      case ProfessionalAccessStatus.blocked:
        return const _AccessCopy(
          icon: Icons.block_rounded,
          title: 'Cuenta bloqueada',
          message:
              'El acceso de esta cuenta está bloqueado. Contacta a soporte para solicitar una revisión.',
        );
      default:
        return const _AccessCopy(
          icon: Icons.error_outline_rounded,
          title: 'No pudimos validar tu acceso',
          message:
              'Ocurrió un problema al comprobar el estado de tu cuenta. Intenta nuevamente.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copy;
    final name = widget.profile?['full_name']?.toString();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(
                        copy.icon,
                        color: AppTheme.primaryOrange,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (name != null && name.trim().isNotEmpty) ...[
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      copy.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkSlate,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      copy.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (widget.onRetry != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: widget.onRetry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Volver a comprobar'),
                        ),
                      ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _isSigningOut ? null : _signOut,
                        child: _isSigningOut
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Cerrar sesión'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessCopy {
  final IconData icon;
  final String title;
  final String message;

  const _AccessCopy({
    required this.icon,
    required this.title,
    required this.message,
  });
}
