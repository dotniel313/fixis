// FIXIS PRO v1.3.0 - Resumen de cotización con estado de aprobación.
import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

class QuoteSummaryScreen extends StatelessWidget {
  final Map<String, dynamic> job;
  final Map<String, dynamic> quote;

  const QuoteSummaryScreen({
    super.key,
    required this.job,
    required this.quote,
  });

  double _amount(String key) {
    final value = quote[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get _status => quote['status']?.toString() ?? 'draft';

  @override
  Widget build(BuildContext context) {
    final isSubmitted = _status == 'submitted';
    final isAccepted = _status == 'accepted';

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Cotización',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.darkSlate,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isAccepted
                      ? Colors.green.withValues(alpha: 0.08)
                      : isSubmitted
                          ? AppTheme.primaryBlue.withValues(alpha: 0.08)
                          : Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAccepted
                          ? Icons.verified_rounded
                          : isSubmitted
                              ? Icons.schedule_rounded
                              : Icons.edit_note_rounded,
                      color: isAccepted
                          ? Colors.green
                          : isSubmitted
                              ? AppTheme.primaryBlue
                              : Colors.orange.shade800,
                      size: 32,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAccepted
                                ? 'Cotización aprobada'
                                : isSubmitted
                                    ? 'Esperando aprobación del cliente'
                                    : 'Cotización en borrador',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkSlate,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isAccepted
                                ? 'El cliente aprobó esta cotización. Regresa al servicio para ver el resumen económico e iniciar el trabajo.'
                                : isSubmitted
                                    ? 'No inicies el trabajo todavía. El siguiente paso será la aprobación del cliente.'
                                    : 'Puedes editarla antes de enviarla.',
                            style: const TextStyle(color: Colors.grey, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job['title']?.toString() ?? 'Servicio',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkSlate,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job['client_name']?.toString() ?? 'Cliente',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    _AmountRow(label: 'Mano de obra', amount: _amount('labor_amount')),
                    const SizedBox(height: 12),
                    _AmountRow(label: 'Materiales', amount: _amount('materials_amount')),
                    const SizedBox(height: 12),
                    _AmountRow(label: 'Otros', amount: _amount('other_amount')),
                    const Divider(height: 32),
                    _AmountRow(
                      label: 'TOTAL',
                      amount: _amount('total_amount'),
                      emphasized: true,
                    ),
                    if ((quote['notes']?.toString().trim().isNotEmpty ?? false)) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Notas',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkSlate,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        quote['notes'].toString(),
                        style: const TextStyle(color: Colors.black87, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.dashboard_outlined),
                label: const Text('Volver'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                  side: const BorderSide(color: AppTheme.primaryBlue),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool emphasized;

  const _AmountRow({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: emphasized ? FontWeight.bold : FontWeight.w500,
              color: AppTheme.darkSlate,
              fontSize: emphasized ? 17 : 15,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            '\$${amount.toStringAsFixed(2)}',
            textAlign: TextAlign.end,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: emphasized ? 22 : 16,
              color: emphasized ? AppTheme.primaryOrange : AppTheme.darkSlate,
            ),
          ),
        ),
      ],
    );
  }
}
