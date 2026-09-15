import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/fixis_ui.dart';
import '../providers/notifications_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(myNotificationsStreamProvider);
    final unread = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Notificaciones',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (unread > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () async {
                  await ref
                      .read(notificationsRepositoryProvider)
                      .markAllAsRead();
                },
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Leer todas'),
              ),
            ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorState(
          onRetry: () => ref.invalidate(myNotificationsStreamProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myNotificationsStreamProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _NotificationsHero(
                  unread: unread,
                  total: items.length,
                ),
                const SizedBox(height: 20),
                const FixisSectionHeader(
                  title: 'Actividad reciente',
                  subtitle: 'Pagos y liquidaciones en tiempo real',
                ),
                const SizedBox(height: 12),
                ...items.map(
                  (notification) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _NotificationCard(
                      notification: notification,
                      onTap: () async {
                        if (notification['read_at'] == null) {
                          await ref
                              .read(notificationsRepositoryProvider)
                              .markAsRead(notification['id'].toString());
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NotificationsHero extends StatelessWidget {
  final int unread;
  final int total;

  const _NotificationsHero({
    required this.unread,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: AppTheme.primaryOrange,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unread == 0
                      ? 'Todo al día'
                      : '$unread ${unread == 1 ? 'novedad' : 'novedades'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total eventos financieros registrados',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.64),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const FixisStatusPill(
            label: 'REALTIME',
            color: AppTheme.success,
            icon: Icons.bolt_rounded,
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final type = notification['type']?.toString() ?? '';
    final unread = notification['read_at'] == null;
    final createdAt = DateTime.tryParse(
      notification['created_at']?.toString() ?? '',
    );

    final visual = switch (type) {
      'settlement_created' => (
          Icons.event_available_rounded,
          AppTheme.warning,
          'LIQUIDACIÓN',
        ),
      'settlement_processing' => (
          Icons.sync_rounded,
          AppTheme.primaryBlue,
          'PROCESANDO',
        ),
      'settlement_paid' => (
          Icons.verified_rounded,
          AppTheme.success,
          'PAGADO',
        ),
      'settlement_rejected' => (
          Icons.warning_amber_rounded,
          AppTheme.danger,
          'REVISAR',
        ),
      _ => (
          Icons.notifications_rounded,
          AppTheme.primaryBlue,
          'FIXIS',
        ),
    };

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: unread
                  ? visual.$2.withValues(alpha: 0.32)
                  : AppTheme.slate200,
            ),
            boxShadow: unread ? AppTheme.softShadow : const [],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: visual.$2.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(visual.$1, color: visual.$2, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification['title']?.toString() ??
                                'Notificación FIXIS',
                            style: const TextStyle(
                              color: AppTheme.darkSlate,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FixisStatusPill(
                          label: visual.$3,
                          color: visual.$2,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification['body']?.toString() ?? '',
                      style: const TextStyle(
                        color: AppTheme.slate500,
                        height: 1.42,
                        fontSize: 13,
                      ),
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: AppTheme.slate500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(createdAt.toLocal()),
                            style: const TextStyle(
                              color: AppTheme.slate500,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (unread) ...[
                            const Spacer(),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryOrange,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$d/$m/${value.year} · $h:$min';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppTheme.primaryOrange,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Todo al día',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Aquí aparecerán en tiempo real tus liquidaciones y pagos FIXIS.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.66),
                  fontSize: 13,
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

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FixisSurface(
        margin: const EdgeInsets.all(24),
        shadows: const [],
        border: Border.all(color: AppTheme.slate200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: AppTheme.slate500,
            ),
            const SizedBox(height: 12),
            const Text(
              'No pudimos cargar tus notificaciones.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppTheme.darkSlate,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
