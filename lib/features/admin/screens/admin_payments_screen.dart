import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/fixis_ui.dart';
import 'admin_account_screen.dart';
import '../providers/admin_payments_repository.dart';

class AdminPaymentsScreen extends ConsumerStatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  ConsumerState<AdminPaymentsScreen> createState() =>
      _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends ConsumerState<AdminPaymentsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _pending = const [];
  List<Map<String, dynamic>> _resolved = const [];
  List<Map<String, dynamic>> _openSettlements = const [];
  List<Map<String, dynamic>> _settlementHistory = const [];
  List<Map<String, dynamic>> _settlementAudit = const [];
  Map<String, dynamic> _platformRevenue = const {};
  List<Map<String, dynamic>> _platformCommissions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(adminPaymentsRepositoryProvider);
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      final results = await Future.wait([
        repo.getPendingPayments(),
        repo.getRecentResolvedPayments(),
        repo.getOpenSettlements(),
        repo.getRecentSettlements(),
        repo.getSettlementAudit(),
        repo.getPlatformRevenueSummary(
          from: monthStart,
          to: now,
        ),
        repo.getPlatformCommissionEntries(),
      ]);

      if (!mounted) return;
      setState(() {
        _pending = results[0] as List<Map<String, dynamic>>;
        _resolved = results[1] as List<Map<String, dynamic>>;
        _openSettlements = results[2] as List<Map<String, dynamic>>;
        _settlementHistory = results[3] as List<Map<String, dynamic>>;
        _settlementAudit = results[4] as List<Map<String, dynamic>>;
        _platformRevenue = results[5] as Map<String, dynamic>;
        _platformCommissions = results[6] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppTheme.midnight,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 16,
          title: const FixisBrandMark(compact: true),
          actions: [
            FixisIconButton(
              tooltip: 'Actualizar',
              onPressed: _loading ? () {} : _load,
              icon: Icons.refresh_rounded,
            ),
            const SizedBox(width: 8),
            FixisIconButton(
              tooltip: 'Mi cuenta Admin',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminAccountScreen(),
                ),
              ),
              icon: Icons.admin_panel_settings_rounded,
            ),
            const SizedBox(width: 12),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppTheme.primaryOrange,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
            tabs: [
              Tab(text: 'Verificar (${_pending.length})'),
              const Tab(text: 'Historial'),
              Tab(text: 'Liquidaciones (${_openSettlements.length})'),
              const Tab(text: 'Ingresos FIXIS'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  children: [
                    _pendingTab(),
                    _resolvedTab(),
                    _settlementsTab(),
                    _platformRevenueTab(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _pendingTab() {
    if (_error != null) {
      return _empty(
        Icons.error_outline,
        'No pudimos cargar los pagos',
        _error!,
      );
    }

    if (_pending.isEmpty) {
      return _empty(
        Icons.verified_outlined,
        'Todo conciliado',
        'No hay transferencias esperando verificación.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _pending.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) => _pendingCard(_pending[index]),
      ),
    );
  }

  Widget _resolvedTab() {
    if (_resolved.isEmpty) {
      return _empty(
        Icons.receipt_long_outlined,
        'Sin historial todavía',
        'Los pagos confirmados o rechazados aparecerán aquí.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _resolved.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final row = _resolved[index];
          final status = row['status']?.toString() ?? '-';
          final paid = status == 'paid';

          final color = paid ? AppTheme.success : AppTheme.danger;
          return FixisSurface(
            padding: EdgeInsets.zero,
            shadows: const [],
            radius: AppTheme.radiusMd,
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
                  color: color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  paid ? Icons.check_rounded : Icons.close_rounded,
                  color: color,
                ),
              ),
              title: Text(
                row['job_title']?.toString() ?? 'Servicio FIXIS',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkSlate,
                ),
              ),
              subtitle: Text(
                '${row['customer_name'] ?? 'Cliente FIXIS'} · ${_money(row['total_due'])} · ${paid ? 'Pagado' : 'Rechazado'}',
                style: const TextStyle(color: AppTheme.slate500),
              ),
              trailing: FixisStatusPill(
                label: paid ? 'PAGADO' : 'RECHAZADO',
                color: color,
                icon: paid
                    ? Icons.verified_rounded
                    : Icons.warning_amber_rounded,
              ),
            ),
          );
        },
      ),
    );
  }



  Widget _platformRevenueTab() {
    final balance = _platformRevenue['ledger_balance'];
    final period = _platformRevenue['period_commissions'];
    final allTime = _platformRevenue['all_time_commissions'];
    final periodJobs = _platformRevenue['period_jobs'] ?? 0;
    final auditOk = _platformRevenue['audit_ok'] ?? 0;
    final auditReview = _platformRevenue['audit_review'] ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
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
              boxShadow: AppTheme.softShadow,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FixisStatusPill(
                        label: 'FINANZAS FIXIS',
                        color: AppTheme.primaryOrange,
                        icon: Icons.auto_graph_rounded,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Ingresos de plataforma',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Comisiones registradas en el ledger financiero.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.account_balance_rounded,
                  color: AppTheme.primaryOrange,
                  size: 38,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _revenueMetricCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Saldo contable FIXIS',
            value: _money(balance),
            subtitle: 'Cuenta FIXIS_REVENUE_USD',
          ),
          const SizedBox(height: 10),
          _revenueMetricCard(
            icon: Icons.calendar_month_rounded,
            title: 'Comisiones del mes',
            value: _money(period),
            subtitle: '$periodJobs servicios',
          ),
          const SizedBox(height: 10),
          _revenueMetricCard(
            icon: Icons.stacked_line_chart_rounded,
            title: 'Comisiones históricas',
            value: _money(allTime),
            subtitle: '${_platformRevenue['all_time_jobs'] ?? 0} servicios',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _auditSummaryCard(
                  'Verificadas',
                  auditOk.toString(),
                  Icons.verified_rounded,
                  AppTheme.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _auditSummaryCard(
                  'Revisar',
                  auditReview.toString(),
                  Icons.warning_amber_rounded,
                  auditReview == 0 ? Colors.grey : AppTheme.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const FixisSectionHeader(
            title: 'Detalle de comisiones',
            subtitle: 'Trazabilidad por servicio aprobado',
          ),
          const SizedBox(height: 8),
          if (_platformCommissions.isEmpty)
            _empty(
              Icons.receipt_long_outlined,
              'Sin comisiones todavía',
              'Las comisiones aparecerán cuando existan servicios pagados y aprobados.',
            )
          else
            ..._platformCommissions.map(_platformCommissionCard),
        ],
      ),
    );
  }

  Widget _revenueMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return FixisSurface(
      shadows: const [],
      border: Border.all(color: AppTheme.slate200),
      radius: AppTheme.radiusMd,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.slate500,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.darkSlate,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.slate500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _auditSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        color: color.withValues(alpha: 0.06),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _platformCommissionCard(Map<String, dynamic> row) {
    final auditStatus = row['audit_status']?.toString() ?? 'review';
    final ok = auditStatus == 'ok';

    return FixisSurface(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      shadows: const [],
      radius: AppTheme.radiusMd,
      border: Border.all(color: AppTheme.slate200),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row['job_title']?.toString() ?? 'Servicio FIXIS',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  _money(row['ledger_commission']),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _field('Total servicio', _money(row['gross_amount'])),
            _field('Mano de obra', _money(row['labor_amount'])),
            _field('Materiales', _money(row['materials_amount'])),
            _field(
              'Comisión',
              '${_money(row['snapshot_commission'])} · '
              '${_toDouble(row['commission_rate_percent']).toStringAsFixed(2)}%',
            ),
            _field('Profesional', _money(row['professional_amount'])),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: (ok ? Colors.green : Colors.red)
                    .withValues(alpha: 0.07),
                border: Border.all(
                  color: (ok ? Colors.green : Colors.red)
                      .withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    ok
                        ? Icons.verified_rounded
                        : Icons.warning_amber_rounded,
                    size: 17,
                    color: ok ? Colors.green : AppTheme.danger,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ok ? 'Comisión verificada' : 'Revisar comisión',
                    style: TextStyle(
                      color: ok ? Colors.green : AppTheme.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _settlementsTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _loading ? null : _generateWeeklyCut,
            icon: const Icon(Icons.calendar_month_rounded),
            label: const Text('Generar corte semanal'),
          ),
          const SizedBox(height: 16),
          if (_openSettlements.isEmpty)
            _empty(
              Icons.account_balance_wallet_outlined,
              'Sin liquidaciones pendientes',
              'Cuando exista saldo profesional disponible, genera el corte semanal.',
            )
          else ...[
            const FixisSectionHeader(
              title: 'Pendientes',
              subtitle: 'Liquidaciones que requieren gestión',
            ),
            const SizedBox(height: 8),
            ..._openSettlements.map(_settlementCard),
          ],
          if (_settlementHistory.isNotEmpty) ...[
            const SizedBox(height: 20),
            const FixisSectionHeader(
              title: 'Historial reciente',
              subtitle: 'Últimos cortes procesados',
            ),
            const SizedBox(height: 8),
            ..._settlementHistory.take(10).map(_settlementCard),
          ],
        ],
      ),
    );
  }


  Map<String, dynamic>? _auditForSettlement(String settlementId) {
    for (final audit in _settlementAudit) {
      if (audit['settlement_id']?.toString() == settlementId) {
        return audit;
      }
    }
    return null;
  }

  Widget _auditBadge(Map<String, dynamic>? audit) {
    final status = audit?['audit_status']?.toString() ?? 'unknown';

    final (label, icon, color) = switch (status) {
      'ok' => (
          'Ledger verificado',
          Icons.verified_rounded,
          AppTheme.success,
        ),
      'reserved' => (
          'Saldo reservado',
          Icons.lock_clock_rounded,
          AppTheme.warning,
        ),
      'closed_without_debit' => (
          'Cerrada sin débito',
          Icons.block_rounded,
          Colors.blueGrey,
        ),
      'review' => (
          'Revisar auditoría',
          Icons.warning_amber_rounded,
          AppTheme.danger,
        ),
      _ => (
          'Auditoría pendiente',
          Icons.help_outline_rounded,
          AppTheme.slate500,
        ),
    };

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settlementCard(Map<String, dynamic> settlement) {
    final status = settlement['status']?.toString() ?? '-';
    final requested = status == 'requested';
    final processing = status == 'processing';
    final audit = _auditForSettlement(settlement['id'].toString());

    return FixisSurface(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      shadows: const [],
      radius: AppTheme.radiusMd,
      border: Border.all(color: AppTheme.slate200),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _money(settlement['requested_amount']),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  _settlementStatusLabel(status),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _field(
              'Profesional',
              settlement['professional_name']?.toString().trim().isNotEmpty == true
                  ? settlement['professional_name'].toString()
                  : 'Profesional FIXIS',
            ),
            _field('Banco', settlement['bank_name']?.toString() ?? '-'),
            _field(
              'Cuenta',
              '${settlement['bank_account_type'] ?? '-'} · '
              '${settlement['bank_account_number'] ?? '-'}',
            ),
            _field(
              'Programado',
              settlement['scheduled_for']?.toString() ?? 'Sin fecha',
            ),
            if (settlement['payout_reference'] != null)
              _field(
                'Referencia',
                settlement['payout_reference'].toString(),
              ),
            if (audit != null) ...[
              _field(
                'Asignado',
                _money(audit['allocated_amount']),
              ),
              if (status == 'paid')
                _field(
                  'Débito ledger',
                  '${audit['settlement_debit_count'] ?? 0} · '
                  '${_money(audit['settlement_debit_amount'])}',
                ),
              _auditBadge(audit),
            ],
            if (requested || processing) ...[
              const SizedBox(height: 12),
              if (requested)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _markProcessing(settlement),
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Pasar a procesamiento'),
                  ),
                ),
              if (processing)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _markSettlementPaid(settlement),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Marcar como pagada'),
                  ),
                ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  onPressed: () => _rejectSettlement(settlement),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Rechazar liquidación'),
                ),
              ),
            ],
          ],
        ),
    );
  }

  Future<void> _generateWeeklyCut() async {
    final now = DateTime.now();
    final daysUntilFriday = (DateTime.friday - now.weekday + 7) % 7;
    final scheduled = DateTime(
      now.year,
      now.month,
      now.day + (daysUntilFriday == 0 ? 0 : daysUntilFriday),
    );

    try {
      final created = await ref
          .read(adminPaymentsRepositoryProvider)
          .createWeeklySettlements(
            cutoffAt: now,
            scheduledFor: scheduled,
          );

      if (!mounted) return;
      _snack(
        created.isEmpty
            ? 'No había saldo nuevo disponible para liquidar.'
            : 'Se generaron ${created.length} liquidaciones.',
        created.isEmpty ? Colors.orange : Colors.green,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString(), Colors.red);
    }
  }

  Future<void> _markProcessing(Map<String, dynamic> settlement) async {
    try {
      await ref
          .read(adminPaymentsRepositoryProvider)
          .markSettlementProcessing(settlement['id'].toString());
      if (!mounted) return;
      _snack('Liquidación en procesamiento.', Colors.orange);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString(), Colors.red);
    }
  }

  Future<void> _markSettlementPaid(
    Map<String, dynamic> settlement,
  ) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        var reference = '';
        var notes = '';
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: const Text(
            'Confirmar pago al profesional',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Confirma el desembolso de '
                  '${_money(settlement['requested_amount'])}.',
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => reference = v.trim(),
                  decoration: const InputDecoration(
                    labelText: 'Referencia bancaria',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => notes = v.trim(),
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop({
                'reference': reference,
                'notes': notes,
              }),
              child: const Text('Marcar pagada'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) return;

    try {
      await ref.read(adminPaymentsRepositoryProvider).markSettlementPaid(
            settlementId: settlement['id'].toString(),
            payoutReference: result['reference'],
            notes: result['notes'],
          );
      if (!mounted) return;
      _snack('Liquidación pagada.', Colors.green);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString(), Colors.red);
    }
  }

  Future<void> _rejectSettlement(
    Map<String, dynamic> settlement,
  ) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        var value = '';
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: const Text(
            'Rechazar liquidación',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: TextField(
            autofocus: false,
            minLines: 2,
            maxLines: 4,
            onChanged: (v) => value = v.trim(),
            decoration: const InputDecoration(
              labelText: 'Motivo',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                if (value.isEmpty) return;
                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('Rechazar'),
            ),
          ],
        );
      },
    );

    if (!mounted || reason == null || reason.isEmpty) return;

    try {
      await ref.read(adminPaymentsRepositoryProvider).rejectSettlement(
            settlementId: settlement['id'].toString(),
            reason: reason,
          );
      if (!mounted) return;
      _snack('Liquidación rechazada.', Colors.orange);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString(), Colors.red);
    }
  }

  Widget _pendingCard(Map<String, dynamic> payment) {
    final evidence = payment['latest_evidence'] as Map<String, dynamic>?;
    final reference = payment['reference_code']?.toString() ?? '-';
    final jobTitle = payment['job_title']?.toString() ?? 'Servicio FIXIS';
    final customerName = payment['customer_name']?.toString() ?? 'Cliente FIXIS';
    final professionalName = payment['professional_name']?.toString() ?? 'Fixi';
    final amount = _money(payment['total_due']);

    return FixisSurface(
      padding: const EdgeInsets.all(18),
      shadows: const [],
      radius: AppTheme.radiusMd,
      border: Border.all(color: AppTheme.slate200),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_balance_rounded,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    jobTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _field('Estado', payment['status']?.toString() ?? '-'),
            _field('Cliente', customerName),
            _field('Fixi', professionalName),
            _field('Categoría', payment['job_category']?.toString() ?? '-'),
            _field('Dirección', payment['job_address']?.toString() ?? '-'),
            _field('Referencia de pago', reference),
            _field(
              'Banco declarado',
              evidence?['declared_bank']?.toString() ?? 'No indicado',
            ),
            _field(
              'Referencia bancaria',
              evidence?['declared_reference']?.toString() ?? 'No indicada',
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360;

                final voucherButton = OutlinedButton.icon(
                  onPressed: evidence == null
                      ? null
                      : () => _openEvidence(evidence),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Ver voucher'),
                );

                final rejectButton = OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  onPressed: () => _reject(payment),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Rechazar'),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      voucherButton,
                      const SizedBox(height: 8),
                      rejectButton,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: voucherButton),
                    const SizedBox(width: 10),
                    Expanded(child: rejectButton),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _confirm(payment),
                icon: const Icon(Icons.verified_rounded),
                label: const Text('Confirmar acreditación'),
              ),
            ),
          ],
        ),
    );
  }

  Future<void> _openEvidence(Map<String, dynamic> evidence) async {
    final path = evidence['storage_path']?.toString() ?? '';
    if (path.isEmpty) return;

    try {
      final url = await ref
          .read(adminPaymentsRepositoryProvider)
          .createVoucherSignedUrl(path);

      if (!mounted || url == null) return;

      final provider = NetworkImage(url);

      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.88),
        builder: (dialogContext) {
          final media = MediaQuery.of(dialogContext);
          final targetWidth = (media.size.width * media.devicePixelRatio)
              .round()
              .clamp(720, 1600);

          return Dialog.fullscreen(
            backgroundColor: Colors.black,
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 5,
                      child: Center(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          cacheWidth: targetWidth,
                          filterQuality: FilterQuality.medium,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => const Center(
                            child: Text(
                              'No pudimos cargar el comprobante.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: IconButton.filledTonal(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Cerrar',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      // Payment vouchers can be high-resolution phone photos.
      // Release the decoded image after closing the viewer to reduce
      // memory pressure before navigating to another admin screen.
      await provider.evict();
    } catch (e) {
      _snack(e.toString(), Colors.red);
    }
  }

  Future<void> _confirm(Map<String, dynamic> payment) async {
    final amount = _toDouble(payment['total_due']);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        var transactionId = '';
        var bankReference = '';
        var notes = '';

        return AlertDialog(
          title: const Text('Confirmar acreditación'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Confirma en el banco que FIXIS recibió ${_money(amount)}.',
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (value) => transactionId = value.trim(),
                  decoration: const InputDecoration(
                    labelText: 'ID transacción bancaria',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) => bankReference = value.trim(),
                  decoration: const InputDecoration(
                    labelText: 'Referencia bancaria',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) => notes = value.trim(),
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop({
                  'transactionId': transactionId,
                  'bankReference': bankReference,
                  'notes': notes,
                });
              },
              child: const Text('Confirmar pago'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) return;

    try {
      await ref.read(adminPaymentsRepositoryProvider).verifyTransfer(
            paymentId: payment['id'].toString(),
            amount: amount,
            bankReference: result['bankReference'] ?? '',
            transactionId: result['transactionId'] ?? '',
            notes: result['notes'] ?? '',
          );

      if (!mounted) return;
      _snack('Pago confirmado y cierre financiero ejecutado.', Colors.green);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString(), Colors.red);
    }
  }

  Future<void> _reject(Map<String, dynamic> payment) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        var reasonValue = '';

        return AlertDialog(
          title: const Text('Rechazar comprobante'),
          content: TextField(
            autofocus: false,
            minLines: 2,
            maxLines: 4,
            onChanged: (value) => reasonValue = value.trim(),
            decoration: const InputDecoration(
              labelText: 'Motivo',
              hintText: 'Ej. monto no acreditado o comprobante incorrecto',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                if (reasonValue.isEmpty) return;
                Navigator.of(dialogContext).pop(reasonValue);
              },
              child: const Text('Rechazar'),
            ),
          ],
        );
      },
    );

    if (!mounted || reason == null || reason.isEmpty) return;

    try {
      await ref.read(adminPaymentsRepositoryProvider).rejectTransfer(
            paymentId: payment['id'].toString(),
            reason: reason,
          );
      if (!mounted) return;
      _snack('Comprobante rechazado.', Colors.orange);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString(), Colors.red);
    }
  }



  String _settlementStatusLabel(String status) {
    return switch (status) {
      'requested' => 'Pendiente',
      'processing' => 'Procesando',
      'paid' => 'Pagada',
      'rejected' => 'Rechazada',
      'cancelled' => 'Cancelada',
      _ => status,
    };
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: Colors.black26),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  double _toDouble(dynamic value) =>
      (value as num?)?.toDouble() ??
      double.tryParse(value?.toString() ?? '') ??
      0;

  String _money(dynamic value) =>
      '\$${_toDouble(value).toStringAsFixed(2)}';

  void _snack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }
}
