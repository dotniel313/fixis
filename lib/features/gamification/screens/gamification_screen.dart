import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/fixis_ui.dart';

final gamificationProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;

  return Supabase.instance.client
      .from('expert_gamification')
      .select()
      .eq('pro_id', user.id)
      .maybeSingle();
});

class GamificationScreen extends ConsumerWidget {
  const GamificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamiAsync = ref.watch(gamificationProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Nivel FIXIS',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: FixisStatusPill(
                label: 'PROGRESO',
                color: AppTheme.warning,
                icon: Icons.workspace_premium_rounded,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: gamiAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _LoadErrorState(),
          data: (data) {
            if (data == null) {
              return const _EmptyGamificationState();
            }
  
            final rankValue = data['current_rank']?.toString().trim();
            final rank =
                (rankValue == null || rankValue.isEmpty) ? 'Inicial' : rankValue;
  
            final completed =
                (data['completed_jobs_count'] as num?)?.toInt() ?? 0;
            final target = (data['target_jobs_count'] as num?)?.toInt();
            final validTarget = target != null && target > 0 ? target : null;
  
            final progress = validTarget == null
                ? null
                : (completed / validTarget).clamp(0.0, 1.0).toDouble();
  
            final remaining = validTarget == null
                ? null
                : (validTarget - completed).clamp(0, validTarget);
  
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _buildHero(
                  rank: rank,
                  completed: completed,
                  target: validTarget,
                  progress: progress,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'Confirmados',
                        value: '$completed',
                        icon: Icons.task_alt_rounded,
                        color: AppTheme.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        label: validTarget == null
                            ? 'Meta'
                            : 'Para meta',
                        value: validTarget == null
                            ? '—'
                            : '${remaining ?? 0}',
                        icon: Icons.flag_rounded,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const FixisSectionHeader(
                  title: 'Cómo crece tu nivel',
                  subtitle: 'Solo usamos datos confirmados del sistema',
                ),
                const SizedBox(height: 10),
                FixisSurface(
                  shadows: const [],
                  border: Border.all(color: AppTheme.slate200),
                  child: const Column(
                    children: [
                      _ProgressRule(
                        icon: Icons.check_circle_rounded,
                        color: AppTheme.success,
                        title: 'Servicios aprobados',
                        text:
                            'Tu progreso aumenta cuando el cliente confirma el servicio.',
                      ),
                      SizedBox(height: 18),
                      _ProgressRule(
                        icon: Icons.shield_rounded,
                        color: AppTheme.primaryBlue,
                        title: 'Progreso respaldado',
                        text:
                            'Los rangos mostrados provienen de expert_gamification.',
                      ),
                      SizedBox(height: 18),
                      _ProgressRule(
                        icon: Icons.emoji_events_rounded,
                        color: AppTheme.warning,
                        title: 'Beneficios futuros',
                        text:
                            'Las insignias y beneficios aparecerán cuando existan reglas reales definidas.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
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
                        Icons.info_outline_rounded,
                        color: AppTheme.primaryBlue,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'FIXIS no mostrará rangos, insignias o beneficios ficticios. Tu nivel siempre se construye con información real de tus servicios.',
                          style: TextStyle(
                            color: AppTheme.slate700,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero({
    required String rank,
    required int completed,
    required int? target,
    required double? progress,
  }) {
    return Container(
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
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppTheme.warning,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rank.toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.primaryOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tu nivel FIXIS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const FixisStatusPill(
                label: 'VERIFICADO',
                color: AppTheme.success,
                icon: Icons.verified_rounded,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '$completed servicios confirmados',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (target != null && progress != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Progreso',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '$completed / $target',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 9,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryOrange,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FixisSurface(
      shadows: const [],
      border: Border.all(color: AppTheme.slate200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.darkSlate,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.slate500,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRule extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String text;

  const _ProgressRule({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
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
                  color: AppTheme.darkSlate,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: const TextStyle(
                  color: AppTheme.slate500,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyGamificationState extends StatelessWidget {
  const _EmptyGamificationState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.midnight, AppTheme.midnightSoft],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.all(
              Radius.circular(AppTheme.radiusLg),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  color: AppTheme.warning,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Tu nivel comienza con tu primer servicio',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cuando un cliente confirme tu servicio, FIXIS empezará a registrar tu progreso real.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.66),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FixisSurface(
        margin: const EdgeInsets.all(24),
        shadows: const [],
        border: Border.all(color: AppTheme.slate200),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: AppTheme.slate500,
              size: 42,
            ),
            SizedBox(height: 12),
            Text(
              'No fue posible cargar tu progreso en este momento.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.darkSlate,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
