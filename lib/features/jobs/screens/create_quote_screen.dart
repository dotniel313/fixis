// FIXIS PRO v1.2.0 - Creación y envío de cotización.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../providers/jobs_repository.dart';

class CreateQuoteScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> job;
  final Map<String, dynamic>? initialQuote;

  const CreateQuoteScreen({
    super.key,
    required this.job,
    this.initialQuote,
  });

  @override
  ConsumerState<CreateQuoteScreen> createState() => _CreateQuoteScreenState();
}

class _CreateQuoteScreenState extends ConsumerState<CreateQuoteScreen> {
  late final TextEditingController _laborController;
  late final TextEditingController _materialsController;
  late final TextEditingController _otherController;
  late final TextEditingController _notesController;

  bool _isSaving = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final quote = widget.initialQuote;
    _laborController = TextEditingController(
      text: _formatEditableAmount(quote?['labor_amount']),
    );
    _materialsController = TextEditingController(
      text: _formatEditableAmount(quote?['materials_amount']),
    );
    _otherController = TextEditingController(
      text: _formatEditableAmount(quote?['other_amount']),
    );
    _notesController = TextEditingController(
      text: quote?['notes']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _laborController.dispose();
    _materialsController.dispose();
    _otherController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double _parseAmount(TextEditingController controller) {
    final normalized = controller.text.trim().replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  double get _total =>
      _parseAmount(_laborController) +
      _parseAmount(_materialsController) +
      _parseAmount(_otherController);

  String _formatEditableAmount(dynamic value) {
    if (value == null) return '';
    final amount = value is num ? value.toDouble() : double.tryParse('$value');
    if (amount == null || amount == 0) return '';
    return amount.toStringAsFixed(2);
  }

  Future<Map<String, dynamic>?> _saveDraft() async {
    if (_total <= 0) {
      _showError('El total de la cotización debe ser mayor que cero.');
      return null;
    }

    setState(() => _isSaving = true);

    try {
      final quote = await ref.read(jobsRepositoryProvider).createOrUpdateQuote(
            jobId: widget.job['id'].toString(),
            laborAmount: _parseAmount(_laborController),
            materialsAmount: _parseAmount(_materialsController),
            otherAmount: _parseAmount(_otherController),
            notes: _notesController.text,
          );

      if (!mounted) return null;
      setState(() => _isSaving = false);
      return quote;
    } on JobActionException catch (e) {
      if (!mounted) return null;
      setState(() => _isSaving = false);
      _showError(e.message);
    } catch (_) {
      if (!mounted) return null;
      setState(() => _isSaving = false);
      _showError('No fue posible guardar la cotización.');
    }

    return null;
  }

  Future<void> _handleSaveDraft() async {
    final quote = await _saveDraft();
    if (quote == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Borrador guardado.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_isSaving || _isSubmitting) return;

    final quote = await _saveDraft();
    if (quote == null || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      final submittedQuote = await ref
          .read(jobsRepositoryProvider)
          .submitQuote(quote['id'].toString());

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      Navigator.of(context).pop({
        'quote': submittedQuote,
        'submitted': true,
      });
    } on JobActionException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError('No fue posible enviar la cotización.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isSaving || _isSubmitting;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Preparar cotización',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.darkSlate,
      ),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _JobHeader(job: widget.job),
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
                    const Text(
                      'Detalle económico',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkSlate,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Separa mano de obra y materiales. FIXIS calculará la comisión en una versión posterior.',
                      style: TextStyle(color: Colors.grey, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    _MoneyField(
                      label: 'Mano de obra',
                      controller: _laborController,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    _MoneyField(
                      label: 'Materiales',
                      controller: _materialsController,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    _MoneyField(
                      label: 'Otros',
                      controller: _otherController,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'TOTAL',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkSlate,
                              ),
                            ),
                          ),
                          Text(
                            '\$${_total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _notesController,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notas para el cliente',
                        hintText: 'Describe el alcance, materiales o condiciones relevantes.',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: busy ? null : _handleSaveDraft,
                icon: const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Guardando...' : 'Guardar borrador'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                  side: const BorderSide(color: AppTheme.primaryBlue),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: busy ? null : _handleSubmit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isSubmitting ? 'Enviando cotización...' : 'Enviar cotización',
                ),
              ),
            ],
          ),
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
      ),
    );
  }
}

class _JobHeader extends StatelessWidget {
  final Map<String, dynamic> job;

  const _JobHeader({required this.job});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job['title']?.toString() ?? 'Servicio',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkSlate,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  job['client_name']?.toString() ?? 'Cliente',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
