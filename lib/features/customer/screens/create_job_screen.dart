import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/fixis_ui.dart';
import '../providers/customer_repository.dart';

class CreateJobScreen extends ConsumerStatefulWidget {
  const CreateJobScreen({super.key});

  @override
  ConsumerState<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends ConsumerState<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _addressReference = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _issuePhotos = [];
  DateTime? _requestedVisitAt;

  String _category = 'Plomería';
  bool _loading = false;
  bool _loadingLocation = false;
  Position? _servicePosition;

  static const categories = [
    'Plomería',
    'Electricidad',
    'Cerrajería',
    'Climatización',
    'Electrodomésticos',
    'Mantenimiento',
    'Otro',
  ];

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _address.dispose();
    _addressReference.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _loadingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception(
          'Activa la ubicación del teléfono para continuar.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'FIXIS necesita permiso de ubicación para publicar el servicio.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() => _servicePosition = position);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ubicación del servicio confirmada.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _pickIssuePhoto(ImageSource source) async {
    if (_issuePhotos.length >= 3) return;
    try {
      final photo = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (photo == null || !mounted) return;
      setState(() => _issuePhotos.add(photo));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos abrir la cámara o galería.')),
      );
    }
  }

  Future<void> _selectRequestedVisit() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _requestedVisitAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _requestedVisitAt ?? now.add(const Duration(hours: 2)),
      ),
    );
    if (time == null || !mounted) return;

    final selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (selected.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una fecha y hora futura.')),
      );
      return;
    }
    setState(() => _requestedVisitAt = selected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_servicePosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Confirma la ubicación del servicio antes de publicar.',
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final repo = ref.read(customerRepositoryProvider);
      final job = await repo.createJob(
        title: _title.text,
        category: _category,
        address: _address.text,
        addressReference: _addressReference.text,
        requestedVisitAt: _requestedVisitAt,
        description: _description.text,
        latitude: _servicePosition!.latitude,
        longitude: _servicePosition!.longitude,
      );

      final jobId = job['id']?.toString();
      var failedPhotos = 0;
      if (jobId != null && jobId.isNotEmpty) {
        for (final photo in _issuePhotos) {
          try {
            final bytes = await photo.readAsBytes();
            final name = photo.name.toLowerCase();
            final extension = name.contains('.') ? name.split('.').last : 'jpg';
            await repo.uploadInitialJobPhoto(
              jobId: jobId,
              bytes: bytes,
              extension: extension,
            );
          } catch (_) {
            failedPhotos += 1;
          }
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failedPhotos == 0
                ? 'Solicitud creada correctamente.'
                : 'Solicitud creada. $failedPhotos foto(s) no pudieron subirse.',
          ),
          backgroundColor: failedPhotos == 0 ? Colors.green : Colors.orange,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Nuevo servicio',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Form(
        key: _formKey,
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
                boxShadow: AppTheme.softShadow,
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FixisStatusPill(
                          label: 'SOLICITUD FIXIS',
                          color: AppTheme.primaryOrange,
                          icon: Icons.add_home_work_rounded,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Cuéntanos qué necesitas',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Un FIXI cercano podrá revisar tu solicitud y enviarte una cotización.',
                          style: TextStyle(
                            color: Colors.white70,
                            height: 1.4,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  Icon(
                    Icons.handyman_rounded,
                    color: AppTheme.primaryOrange,
                    size: 38,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const FixisSectionHeader(
              title: 'Servicio',
              subtitle: 'Describe brevemente el trabajo',
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Ej. Fuga de agua en cocina',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty
                      ? 'Ingresa un título'
                      : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: categories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText:
                    'Describe el problema con el mayor detalle posible.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 22),
            const FixisSectionHeader(
              title: 'Ubicación',
              subtitle: 'La usamos para encontrar FIXIS cercanos',
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty
                      ? 'Ingresa la dirección'
                      : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressReference,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Referencia (opcional)',
                hintText: 'Ej. casa con reja negra, pasaje sin letrero, frente al almacén',
                prefixIcon: Icon(Icons.signpost_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            FixisSurface(
              padding: const EdgeInsets.all(14),
              shadows: const [],
              color: _servicePosition == null
                  ? AppTheme.warningSoft
                  : AppTheme.successSoft,
              border: Border.all(
                color: (_servicePosition == null
                        ? AppTheme.warning
                        : AppTheme.success)
                    .withValues(alpha: 0.18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: (_servicePosition == null
                              ? AppTheme.warning
                              : AppTheme.success)
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      _servicePosition == null
                          ? Icons.location_searching_rounded
                          : Icons.location_on_rounded,
                      color: _servicePosition == null
                          ? AppTheme.warning
                          : AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      _servicePosition == null
                          ? 'Confirma dónde se realizará el servicio.'
                          : 'Ubicación confirmada para el matching cercano.',
                      style: const TextStyle(
                        color: AppTheme.darkSlate,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed:
                        _loadingLocation ? null : _useCurrentLocation,
                    child: _loadingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _servicePosition == null
                                ? 'Usar GPS'
                                : 'Actualizar',
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const FixisSectionHeader(
              title: 'Visita y fotos',
              subtitle: 'Información opcional que ayuda al FIXI a prepararse',
            ),
            const SizedBox(height: 10),
            FixisSurface(
              padding: const EdgeInsets.all(14),
              shadows: const [],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event_outlined, color: AppTheme.primaryBlue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _requestedVisitAt == null
                              ? 'Indica cuándo te gustaría recibir la visita.'
                              : 'Preferencia: ${DateFormat('dd/MM/yyyy · HH:mm').format(_requestedVisitAt!)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed: _selectRequestedVisit,
                        child: Text(_requestedVisitAt == null ? 'Elegir' : 'Cambiar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Es una preferencia; el horario queda confirmado solo cuando ambas partes lo acuerdan.',
                    style: TextStyle(color: AppTheme.slate500, fontSize: 11.5, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FixisSurface(
              padding: const EdgeInsets.all(14),
              shadows: const [],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fotos del problema (opcional, máximo 3)',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ayudan al FIXI a entender el problema. No reemplazan la inspección presencial ni garantizan un diagnóstico definitivo.',
                    style: TextStyle(color: AppTheme.slate500, fontSize: 11.5, height: 1.35),
                  ),
                  if (_issuePhotos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 84,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _issuePhotos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(_issuePhotos[index].path),
                                  width: 84,
                                  height: 84,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 3,
                                top: 3,
                                child: InkWell(
                                  onTap: () => setState(() => _issuePhotos.removeAt(index)),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 15),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _issuePhotos.length >= 3
                            ? null
                            : () => _pickIssuePhoto(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Cámara'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _issuePhotos.length >= 3
                            ? null
                            : () => _pickIssuePhoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galería'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('Publicar solicitud'),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Podrás revisar y aceptar la cotización antes de iniciar el servicio.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.slate500,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
