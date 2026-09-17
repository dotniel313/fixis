import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/fixis_ui.dart';
import '../../auth/providers/auth_repository.dart';
import '../../auth/screens/login_screen.dart';

class AdminAccountScreen extends ConsumerWidget {
  const AdminAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final auth = ref.read(authRepositoryProvider);
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Mi cuenta Admin',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 40,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No fue posible cargar la cuenta administrativa.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => ref.invalidate(userProfileProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        data: (profile) {
          final fullName =
              profile?['full_name']?.toString().trim().isNotEmpty == true
                  ? profile!['full_name'].toString()
                  : 'Administrador FIXIS';

          final role = profile?['role']?.toString() ?? 'admin';
          final accountStatus =
              profile?['account_status']?.toString() ?? 'active';

          final roleLabel = switch (role) {
            'super_admin' => 'SUPER ADMIN',
            'admin' => 'ADMIN',
            _ => role.toUpperCase(),
          };

          final statusColor = accountStatus == 'active'
              ? AppTheme.success
              : AppTheme.warning;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.midnight, AppTheme.midnightSoft],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppTheme.radiusLg),
                  ),
                  boxShadow: AppTheme.floatingShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FixisBrandMark(compact: true),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primaryOrange,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FixisStatusPill(
                                label: roleLabel,
                                color: AppTheme.primaryOrange,
                                icon: Icons.security_rounded,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                fullName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                user?.email ?? 'Correo no disponible',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.62),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 300;
                        final statusMetric = _heroMetric(
                          Icons.verified_user_rounded,
                          'Estado',
                          accountStatus.toUpperCase(),
                          statusColor,
                        );
                        final accessMetric = _heroMetric(
                          Icons.lock_rounded,
                          'Acceso',
                          'PROTEGIDO',
                          AppTheme.primaryBlue,
                        );

                        if (narrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              statusMetric,
                              const SizedBox(height: 10),
                              accessMetric,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: statusMetric),
                            const SizedBox(width: 10),
                            Expanded(child: accessMetric),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const FixisSectionHeader(
                title: 'Identidad administrativa',
                subtitle:
                    'Datos utilizados para auditoría de operaciones internas',
              ),
              const SizedBox(height: 10),
              FixisSurface(
                padding: EdgeInsets.zero,
                shadows: const [],
                border: Border.all(color: AppTheme.slate200),
                child: Column(
                  children: [
                    _InfoTile(
                      icon: Icons.badge_outlined,
                      title: 'Nombre',
                      value: fullName,
                      color: AppTheme.primaryBlue,
                    ),
                    const Divider(indent: 60),
                    _InfoTile(
                      icon: Icons.email_outlined,
                      title: 'Correo',
                      value: user?.email ?? 'No disponible',
                      color: AppTheme.primaryOrange,
                    ),
                    const Divider(indent: 60),
                    _InfoTile(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Rol',
                      value: roleLabel,
                      color: AppTheme.primaryBlue,
                    ),
                    const Divider(indent: 60),
                    _InfoTile(
                      icon: Icons.shield_outlined,
                      title: 'Estado de cuenta',
                      value: accountStatus,
                      color: statusColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const FixisSectionHeader(
                title: 'Auditoría',
                subtitle:
                    'Las operaciones financieras registran quién las ejecutó',
              ),
              const SizedBox(height: 10),
              FixisSurface(
                shadows: const [],
                color: AppTheme.blueSoft,
                border: Border.all(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.fact_check_outlined,
                      color: AppTheme.primaryBlue,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'FIXIS conserva la trazabilidad de generación, procesamiento, pago y rechazo de liquidaciones mediante el usuario administrativo autenticado.',
                        style: TextStyle(
                          color: AppTheme.slate700,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const FixisSectionHeader(
                title: 'Sesión',
                subtitle: 'Control de acceso administrativo',
              ),
              const SizedBox(height: 10),
              FixisSurface(
                padding: EdgeInsets.zero,
                shadows: const [],
                border: Border.all(color: AppTheme.slate200),
                child: ListTile(
                  onTap: () async {
                    await auth.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                        (_) => false,
                      );
                    }
                  },
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: AppTheme.warning,
                    ),
                  ),
                  title: const Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      color: AppTheme.darkSlate,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.slate500,
                  ),
                ),
              ),
            ],
          );
        },
        ),
      ),
    );
  }

  static Widget _heroMetric(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.52),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.slate500,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.darkSlate,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
