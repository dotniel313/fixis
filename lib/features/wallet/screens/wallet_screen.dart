import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/fixis_ui.dart';
import '../../auth/providers/auth_repository.dart';

final walletV2Provider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;

  if (user == null) {
    return {
      'summary': {
        'available_balance': 0.0,
        'reserved_balance': 0.0,
        'total_earned': 0.0,
        'total_withdrawn': 0.0,
        'currency': 'USD',
      },
      'earnings': <Map<String, dynamic>>[],
      'settlements': <Map<String, dynamic>>[],
    };
  }

  final results = await Future.wait([
    client.rpc('get_wallet_summary'),
    client.rpc('get_professional_payout_schedule'),
  ]);

  final summaryResponse = results[0];
  final scheduleResponse = results[1];

  Map<String, dynamic> summary = {
    'available_balance': 0.0,
    'reserved_balance': 0.0,
    'total_earned': 0.0,
    'total_withdrawn': 0.0,
    'currency': 'USD',
  };

  if (summaryResponse is List && summaryResponse.isNotEmpty) {
    summary = Map<String, dynamic>.from(summaryResponse.first as Map);
  } else if (summaryResponse is Map) {
    summary = Map<String, dynamic>.from(summaryResponse);
  }

  Map<String, dynamic> payoutSchedule = {
    'next_cut_date': null,
    'active_settlement_id': null,
    'active_settlement_amount': null,
    'active_settlement_status': null,
    'active_scheduled_for': null,
    'last_paid_amount': null,
    'last_paid_at': null,
    'last_payout_reference': null,
  };

  if (scheduleResponse is List && scheduleResponse.isNotEmpty) {
    payoutSchedule =
        Map<String, dynamic>.from(scheduleResponse.first as Map);
  } else if (scheduleResponse is Map) {
    payoutSchedule = Map<String, dynamic>.from(scheduleResponse);
  }

  final earningsResponse = await client
      .from('financial_ledger_entries')
      .select('id, entry_type, direction, amount, status, description, created_at')
      .eq('entry_type', 'professional_earning')
      .order('created_at', ascending: false)
      .limit(20);

  final settlementsResponse = await client
      .from('settlements')
      .select(
        'id, requested_amount, currency, status, bank_name, bank_account_type, '
        'bank_account_number, requested_at, processing_at, paid_at, rejected_at, '
        'cancelled_at, rejection_reason, created_at, generated_by, '
        'scheduled_for, payout_reference, payment_notes',
      )
      .order('created_at', ascending: false)
      .limit(20);

  return {
    'summary': summary,
    'payout_schedule': payoutSchedule,
    'earnings': List<Map<String, dynamic>>.from(earningsResponse),
    'settlements': List<Map<String, dynamic>>.from(settlementsResponse),
  };
});

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _money(dynamic value) => '\$${_toDouble(value).toStringAsFixed(2)}';

  Future<void> _refresh() async {
    ref.invalidate(walletV2Provider);
    ref.invalidate(userProfileProvider);
    await ref.read(walletV2Provider.future);
  }

  Future<void> _cancelWithdrawal(String settlementId) async {
    try {
      await Supabase.instance.client.rpc(
        'cancel_withdrawal',
        params: {'p_settlement_id': settlementId},
      );
      if (!mounted) return;
      _showSnack('Solicitud de retiro cancelada.', Colors.green);
      await _refresh();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      _showSnack(_friendlyRpcError(e.message), Colors.red);
    }
  }

  String _friendlyRpcError(String raw) {
    if (raw.contains('PAYOUT_DETAILS_REQUIRED')) {
      return 'Completa tus datos bancarios antes de solicitar un retiro.';
    }
    if (raw.contains('INSUFFICIENT_AVAILABLE_BALANCE')) {
      return 'El saldo disponible cambió. Actualiza la billetera e intenta nuevamente.';
    }
    if (raw.contains('FINANCIAL_ACCOUNT_NOT_FOUND')) {
      return 'Aún no tienes una cuenta financiera habilitada.';
    }
    if (raw.contains('SETTLEMENT_CANNOT_BE_CANCELLED')) {
      return 'Este retiro ya está siendo procesado y no puede cancelarse.';
    }
    return 'No se pudo completar la operación.';
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletV2Provider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Billetera',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: FixisStatusPill(
                label: 'FIXIS PRO',
                color: AppTheme.primaryOrange,
                icon: Icons.verified_rounded,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: walletAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _buildError(error),
          data: (data) {
            final summary = Map<String, dynamic>.from(data['summary'] as Map);
            final payoutSchedule =
                Map<String, dynamic>.from(data['payout_schedule'] as Map);
            final earnings = List<Map<String, dynamic>>.from(data['earnings'] as List);
            final settlements = List<Map<String, dynamic>>.from(data['settlements'] as List);
  
            final available = _toDouble(summary['available_balance']);
            final reserved = _toDouble(summary['reserved_balance']);
            final earned = _toDouble(summary['total_earned']);
            final withdrawn = _toDouble(summary['total_withdrawn']);
  
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                children: [
                  _buildBalanceCard(
                    available: available,
                    reserved: reserved,
                    earned: earned,
                    withdrawn: withdrawn,
                  ),
                  const SizedBox(height: 16),
                  _buildNextPayoutCard(
                    payoutSchedule: payoutSchedule,
                    available: available,
                  ),
                  const SizedBox(height: 24),
                  _buildMetrics(
                    reserved: reserved,
                    earned: earned,
                    withdrawn: withdrawn,
                  ),
                  const SizedBox(height: 32),
                  _sectionTitle('Cuenta de destino'),
                  const SizedBox(height: 12),
                  _buildBankCard(profileAsync),
                  const SizedBox(height: 32),
                  _sectionTitle('Liquidaciones'),
                  const SizedBox(height: 12),
                  if (settlements.isEmpty)
                    _emptyCard('Aún no tienes liquidaciones registradas.')
                  else
                    ...settlements.map(_buildSettlementItem),
                  const SizedBox(height: 32),
                  _sectionTitle('Ganancias recientes'),
                  const SizedBox(height: 12),
                  if (earnings.isEmpty)
                    _emptyCard('Aún no tienes ganancias registradas en el ledger.')
                  else
                    ...earnings.map(_buildEarningItem),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }


  Widget _buildNextPayoutCard({
    required Map<String, dynamic> payoutSchedule,
    required double available,
  }) {
    final activeStatus =
        payoutSchedule['active_settlement_status']?.toString();
    final activeAmount =
        _toDouble(payoutSchedule['active_settlement_amount']);
    final scheduledFor =
        payoutSchedule['active_scheduled_for']?.toString();
    final nextCut = payoutSchedule['next_cut_date']?.toString();

    final hasActive =
        activeStatus == 'requested' || activeStatus == 'processing';

    String title;
    String subtitle;
    IconData icon;
    Color color;

    if (activeStatus == 'processing') {
      title = 'Pago en procesamiento';
      subtitle =
          '${_money(activeAmount)} está siendo transferido por FIXIS.'
          '${scheduledFor != null ? ' Programado: $scheduledFor.' : ''}';
      icon = Icons.sync_rounded;
      color = AppTheme.primaryBlue;
    } else if (activeStatus == 'requested') {
      title = 'Liquidación preparada';
      subtitle =
          '${_money(activeAmount)} está reservado para tu próximo pago.'
          '${scheduledFor != null ? ' Programado: $scheduledFor.' : ''}';
      icon = Icons.lock_clock_rounded;
      color = AppTheme.warning;
    } else {
      title = 'Próximo corte semanal';
      subtitle = available > 0
          ? 'Tu saldo disponible de ${_money(available)} entrará al próximo '
              'corte de viernes${nextCut != null ? ' ($nextCut)' : ''}.'
          : 'El próximo corte será el viernes'
              '${nextCut != null ? ' ($nextCut)' : ''}. '
              'Las nuevas ganancias aprobadas aparecerán aquí.';
      icon = Icons.event_available_rounded;
      color = AppTheme.success;
    }

    return FixisSurface(
      padding: const EdgeInsets.all(16),
      shadows: const [],
      color: color.withValues(alpha: 0.055),
      border: Border.all(color: color.withValues(alpha: 0.18)),
      radius: AppTheme.radiusMd,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkSlate,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    height: 1.35,
                    fontSize: 13,
                  ),
                ),
                if (hasActive &&
                    payoutSchedule['last_payout_reference'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Última referencia: '
                    '${payoutSchedule['last_payout_reference']}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard({
    required double available,
    required double reserved,
    required double earned,
    required double withdrawn,
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
              const Expanded(
                child: Text(
                  'SALDO DISPONIBLE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppTheme.primaryOrange,
                  size: 21,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _money(available),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            reserved > 0
                ? '${_money(reserved)} están reservados para tu próxima liquidación.'
                : 'Ganancias aprobadas y disponibles para tu próximo corte.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics({
    required double reserved,
    required double earned,
    required double withdrawn,
  }) {
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            'Reservado',
            _money(reserved),
            Icons.lock_clock_rounded,
            AppTheme.warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metricCard(
            'Ganado',
            _money(earned),
            Icons.trending_up_rounded,
            AppTheme.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metricCard(
            'Retirado',
            _money(withdrawn),
            Icons.account_balance_rounded,
            AppTheme.primaryBlue,
          ),
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return FixisSurface(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      shadows: const [],
      radius: AppTheme.radiusMd,
      border: Border.all(color: AppTheme.slate200),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkSlate,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildBankCard(AsyncValue<Map<String, dynamic>?> profileAsync) {
    return profileAsync.when(
      data: (profile) {
        final bank = (profile?['bank'] ?? '').toString().trim();
        final accountType = (profile?['account_type'] ?? '').toString().trim();
        final accountNumber = (profile?['account_number'] ?? '').toString().trim();
        final complete = bank.isNotEmpty && accountType.isNotEmpty && accountNumber.isNotEmpty;

        String masked = 'Sin registrar';
        if (accountNumber.length >= 4) {
          masked = '**** ${accountNumber.substring(accountNumber.length - 4)}';
        } else if (accountNumber.isNotEmpty) {
          masked = accountNumber;
        }

        return FixisSurface(
          padding: const EdgeInsets.all(18),
          shadows: const [],
          border: Border.all(color: AppTheme.slate200),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.blueSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bank.isEmpty ? 'Datos bancarios pendientes' : bank,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.darkSlate,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      complete ? '$accountType • $masked' : 'Completa tu perfil para poder retirar.',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(
                complete ? Icons.check_circle : Icons.warning_amber_rounded,
                color: complete ? AppTheme.success : AppTheme.warning,
                size: 20,
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _emptyCard('No se pudieron cargar los datos bancarios.'),
    );
  }

  Widget _buildSettlementItem(Map<String, dynamic> settlement) {
    final status = settlement['status']?.toString() ?? 'requested';
    final generatedByFixis = settlement['generated_by'] != null;
    final canCancel = status == 'requested' && !generatedByFixis;

    String label;
    Color color;
    IconData icon;

    switch (status) {
      case 'processing':
        label = 'En procesamiento';
        color = AppTheme.primaryBlue;
        icon = Icons.sync_rounded;
        break;
      case 'paid':
        label = 'Pagado';
        color = AppTheme.success;
        icon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        label = 'Rechazado';
        color = AppTheme.danger;
        icon = Icons.cancel_rounded;
        break;
      case 'cancelled':
        label = 'Cancelado';
        color = Colors.grey;
        icon = Icons.block_rounded;
        break;
      default:
        label = 'Solicitado';
        color = AppTheme.warning;
        icon = Icons.schedule_rounded;
    }

    return FixisSurface(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      shadows: const [],
      border: Border.all(color: AppTheme.slate200),
      radius: AppTheme.radiusMd,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _money(settlement['requested_amount']),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkSlate,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                if (settlement['scheduled_for'] != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Programado: ${settlement['scheduled_for']}',
                    style: const TextStyle(
                      color: Colors.black45,
                      fontSize: 11,
                    ),
                  ),
                ],
                if (status == 'paid' &&
                    settlement['payout_reference'] != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Ref. ${settlement['payout_reference']}',
                    style: const TextStyle(
                      color: Colors.black45,
                      fontSize: 11,
                    ),
                  ),
                ],
                if (status == 'rejected' && settlement['rejection_reason'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    settlement['rejection_reason'].toString(),
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (canCancel)
            TextButton(
              onPressed: () => _cancelWithdrawal(settlement['id'].toString()),
              child: const Text('Cancelar'),
            ),
        ],
      ),
    );
  }

  Widget _buildEarningItem(Map<String, dynamic> entry) {
    return FixisSurface(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      shadows: const [],
      border: Border.all(color: AppTheme.slate200),
      radius: AppTheme.radiusMd,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_rounded,
              color: Colors.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry['description']?.toString() ?? 'Ingreso por servicio aprobado',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkSlate,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Disponible',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${_money(entry['amount'])}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              'No se pudo cargar la billetera.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.darkSlate,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.invalidate(walletV2Provider),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return FixisSectionHeader(title: text);
  }

  Widget _emptyCard(String message) {
    return FixisSurface(
      padding: const EdgeInsets.all(18),
      shadows: const [],
      border: Border.all(color: AppTheme.slate200),
      child: Row(
        children: [
          const Icon(
            Icons.inbox_outlined,
            color: AppTheme.slate500,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.slate500),
            ),
          ),
        ],
      ),
    );
  }
}
