import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/fixis_ui.dart';
import '../../auth/providers/auth_repository.dart';
import '../providers/customer_repository.dart';
import 'create_job_screen.dart';
import 'customer_job_detail_screen.dart';
import 'customer_profile_screen.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(myCustomerJobsProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final name = profileAsync.value?['full_name']?.toString() ?? 'Cliente';
    final firstName = name.trim().isEmpty ? 'Cliente' : name.trim().split(' ').first;
    final avatarUrl = profileAsync.value?['avatar_url']?.toString();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      floatingActionButton: SafeArea(
        minimum: const EdgeInsets.only(bottom: 12),
        child: FloatingActionButton.extended(
          backgroundColor: AppTheme.primaryOrange,
          foregroundColor: Colors.white,
          elevation: 4,
          onPressed: () async {
            final created = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const CreateJobScreen()),
            );
            if (created == true) ref.invalidate(myCustomerJobsProvider);
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Solicitar servicio',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(myCustomerJobsProvider.future),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 110),
            children: [
              _CustomerHero(
                firstName: firstName,
                avatarUrl: avatarUrl,
                onProfile: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CustomerProfileScreen(),
                  ),
                ),
                onCreate: () async {
                  final created = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const CreateJobScreen()),
                  );
                  if (created == true) {
                    ref.invalidate(myCustomerJobsProvider);
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                child: jobsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(36),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => const _InfoCard(
                    icon: Icons.cloud_off_rounded,
                    title: 'No pudimos cargar tus servicios',
                    subtitle: 'Desliza para actualizar o inténtalo nuevamente.',
                    color: AppTheme.danger,
                  ),
                  data: (jobs) {
                    if (jobs.isEmpty) {
                      return const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FixisSectionHeader(
                            title: 'Tus servicios',
                            subtitle: 'Todo comienza con tu primera solicitud',
                          ),
                          SizedBox(height: 12),
                          _InfoCard(
                            icon: Icons.home_repair_service_outlined,
                            title: 'Aún no tienes solicitudes',
                            subtitle:
                                'Cuéntanos qué necesitas y FIXIS buscará profesionales cercanos.',
                            color: AppTheme.primaryOrange,
                          ),
                        ],
                      );
                    }
  
                    const historicalStatuses = <String>{
                      'customer_approved',
                      'completed',
                      'cancelled',
                    };
  
                    final activeJobs = jobs
                        .where(
                          (job) => !historicalStatuses.contains(
                            job['status']?.toString(),
                          ),
                        )
                        .toList(growable: false);
  
                    final historyJobs = jobs
                        .where(
                          (job) => historicalStatuses.contains(
                            job['status']?.toString(),
                          ),
                        )
                        .toList(growable: false);
  
                    Widget buildJobCard(Map<String, dynamic> job) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _JobCard(
                          job: job,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CustomerJobDetailScreen(
                                  jobId: job['id'].toString(),
                                ),
                              ),
                            );
                            ref.invalidate(myCustomerJobsProvider);
                          },
                        ),
                      );
                    }
  
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FixisSectionHeader(
                          title: 'Servicios activos',
                          subtitle: activeJobs.isEmpty
                              ? 'No tienes servicios en curso'
                              : '${activeJobs.length} ${activeJobs.length == 1 ? 'servicio en curso' : 'servicios en curso'}',
                          trailing: FixisStatusPill(
                            label: activeJobs.isEmpty ? 'AL DÍA' : 'ACTIVOS',
                            color: activeJobs.isEmpty
                                ? AppTheme.success
                                : AppTheme.primaryBlue,
                            icon: activeJobs.isEmpty
                                ? Icons.check_circle_rounded
                                : Icons.bolt_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (activeJobs.isEmpty)
                          const _InfoCard(
                            icon: Icons.check_circle_outline_rounded,
                            title: 'Todo al día',
                            subtitle:
                                'Cuando solicites un servicio, podrás seguirlo aquí en tiempo real.',
                            color: AppTheme.success,
                          )
                        else
                          ...activeJobs.map(buildJobCard),
                        if (historyJobs.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const FixisSectionHeader(
                            title: 'Historial',
                            subtitle: 'Servicios finalizados y cancelados',
                          ),
                          const SizedBox(height: 12),
                          ...historyJobs.map(buildJobCard),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerHero extends StatelessWidget {
  final String firstName;
  final String? avatarUrl;
  final VoidCallback onProfile;
  final VoidCallback onCreate;

  const _CustomerHero({
    required this.firstName,
    required this.avatarUrl,
    required this.onProfile,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 58, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.midnight, AppTheme.midnightSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.radiusXl),
          bottomRight: Radius.circular(AppTheme.radiusXl),
        ),
        boxShadow: AppTheme.floatingShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FixisBrandMark(compact: true),
              const Spacer(),
              Tooltip(
                message: 'Mi perfil',
                child: GestureDetector(
                  onTap: onProfile,
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryOrange,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white.withValues(alpha: 0.10),
                      backgroundImage:
                          avatarUrl != null && avatarUrl!.trim().isNotEmpty
                              ? NetworkImage(avatarUrl!)
                              : null,
                      child: avatarUrl == null || avatarUrl!.trim().isEmpty
                          ? const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 22,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            'Hola, $firstName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tu hogar, resuelto con profesionales FIXIS.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Material(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: InkWell(
              onTap: onCreate,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.09),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color:
                            AppTheme.primaryOrange.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.add_home_work_rounded,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¿Necesitas ayuda?',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Publica una solicitud en pocos pasos',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppTheme.primaryOrange,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback onTap;

  const _JobCard({
    required this.job,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = job['status']?.toString() ?? 'pending';
    final visual = _statusVisual(status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.slate200),
            boxShadow: status == 'en_route' || status == 'in_progress'
                ? AppTheme.softShadow
                : const [],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: visual.$2.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  _categoryIcon(job['category']?.toString()),
                  color: visual.$2,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job['title']?.toString() ?? 'Servicio',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.darkSlate,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job['category']?.toString() ?? '',
                      style: const TextStyle(
                        color: AppTheme.slate500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 9),
                    FixisStatusPill(
                      label: visual.$1,
                      color: visual.$2,
                      icon: visual.$3,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.slate500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, Color, IconData) _statusVisual(String status) => switch (status) {
        'pending' => (
            'BUSCANDO FIXI',
            AppTheme.warning,
            Icons.search_rounded,
          ),
        'accepted' => (
            'FIXI ASIGNADO',
            AppTheme.primaryBlue,
            Icons.person_pin_circle_rounded,
          ),
        'quote_submitted' => (
            'COTIZACIÓN',
            AppTheme.primaryOrange,
            Icons.request_quote_rounded,
          ),
        'authorized' => (
            'APROBADO',
            AppTheme.primaryBlue,
            Icons.check_circle_rounded,
          ),
        'en_route' => (
            'EN CAMINO',
            AppTheme.primaryOrange,
            Icons.route_rounded,
          ),
        'arrived' => (
            'YA LLEGÓ',
            AppTheme.primaryBlue,
            Icons.location_on_rounded,
          ),
        'in_progress' => (
            'EN CURSO',
            AppTheme.success,
            Icons.handyman_rounded,
          ),
        'work_completed' => (
            'CONFIRMA EL SERVICIO',
            AppTheme.warning,
            Icons.task_alt_rounded,
          ),
        'customer_approved' => (
            'CONFIRMADO',
            AppTheme.success,
            Icons.verified_rounded,
          ),
        'completed' => (
            'COMPLETADO',
            AppTheme.success,
            Icons.check_circle_rounded,
          ),
        'cancelled' => (
            'CANCELADO',
            AppTheme.danger,
            Icons.cancel_outlined,
          ),
        _ => (
            status.toUpperCase(),
            AppTheme.slate500,
            Icons.info_outline_rounded,
          ),
      };

  IconData _categoryIcon(String? category) {
    final value = (category ?? '').toLowerCase();
    if (value.contains('electric')) return Icons.bolt_rounded;
    if (value.contains('plomer')) return Icons.water_drop_rounded;
    if (value.contains('cerraj')) return Icons.key_rounded;
    if (value.contains('clima')) return Icons.ac_unit_rounded;
    if (value.contains('electro')) return Icons.kitchen_rounded;
    if (value.contains('manten')) return Icons.build_rounded;
    return Icons.handyman_rounded;
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FixisSurface(
      shadows: const [],
      border: Border.all(color: AppTheme.slate200),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.darkSlate,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.slate500,
              height: 1.4,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
