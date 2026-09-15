// FIXIS PRO v1.4.2 - Corrige mensaje duplicado en estado work_completed.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/theme.dart';
import '../providers/jobs_repository.dart';
import 'create_quote_screen.dart';
import 'quote_summary_screen.dart';
import 'revision_quote_screen.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> job;

  const JobDetailScreen({
    super.key,
    required this.job,
  });

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  late Map<String, dynamic> _job;
  Map<String, dynamic>? _quote;
  Map<String, dynamic>? _financialSnapshot;
  bool _isLoadingQuote = true;
  bool _isStartingJob = false;
  bool _isRouteActionLoading = false;
  StreamSubscription<Position>? _liveLocationSubscription;
  DateTime? _lastLiveSyncAt;
  Position? _lastLivePosition;

  File? _imageBefore;
  File? _imageAfter;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _isPickingImage = false;
  String _uploadStatus = '';

  @override
  void initState() {
    super.initState();
    _job = Map<String, dynamic>.from(widget.job);
    _refreshData().then((_) {
      if (mounted && _status == 'en_route') {
        _startLiveTracking();
      }
    });
  }

  @override
  void dispose() {
    _liveLocationSubscription?.cancel();
    super.dispose();
  }

  String get _status => _job['status']?.toString() ?? 'pending';

  Future<void> _refreshData() async {
    final jobId = _job['id']?.toString();
    if (jobId == null || jobId.isEmpty) {
      if (mounted) setState(() => _isLoadingQuote = false);
      return;
    }

    if (mounted) setState(() => _isLoadingQuote = true);

    try {
      final repo = ref.read(jobsRepositoryProvider);
      final freshJob = await repo.getJobById(jobId);
      final quote = await repo.getQuoteForJob(jobId);
      final snapshot = await repo.getFinancialSnapshotForJob(jobId);

      if (!mounted) return;
      setState(() {
        if (freshJob != null) _job = freshJob;
        _quote = quote;
        _financialSnapshot = snapshot;
        _isLoadingQuote = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingQuote = false);
    }
  }

  Future<void> _loadQuote() => _refreshData();

  Future<void> _openQuoteEditor() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => CreateQuoteScreen(
          job: _job,
          initialQuote: _quote,
        ),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      final quoteData = result['quote'];
      final submitted = result['submitted'] == true;

      if (quoteData is Map) {
        setState(() {
          _quote = Map<String, dynamic>.from(quoteData);
          if (submitted) _job['status'] = 'quote_submitted';
        });
      }

      if (submitted && _quote != null) {
        await _openQuoteSummary();
        return;
      }
    }

    await _loadQuote();
  }

  Future<void> _openQuoteSummary() async {
    if (_quote == null) {
      await _loadQuote();
    }
    if (!mounted || _quote == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuoteSummaryScreen(
          job: _job,
          quote: _quote!,
        ),
      ),
    );
  }

  Future<void> _openRevisionQuote() async {
    final jobId = _job['id']?.toString();
    if (jobId == null || jobId.isEmpty) return;

    final repo = ref.read(jobsRepositoryProvider);
    final freshJob = await repo.getJobById(jobId);
    if (!mounted) return;
    if (freshJob == null || freshJob['status']?.toString() != 'arrived') {
      _showError('El servicio debe estar en estado Llegó para revisar la cotización.');
      await _refreshData();
      return;
    }

    final acceptedQuoteId = freshJob['accepted_quote_id']?.toString();
    final quotes = await repo.getQuotesForJob(jobId);
    if (!mounted) return;

    Map<String, dynamic>? currentQuote;
    for (final quote in quotes) {
      if (quote['id']?.toString() == acceptedQuoteId) {
        currentQuote = quote;
        break;
      }
    }

    if (currentQuote == null) {
      _showError('No encontramos la cotización vigente.');
      return;
    }

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => RevisionQuoteScreen(
          job: freshJob,
          currentQuote: currentQuote!,
        ),
      ),
    );

    if (!mounted) return;
    if (result?['submitted'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisión enviada. Espera la respuesta del cliente.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    await _refreshData();
  }

  Future<void> _cancelPendingRevision() async {
    final quoteId = _job['pending_quote_revision_id']?.toString();
    if (quoteId == null || quoteId.isEmpty || _isStartingJob) return;

    setState(() => _isStartingJob = true);
    try {
      final updatedJob =
          await ref.read(jobsRepositoryProvider).cancelQuoteRevision(quoteId);
      if (!mounted) return;
      setState(() {
        _job = updatedJob;
        _isStartingJob = false;
      });
      await _refreshData();
    } on JobActionException catch (e) {
      if (!mounted) return;
      setState(() => _isStartingJob = false);
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isStartingJob = false);
      _showError('No fue posible retirar la revisión.');
    }
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _showError('Activa los servicios de ubicación para continuar.');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      _showError('Permiso de ubicación denegado.');
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      _showError('El permiso de ubicación está bloqueado. Actívalo en Ajustes.');
      return false;
    }

    return true;
  }

  Future<void> _beginRoute() async {
    final jobId = _job['id']?.toString();
    if (jobId == null || jobId.isEmpty || _isRouteActionLoading) return;

    if (!await _ensureLocationPermission()) return;

    setState(() => _isRouteActionLoading = true);

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final updatedJob = await ref.read(jobsRepositoryProvider).startRoute(
            jobId: jobId,
            latitude: position.latitude,
            longitude: position.longitude,
            heading: position.heading >= 0 ? position.heading : null,
            speed: position.speed >= 0 ? position.speed : null,
            accuracy: position.accuracy,
          );

      if (!mounted) return;
      setState(() {
        _job = updatedJob;
        _isRouteActionLoading = false;
        _lastLivePosition = position;
      });

      await _startLiveTracking();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ubicación compartida. El cliente ya puede seguir tu llegada.'),
          backgroundColor: Colors.green,
        ),
      );
    } on JobActionException catch (e) {
      if (!mounted) return;
      setState(() => _isRouteActionLoading = false);
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRouteActionLoading = false);
      _showError('No fue posible iniciar el trayecto.');
    }
  }

  Future<void> _startLiveTracking() async {
    if (_liveLocationSubscription != null) return;
    if (!await _ensureLocationPermission()) return;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
    );

    _liveLocationSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((position) async {
      if (!mounted || _status != 'en_route') return;

      final now = DateTime.now();
      if (_lastLiveSyncAt != null &&
          now.difference(_lastLiveSyncAt!) < const Duration(seconds: 5)) {
        return;
      }

      _lastLiveSyncAt = now;
      _lastLivePosition = position;

      try {
        await ref.read(jobsRepositoryProvider).updateLiveLocation(
              jobId: _job['id'].toString(),
              latitude: position.latitude,
              longitude: position.longitude,
              heading: position.heading >= 0 ? position.heading : null,
              speed: position.speed >= 0 ? position.speed : null,
              accuracy: position.accuracy,
            );
        if (mounted) setState(() {});
      } catch (_) {
        // El siguiente movimiento reintentará. No interrumpimos la navegación.
      }
    });
  }

  Future<void> _markArrived() async {
    final jobId = _job['id']?.toString();
    if (jobId == null || jobId.isEmpty || _isRouteActionLoading) return;

    if (!await _ensureLocationPermission()) return;
    setState(() => _isRouteActionLoading = true);

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final repo = ref.read(jobsRepositoryProvider);
      await repo.updateLiveLocation(
        jobId: jobId,
        latitude: position.latitude,
        longitude: position.longitude,
        heading: position.heading >= 0 ? position.heading : null,
        speed: position.speed >= 0 ? position.speed : null,
        accuracy: position.accuracy,
      );
      final updatedJob = await repo.markArrived(jobId);
      await _liveLocationSubscription?.cancel();
      _liveLocationSubscription = null;

      if (!mounted) return;
      setState(() {
        _job = updatedJob;
        _isRouteActionLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Llegada registrada. El tracking en vivo se detuvo.'),
          backgroundColor: Colors.green,
        ),
      );
    } on JobActionException catch (e) {
      if (!mounted) return;
      setState(() => _isRouteActionLoading = false);
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRouteActionLoading = false);
      _showError('No fue posible registrar la llegada.');
    }
  }

  Future<void> _startAuthorizedJob() async {
    final jobId = _job['id']?.toString();
    if (jobId == null || jobId.isEmpty || _isStartingJob) return;

    setState(() => _isStartingJob = true);

    try {
      final updatedJob = await ref.read(jobsRepositoryProvider).startJob(jobId);
      if (!mounted) return;
      setState(() {
        _job = updatedJob;
        _isStartingJob = false;
      });
      await _liveLocationSubscription?.cancel();
      _liveLocationSubscription = null;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Servicio iniciado correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } on JobActionException catch (e) {
      if (!mounted) return;
      setState(() => _isStartingJob = false);
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isStartingJob = false);
      _showError('No fue posible iniciar el servicio.');
    }
  }

  Future<void> _takePicture(bool isBefore) async {
    if (_isPickingImage || _isUploading) return;

    setState(() => _isPickingImage = true);

    try {
      debugPrint(
        '[EVIDENCE] opening camera '
        'job=${_job['id']} type=${isBefore ? 'antes' : 'despues'}',
      );

      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 55,
        maxWidth: 1280,
        maxHeight: 1280,
        requestFullMetadata: false,
      );

      if (photo == null || !mounted) return;

      final file = File(photo.path);
      final size = await file.length();

      debugPrint(
        '[EVIDENCE] captured '
        'type=${isBefore ? 'antes' : 'despues'} '
        'bytes=$size path=${photo.path}',
      );

      if (!mounted) return;

      final previousFile = isBefore ? _imageBefore : _imageAfter;
      if (previousFile != null && previousFile.path != file.path) {
        await FileImage(previousFile).evict();
      }

      if (!mounted) return;
      setState(() {
        if (isBefore) {
          _imageBefore = file;
        } else {
          _imageAfter = file;
        }
      });
    } catch (e, st) {
      debugPrint('[EVIDENCE] camera error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al abrir la cámara: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  Future<void> _finishJob() async {
    if (_imageBefore == null || _imageAfter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes tomar ambas fotos antes de completar el trabajo.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatus = 'Subiendo evidencia inicial...';
    });

    try {
      final repo = ref.read(jobsRepositoryProvider);
      final jobId = _job['id'].toString();

      debugPrint('[EVIDENCE] upload start job=$jobId type=antes');
      await repo.uploadEvidence(_imageBefore!, jobId, 'antes');
      debugPrint('[EVIDENCE] upload complete job=$jobId type=antes');

      if (!mounted) return;
      setState(() => _uploadStatus = 'Subiendo evidencia final...');

      debugPrint('[EVIDENCE] upload start job=$jobId type=despues');
      await repo.uploadEvidence(_imageAfter!, jobId, 'despues');
      debugPrint('[EVIDENCE] upload complete job=$jobId type=despues');

      debugPrint('[EVIDENCE] finish_job start job=$jobId');
      final updatedJob = await repo.finishJob(jobId);
      debugPrint(
        '[EVIDENCE] finish_job complete '
        'job=$jobId status=${updatedJob['status']}',
      );

      if (!mounted) return;

      final beforeProvider = FileImage(_imageBefore!);
      final afterProvider = FileImage(_imageAfter!);
      await beforeProvider.evict();
      await afterProvider.evict();

      if (!mounted) return;
      setState(() {
        _job = updatedJob;
        _imageBefore = null;
        _imageAfter = null;
        _isUploading = false;
        _uploadStatus = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trabajo finalizado. Esperando confirmación del cliente.'),
          backgroundColor: Colors.green,
        ),
      );
    } on JobActionException catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadStatus = '';
      });
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadStatus = '';
      });
      _showError('No fue posible completar el trabajo.');
    }
  }

  void _openNavigationMenu() {
    final lat = (_job['latitude'] as num?)?.toDouble();
    final lng = (_job['longitude'] as num?)?.toDouble();

    if (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este servicio no tiene una ubicación válida para navegación.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '¿Cómo deseas llegar al cliente?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkSlate,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(
                    Icons.directions_car,
                    color: Colors.lightBlue,
                    size: 30,
                  ),
                  title: const Text(
                    'Navegar con Waze',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _launchUrl(
                      'waze://?ll=$lat,$lng&navigate=yes',
                      'https://waze.com/ul?ll=$lat,$lng&navigate=yes',
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.pin_drop, color: Colors.red, size: 30),
                  title: const Text(
                    'Navegar con Google Maps',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _launchUrl(
                      'comgooglemaps://?daddr=$lat,$lng&directionsmode=driving',
                      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.map, color: Colors.blue, size: 30),
                  title: const Text(
                    'Apple Maps (iOS)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _launchUrl(
                      'maps://?daddr=$lat,$lng',
                      'https://maps.apple.com/?daddr=$lat,$lng',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchUrl(String appUrl, String webUrl) async {
    final appUri = Uri.parse(appUrl);
    final webUri = Uri.parse(webUrl);

    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatVisitDate(dynamic raw) {
    final dt = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (dt == null) return '-';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} · ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final id = _job['id']?.toString() ?? '';
    final shortId = id.length > 8 ? id.substring(0, 8) : id;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Trabajo #$shortId',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.darkSlate,
        elevation: 1,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildJobHeader(),
            const SizedBox(height: 20),
            _buildStatusCard(),
            const SizedBox(height: 20),
            if (_status == 'accepted') _buildAcceptedActions(),
            if (_status == 'quote_submitted') _buildQuoteSubmittedActions(),
            if (_status == 'authorized') _buildAuthorizedPlaceholder(),
            if (_status == 'en_route') _buildEnRouteState(),
            if (_status == 'arrived') _buildArrivedState(),
            if (_status == 'quote_revision_pending') _buildRevisionPendingState(),
            if (_status == 'in_progress') _buildEvidenceFlow(),
            if (_status == 'customer_approved') _buildCustomerApprovedState(),
            if (_status == 'completed') _buildCompletedState(),
          ],
        ),
      ),
    );
  }

  Widget _buildJobHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _job['category']?.toString() ?? 'Servicio',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _status.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.primaryBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _job['title']?.toString() ?? 'Sin título',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkSlate,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cliente: ${_job['client_name'] ?? 'Cliente'}',
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            'Dirección: ${_job['address'] ?? 'Dirección no especificada'}',
            style: const TextStyle(color: Colors.grey),
          ),
          if ((_job['address_reference']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              'Referencia: ${_job['address_reference']}',
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ],
          if ((_job['requested_visit_at']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              'Preferencia de visita: ${_formatVisitDate(_job['requested_visit_at'])}',
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          _buildInitialProblemPhotos(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openNavigationMenu,
              icon: const Icon(Icons.navigation_rounded),
              label: const Text('Iniciar navegación'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryBlue,
                side: BorderSide(color: Colors.blue.shade200),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRemotePhotoViewer({
    required String url,
    required int index,
    required int total,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (dialogContext) {
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white70,
                                size: 48,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No fue posible abrir la fotografía.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
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
                Positioned(
                  top: 15,
                  right: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${index + 1} / $total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInitialProblemPhotos() {
    final jobId = _job['id']?.toString();
    if (jobId == null || jobId.isEmpty) return const SizedBox.shrink();

    final repo = ref.read(jobsRepositoryProvider);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repo.getJobAttachments(jobId),
      builder: (context, snapshot) {
        final attachments = (snapshot.data ?? const <Map<String, dynamic>>[])
            .where((item) => item['attachment_type']?.toString() == 'issue_initial')
            .toList(growable: false);
        if (attachments.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fotos enviadas por el cliente',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: attachments.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final path = attachments[index]['storage_path']?.toString() ?? '';
                  return FutureBuilder<String>(
                    future: repo.createJobAttachmentSignedUrl(path),
                    builder: (context, urlSnapshot) {
                      final url = urlSnapshot.data;
                      if (url == null) {
                        return Container(
                          width: 88,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      return Semantics(
                        button: true,
                        label: 'Abrir foto ${index + 1} de ${attachments.length}',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openRemotePhotoViewer(
                            url: url,
                            index: index,
                            total: attachments.length,
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  url,
                                  width: 88,
                                  height: 88,
                                  fit: BoxFit.cover,
                                  cacheWidth: 264,
                                  cacheHeight: 264,
                                  filterQuality: FilterQuality.low,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 88,
                                    height: 88,
                                    color: Colors.grey.shade100,
                                    child: const Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 5,
                                bottom: 5,
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.zoom_out_map_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusCard() {
    final (icon, title, message, color) = switch (_status) {
      'accepted' => (
          Icons.assignment_turned_in_outlined,
          'Oportunidad aceptada',
          'Revisa el servicio y prepara tu cotización antes de iniciar el trabajo.',
          AppTheme.primaryOrange,
        ),
      'quote_submitted' => (
          Icons.schedule_rounded,
          'Cotización enviada',
          'Estamos esperando la decisión del cliente. No inicies el trabajo todavía.',
          AppTheme.primaryBlue,
        ),
      'authorized' => (
          Icons.verified_rounded,
          'Servicio autorizado',
          'La cotización fue aprobada. Cuando salgas, inicia el trayecto para compartir tu llegada con el cliente.',
          Colors.green,
        ),
      'en_route' => (
          Icons.navigation_rounded,
          'En camino',
          'FIXIS Live está compartiendo tu ubicación únicamente durante este trayecto.',
          AppTheme.primaryBlue,
        ),
      'quote_revision_pending' => (
        Icons.price_change_rounded,
        'Revisión pendiente',
        'El cliente debe aceptar o rechazar la nueva cotización antes de iniciar.',
        Colors.orange,
      ),
      'arrived' => (
          Icons.location_on_rounded,
          'Llegaste al servicio',
          'La llegada fue registrada y el tracking en vivo ya está detenido.',
          Colors.green,
        ),
      'in_progress' => (
          Icons.build_circle_outlined,
          'Trabajo en ejecución',
          'Toma la evidencia de antes y después. Al finalizar, el cliente deberá confirmar el servicio.',
          Colors.green,
        ),
      'work_completed' => (
          Icons.hourglass_top_rounded,
          'Esperando confirmación del cliente',
          'El trabajo fue marcado como terminado. El saldo se generará cuando el cliente confirme el servicio.',
          AppTheme.primaryOrange,
        ),
      'customer_approved' => (
          Icons.verified_rounded,
          'Trabajo confirmado',
          'El cliente confirmó el servicio. El movimiento financiero ya puede reflejarse en tu ledger.',
          Colors.green,
        ),
      'completed' => (
          Icons.task_alt_rounded,
          'Trabajo completado',
          'Este servicio ya fue finalizado.',
          Colors.green,
        ),
      _ => (
          Icons.info_outline,
          'Estado del servicio',
          'Estado actual: $_status',
          Colors.grey,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkSlate,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(color: Colors.grey, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptedActions() {
    if (_isLoadingQuote) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasDraft = _quote?['status'] == 'draft';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _openQuoteEditor,
          icon: Icon(hasDraft ? Icons.edit_note_rounded : Icons.request_quote_outlined),
          label: Text(hasDraft ? 'Continuar cotización' : 'Preparar cotización'),
        ),
        if (hasDraft) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openQuoteSummary,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Ver borrador'),
          ),
        ],
      ],
    );
  }

  Widget _buildQuoteSubmittedActions() {
    if (_isLoadingQuote) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _quote == null ? _loadQuote : _openQuoteSummary,
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Ver cotización enviada'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
        ),
        const SizedBox(height: 12),
        const Text(
          'La cotización ya no puede editarse. Desliza hacia abajo para actualizar cuando el cliente la apruebe.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildAuthorizedPlaceholder() {
    if (_isLoadingQuote) {
      return const Center(child: CircularProgressIndicator());
    }

    final snapshot = _financialSnapshot;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.green.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_rounded, color: Colors.green, size: 30),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cotización aprobada',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkSlate,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (snapshot == null)
                const Text(
                  'La aprobación está registrada, pero todavía no se pudo cargar el resumen financiero. Actualiza la pantalla antes de iniciar.',
                  style: TextStyle(color: Colors.grey, height: 1.4),
                )
              else ...[
                _financialRow('Servicio', _snapshotAmount('gross_amount')),
                const SizedBox(height: 10),
                _financialRow(
                  'Comisión FIXIS (${_snapshotAmount('commission_rate_percent').toStringAsFixed(0)}%)',
                  _snapshotAmount('commission_amount'),
                ),
                const Divider(height: 28),
                _financialRow(
                  'Tu ingreso',
                  _snapshotAmount('professional_amount'),
                  emphasized: true,
                ),
                const SizedBox(height: 8),
                Text(
                  'Base comisionable: ${snapshot['commission_basis'] == 'labor' ? 'mano de obra' : 'total del servicio'}.',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: snapshot == null || _isRouteActionLoading ? null : _beginRoute,
          icon: _isRouteActionLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.navigation_rounded),
          label: Text(_isRouteActionLoading ? 'Preparando ruta...' : 'Ir al cliente'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildEnRouteState() {
    final position = _lastLivePosition;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.my_location_rounded, color: AppTheme.primaryBlue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'FIXIS Live activo',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Compartimos tu posición únicamente durante el trayecto hacia este cliente.',
                style: TextStyle(color: Colors.black54, height: 1.4),
              ),
              if (position != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Precisión aproximada: ${position.accuracy.toStringAsFixed(0)} m',
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _openNavigationMenu,
          icon: const Icon(Icons.directions_rounded),
          label: const Text('Abrir navegación'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _isRouteActionLoading ? null : _markArrived,
          icon: _isRouteActionLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.location_on_rounded),
          label: Text(_isRouteActionLoading ? 'Registrando...' : 'Llegué'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildArrivedState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.green.withValues(alpha: 0.22)),
          ),
          child: const Row(
            children: [
              Icon(Icons.location_on_rounded, color: Colors.green, size: 30),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Llegada registrada. El tracking está detenido y ya puedes iniciar el servicio.',
                  style: TextStyle(height: 1.4, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _isStartingJob ? null : _openRevisionQuote,
          icon: const Icon(Icons.price_change_rounded),
          label: const Text('Solicitar cambio de alcance'),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _isStartingJob ? null : _startAuthorizedJob,
          icon: _isStartingJob
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.play_circle_fill_rounded),
          label: Text(_isStartingJob ? 'Iniciando...' : 'Iniciar servicio'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildRevisionPendingState() {
    final revisionNumber = _quote?['revision_number'];
    final revisionReason = _quote?['revision_reason']?.toString() ?? '';
    final total = (_quote?['total_amount'] as num?)?.toDouble() ??
        double.tryParse(_quote?['total_amount']?.toString() ?? '') ??
        0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.orange.withValues(alpha: .22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, color: Colors.orange),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Esperando decisión del cliente',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Revisión ${revisionNumber ?? ''} · \$${total.toStringAsFixed(2)}'),
              if (revisionReason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(revisionReason),
              ],
              const SizedBox(height: 8),
              const Text(
                'No puedes iniciar el trabajo hasta que el cliente acepte o rechace la revisión.',
                style: TextStyle(height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _isStartingJob ? null : _cancelPendingRevision,
          icon: const Icon(Icons.undo_rounded),
          label: const Text('Retirar revisión'),
        ),
      ],
    );
  }

  double _snapshotAmount(String key) {
    final value = _financialSnapshot?[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _financialRow(
    String label,
    double amount, {
    bool emphasized = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.darkSlate,
              fontWeight: emphasized ? FontWeight.bold : FontWeight.w500,
              fontSize: emphasized ? 16 : 14,
            ),
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: emphasized ? Colors.green.shade700 : AppTheme.darkSlate,
            fontWeight: FontWeight.bold,
            fontSize: emphasized ? 21 : 15,
          ),
        ),
      ],
    );
  }

  Widget _buildEvidenceFlow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Evidencia fotográfica obligatoria',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkSlate,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Estas evidencias respaldan la ejecución del servicio y se suben antes de solicitar la confirmación del cliente.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildPhotoCard(
                'ANTES',
                _imageBefore,
                (_isPickingImage || _isUploading)
                    ? () {}
                    : () => _takePicture(true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPhotoCard(
                'DESPUÉS',
                _imageAfter,
                (_isPickingImage || _isUploading)
                    ? () {}
                    : () => _takePicture(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        if (_isUploading)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _uploadStatus,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ElevatedButton.icon(
          onPressed: _isUploading ? null : _finishJob,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: Text(
            _isUploading ? 'Procesando...' : 'Completar trabajo',
          ),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
      ],
    );
  }

  Widget _buildCustomerApprovedState() {
    final snapshot = _financialSnapshot;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_rounded, color: Colors.green),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Servicio confirmado',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkSlate,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (snapshot != null) ...[
            _financialRow('Servicio', _snapshotAmount('gross_amount')),
            const SizedBox(height: 8),
            _financialRow('Comisión FIXIS', _snapshotAmount('commission_amount')),
            const Divider(height: 24),
            _financialRow(
              'Tu ingreso',
              _snapshotAmount('professional_amount'),
              emphasized: true,
            ),
          ] else
            const Text(
              'El servicio fue confirmado. Actualiza la pantalla para cargar el resumen financiero.',
              style: TextStyle(color: Colors.grey, height: 1.4),
            ),
        ],
      ),
    );
  }

  Widget _buildCompletedState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 32),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'El servicio está cerrado. No se generarán ganancias ficticias en esta versión.',
              style: TextStyle(color: AppTheme.darkSlate, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(String title, File? imageFile, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: imageFile != null ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: imageFile != null ? Colors.transparent : Colors.grey.shade300,
            width: 2,
          ),
          image: imageFile != null
              ? DecorationImage(
                  image: ResizeImage(
                    FileImage(imageFile),
                    width: 420,
                  ),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: imageFile == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt, color: Colors.grey, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
