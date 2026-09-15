// FIXIS PRO v1.10.8.6 - Cotización revisada después de la llegada.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../providers/jobs_repository.dart';

class RevisionQuoteScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> job;
  final Map<String, dynamic> currentQuote;

  const RevisionQuoteScreen({
    super.key,
    required this.job,
    required this.currentQuote,
  });

  @override
  ConsumerState<RevisionQuoteScreen> createState() => _RevisionQuoteScreenState();
}

class _RevisionQuoteScreenState extends ConsumerState<RevisionQuoteScreen> {
  late final TextEditingController _labor;
  late final TextEditingController _materials;
  late final TextEditingController _other;
  late final TextEditingController _reason;
  late final TextEditingController _notes;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _labor = TextEditingController(text: _editable(widget.currentQuote['labor_amount']));
    _materials = TextEditingController(text: _editable(widget.currentQuote['materials_amount']));
    _other = TextEditingController(text: _editable(widget.currentQuote['other_amount']));
    _reason = TextEditingController();
    _notes = TextEditingController(text: widget.currentQuote['notes']?.toString() ?? '');
  }

  @override
  void dispose() {
    _labor.dispose();
    _materials.dispose();
    _other.dispose();
    _reason.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _editable(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    return (number ?? 0).toStringAsFixed(2);
  }

  double _amount(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;

  double get _total => _amount(_labor) + _amount(_materials) + _amount(_other);

  Future<void> _submit() async {
    final reason = _reason.text.trim();
    if (reason.length < 5) {
      _show('Explica brevemente por qué cambió el alcance.');
      return;
    }
    if (_total <= 0) {
      _show('El total revisado debe ser mayor que cero.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final quote = await ref.read(jobsRepositoryProvider).submitQuoteRevision(
            jobId: widget.job['id'].toString(),
            laborAmount: _amount(_labor),
            materialsAmount: _amount(_materials),
            otherAmount: _amount(_other),
            revisionReason: reason,
            notes: _notes.text,
          );

      if (!mounted) return;
      Navigator.of(context).pop<Map<String, dynamic>>({
        'submitted': true,
        'quote': quote,
      });
    } on JobActionException catch (e) {
      _show(e.message);
    } catch (_) {
      _show('No fue posible enviar la cotización revisada.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final originalTotal = (widget.currentQuote['total_amount'] as num?)?.toDouble() ??
        double.tryParse(widget.currentQuote['total_amount']?.toString() ?? '') ??
        0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('Revisar cotización')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withValues(alpha: .2)),
              ),
              child: Text(
                'Cotización vigente: \$${originalTotal.toStringAsFixed(2)}. '
                'La original quedará preservada y el cliente deberá aceptar '
                'expresamente esta revisión antes de iniciar el trabajo.',
                style: const TextStyle(height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _reason,
              minLines: 3,
              maxLines: 5,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Motivo del cambio de alcance *',
                hintText: 'Ej.: se detectó una tubería interna dañada no visible inicialmente.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _MoneyField(label: 'Mano de obra', controller: _labor, onChanged: (_) => setState(() {})),
            const SizedBox(height: 12),
            _MoneyField(label: 'Materiales', controller: _materials, onChanged: (_) => setState(() {})),
            const SizedBox(height: 12),
            _MoneyField(label: 'Otros', controller: _other, onChanged: (_) => setState(() {})),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notas adicionales',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Nuevo total',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '\$${_total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_submitting ? 'Enviando...' : 'Enviar revisión al cliente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _MoneyField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,6}([\.,]\d{0,2})?')),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixText: '\$ ',
        border: const OutlineInputBorder(),
      ),
    );
  }
}
