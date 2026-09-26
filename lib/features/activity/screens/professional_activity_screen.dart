import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/fixis_ui.dart';
import '../../jobs/providers/jobs_repository.dart';
import '../../jobs/screens/job_detail_screen.dart';

final completedProfessionalJobsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return const [];
  final rows = await client
      .from('jobs')
      .select('id, title, status, created_at, assigned_pro_id')
      .eq('assigned_pro_id', user.id)
      .eq('status', 'customer_approved')
      .order('created_at', ascending: false)
      .limit(20);
  return List<Map<String, dynamic>>.from(rows);
});

class ProfessionalActivityScreen extends ConsumerWidget {
  const ProfessionalActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(myActiveJobsStreamProvider);
    final completedAsync = ref.watch(completedProfessionalJobsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mi actividad',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
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
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Actividad FIXIS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Tu operación activa en un solo lugar',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.insights_rounded,
                    color: AppTheme.primaryOrange,
                    size: 34,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            activeAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, __) => const FixisSurface(
                shadows: [],
                child: Text(
                  'No pudimos cargar tu actividad en este momento.',
                ),
              ),
              data: (jobs) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            label: 'Activos',
                            value: '${jobs.length}',
                            icon: Icons.work_outline_rounded,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetricCard(
                            label: 'En ejecución',
                            value:
                                '${jobs.where((j) => j['status'] == 'in_progress').length}',
                            icon: Icons.play_circle_outline_rounded,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const FixisSectionHeader(
                      title: 'Servicios en curso',
                      subtitle: 'Acceso rápido a tus trabajos operativos',
                    ),
                    const SizedBox(height: 12),
                    if (jobs.isEmpty)
                      const FixisSurface(
                        shadows: [],
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              color: AppTheme.success,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No tienes servicios activos en este momento.',
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...jobs.map(
                        (job) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: FixisSurface(
                            padding: EdgeInsets.zero,
                            shadows: const [],
                            border: Border.all(color: AppTheme.slate200),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.primaryBlue.withValues(alpha: .08),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: const Icon(
                                  Icons.handyman_rounded,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                              title: Text(
                                job['title']?.toString() ?? 'Servicio',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                _statusLabel(job['status']?.toString() ?? ''),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => JobDetailScreen(job: job),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const FixisSectionHeader(
              title: 'Servicios confirmados',
              subtitle: 'Abre un servicio para calificar al cliente',
            ),
            const SizedBox(height: 12),
            completedAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('No pudimos cargar el historial.'),
              data: (jobs) => jobs.isEmpty
                  ? const Text('Todavía no tienes servicios confirmados.')
                  : Column(
                      children: jobs.map((job) => ListTile(
                        title: Text(job['title']?.toString() ?? 'Servicio'),
                        subtitle: const Text('Pago confirmado'),
                        trailing: const Icon(Icons.star_outline_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => JobDetailScreen(job: job),
                          ),
                        ),
                      )).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(String status) {
    return switch (status) {
      'accepted' => 'Cotización pendiente',
      'quote_submitted' => 'Esperando cliente',
      'authorized' => 'Autorizado',
      'en_route' => 'En camino',
      'arrived' => 'En ubicación',
      'in_progress' => 'En progreso',
      'work_completed' => 'Esperando aprobación',
      _ => status.replaceAll('_', ' '),
    };
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
          Icon(icon, color: color, size: 22),
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
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
