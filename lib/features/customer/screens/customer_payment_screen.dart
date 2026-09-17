import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/theme.dart';
import '../providers/customer_repository.dart';

class CustomerPaymentScreen extends ConsumerStatefulWidget {
  final String jobId;

  const CustomerPaymentScreen({
    super.key,
    required this.jobId,
  });

  @override
  ConsumerState<CustomerPaymentScreen> createState() =>
      _CustomerPaymentScreenState();
}

class _CustomerPaymentScreenState
    extends ConsumerState<CustomerPaymentScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _referenceController = TextEditingController();

  Map<String, dynamic>? _payment;
  Map<String, dynamic>? _bankAccount;
  Map<String, dynamic>? _quote;

  XFile? _evidence;
  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(customerRepositoryProvider);
      final results = await Future.wait<dynamic>([
        repo.getPaymentForJob(widget.jobId),
        repo.getActiveBankAccount(),
        repo.getAcceptedQuoteForJob(widget.jobId),
      ]);

      if (!mounted) return;
      setState(() {
        _payment = results[0] as Map<String, dynamic>?;
        _bankAccount = results[1] as Map<String, dynamic>?;
        _quote = results[2] as Map<String, dynamic>?;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _prepareTransfer() async {
    if (_bankAccount == null) {
      _showError(
        'FIXIS todavía no tiene una cuenta bancaria activa configurada.',
      );
      return;
    }

    setState(() => _working = true);
    try {
      final payment =
          await ref.read(customerRepositoryProvider).prepareJobPayment(
                jobId: widget.jobId,
                paymentMethod: 'bank_transfer',
              );

      if (!mounted) return;
      setState(() => _payment = payment);
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _pickEvidence() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (image == null || !mounted) return;
    setState(() => _evidence = image);
  }

  Future<void> _submitEvidence() async {
    final payment = _payment;
    final evidence = _evidence;

    if (payment == null || evidence == null) {
      _showError('Selecciona el comprobante de la transferencia.');
      return;
    }

    setState(() => _working = true);

    try {
      final bytes = await evidence.readAsBytes();
      final extension = _extensionOf(evidence.name);
      final contentType =
          evidence.mimeType ?? _contentTypeForExtension(extension);

      final updated =
          await ref.read(customerRepositoryProvider).uploadBankTransferEvidence(
                paymentId: payment['id'].toString(),
                bytes: bytes,
                extension: extension,
                contentType: contentType,
                declaredAmount: _asDouble(payment['total_due']),
                declaredBank: _bankAccount?['bank_name']?.toString(),
                declaredReference: _referenceController.text,
              );

      if (!mounted) return;
      setState(() {
        _payment = updated;
        _evidence = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Comprobante recibido. Verificaremos la acreditación bancaria.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Aprobar y pagar')),
        body: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 12),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Aprobar y pagar')),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _summaryCard(),
              const SizedBox(height: 16),
              if (_error != null) ...[
                _noticeCard(
                  title: 'No pudimos cargar todo',
                  text: _error!,
                  icon: Icons.error_outline,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
              ],
              if (_payment == null)
                _methodSelection()
              else
                _paymentFlow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    final labor = _asDouble(_quote?['labor_amount']);
    final materials = _asDouble(_quote?['materials_amount']);
    final other = _asDouble(_quote?['other_amount']);

    var total = _asDouble(_quote?['total_amount']);
    if (total == 0 && _payment != null) {
      total = _asDouble(_payment?['service_amount']);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen del servicio',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          if (_quote != null) ...[
            _moneyRow('Mano de obra', labor),
            _moneyRow('Materiales', materials),
            _moneyRow('Otros', other),
            const Divider(height: 24),
          ],
          _moneyRow(
            'Total a pagar',
            total,
            bold: true,
            valueColor: AppTheme.primaryBlue,
          ),
        ],
      ),
    );
  }

  Widget _methodSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Cómo deseas pagar?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _paymentMethodCard(
          icon: Icons.account_balance_rounded,
          title: 'Transferencia bancaria',
          subtitle:
              'Sin confirmación automática. FIXIS verificará que el dinero se haya acreditado.',
          selected: true,
        ),
        const SizedBox(height: 10),
        _paymentMethodCard(
          icon: Icons.credit_card_rounded,
          title: 'Tarjeta',
          subtitle: 'Próximamente.',
          enabled: false,
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _working ? null : _prepareTransfer,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(
              _working
                  ? 'Preparando...'
                  : 'Continuar con transferencia',
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentFlow() {
    final status = _payment?['status']?.toString() ?? 'unpaid';

    if (status == 'paid') {
      return _noticeCard(
        title: 'Pago confirmado',
        text:
            'FIXIS confirmó la acreditación. El servicio puede continuar con su cierre financiero.',
        icon: Icons.verified_rounded,
        color: Colors.green,
      );
    }

    if (status == 'pending_verification' ||
        status == 'voucher_uploaded') {
      return Column(
        children: [
          _noticeCard(
            title: 'Comprobante en verificación',
            text:
                'Recibimos tu comprobante. El pago solo se marcará como pagado cuando FIXIS confirme que el dinero llegó a la cuenta.',
            icon: Icons.hourglass_top_rounded,
            color: Colors.orange,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _working ? null : _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar estado'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status == 'rejected') ...[
          _noticeCard(
            title: 'Comprobante rechazado',
            text:
                _payment?['rejection_reason']?.toString() ??
                    'No pudimos validar la transferencia. Puedes subir un nuevo comprobante.',
            icon: Icons.error_outline_rounded,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
        ],
        _bankTransferCard(),
        const SizedBox(height: 16),
        _evidenceCard(),
      ],
    );
  }

  Widget _bankTransferCard() {
    final bank = _bankAccount;

    if (bank == null) {
      return _noticeCard(
        title: 'Cuenta bancaria no configurada',
        text:
            'No realices ninguna transferencia todavía. FIXIS debe configurar una cuenta bancaria activa.',
        icon: Icons.account_balance_outlined,
        color: Colors.red,
      );
    }

    final paymentReference =
        _payment?['reference_code']?.toString() ?? '-';
    final totalDue = _asDouble(_payment?['total_due']);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_rounded),
              SizedBox(width: 10),
              Text(
                'Datos para transferir',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _copyRow('Banco', bank['bank_name']?.toString() ?? '-'),
          _copyRow(
            'Tipo de cuenta',
            _accountTypeLabel(bank['account_type']?.toString()),
          ),
          _copyRow(
            'Cuenta',
            bank['account_number']?.toString() ?? '-',
          ),
          _copyRow(
            'Beneficiario',
            bank['beneficiary_name']?.toString() ?? '-',
          ),
          if ((bank['beneficiary_id']?.toString() ?? '').isNotEmpty)
            _copyRow(
              'RUC / identificación',
              bank['beneficiary_id'].toString(),
            ),
          const Divider(height: 28),
          _copyRow(
            'Valor exacto',
            '\$${totalDue.toStringAsFixed(2)}',
          ),
          _copyRow(
            'Referencia FIXIS',
            paymentReference,
            emphasize: true,
          ),
          if ((bank['instructions']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              bank['instructions'].toString(),
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _evidenceCard() {
    if (_bankAccount == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comprobante',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'La captura es evidencia para conciliación. No confirma por sí sola que el pago se haya acreditado.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _working ? null : _pickEvidence,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(
              _evidence == null
                  ? 'Seleccionar comprobante'
                  : 'Cambiar comprobante',
            ),
          ),
          if (_evidence != null) ...[
            const SizedBox(height: 8),
            Text(
              _evidence!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _referenceController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Referencia bancaria (opcional)',
              hintText: 'Ej. número de operación',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  _working || _evidence == null ? null : _submitEvidence,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(
                _working ? 'Enviando...' : 'Enviar comprobante',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentMethodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    bool selected = false,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1 : .55,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryBlue.withValues(alpha: .07)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppTheme.primaryBlue : Colors.black12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? AppTheme.primaryBlue : Colors.black54,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                color: AppTheme.primaryBlue,
              ),
          ],
        ),
      ),
    );
  }

  Widget _copyRow(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight:
                    emphasize ? FontWeight.w900 : FontWeight.w700,
                color: emphasize ? AppTheme.primaryOrange : null,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copiar',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label copiado.')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _moneyRow(
    String label,
    double value, {
    bool bold = false,
    Color? valueColor,
  }) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
      fontSize: bold ? 18 : 15,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: style.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }

  Widget _noticeCard({
    required String title,
    required String text,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(18),
      ),
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
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  double _asDouble(dynamic value) =>
      (value as num?)?.toDouble() ?? 0;

  String _extensionOf(String name) {
    final index = name.lastIndexOf('.');
    if (index < 0 || index == name.length - 1) return 'jpg';
    return name.substring(index + 1).toLowerCase();
  }

  String _contentTypeForExtension(String extension) {
    return switch (extension.toLowerCase()) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  String _accountTypeLabel(String? value) => switch (value) {
        'checking' => 'Cuenta corriente',
        'savings' => 'Cuenta de ahorros',
        _ => value ?? '-',
      };
}
