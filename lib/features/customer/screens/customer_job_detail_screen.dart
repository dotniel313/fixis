import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/route_service.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/fixis_ui.dart';
import '../providers/customer_repository.dart';
import 'customer_payment_screen.dart';

class CustomerJobDetailScreen extends ConsumerStatefulWidget {
  final String jobId;
  const CustomerJobDetailScreen({super.key, required this.jobId});

  @override
  ConsumerState<CustomerJobDetailScreen> createState() => _CustomerJobDetailScreenState();
}

class _CustomerJobDetailScreenState extends ConsumerState<CustomerJobDetailScreen> {
  bool _loadingAction = false;

  final RouteService _routeService = OsrmRouteService();
  RouteResult? _route;
  LatLng? _routeOrigin;
  LatLng? _routeDestination;
  DateTime? _routeRequestedAt;
  bool _routeLoading = false;
  String? _routeError;

  Future<void> _refresh() async => setState(() {});

  Future<void> _acceptQuote(String quoteId) async {
    setState(() => _loadingAction = true);
    try {
      await ref.read(customerRepositoryProvider).acceptQuote(quoteId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cotización aprobada.'), backgroundColor: Colors.green),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  Future<void> _acceptRevision(String quoteId) async {
    setState(() => _loadingAction = true);
    try {
      await ref.read(customerRepositoryProvider).acceptQuoteRevision(quoteId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cotización revisada aprobada.'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  Future<void> _rejectRevision(String quoteId) async {
    setState(() => _loadingAction = true);
    try {
      await ref.read(customerRepositoryProvider).rejectQuoteRevision(quoteId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisión rechazada. La cotización anterior sigue vigente.'),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  Future<void> _openPayment() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerPaymentScreen(jobId: widget.jobId),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(customerRepositoryProvider);
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Detalle del servicio',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: FixisStatusPill(
                label: 'FIXIS',
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
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: StreamBuilder<Map<String, dynamic>>(
            stream: repo.watchJob(widget.jobId),
            builder: (context, jobSnapshot) {
              if (jobSnapshot.connectionState == ConnectionState.waiting) {
                return ListView(children: const [SizedBox(height: 240), Center(child: CircularProgressIndicator())]);
              }
              if (jobSnapshot.hasError || jobSnapshot.data == null || jobSnapshot.data!.isEmpty) {
                return ListView(children: const [SizedBox(height: 160), Center(child: Text('No pudimos cargar el servicio.'))]);
              }
  
              final job = jobSnapshot.data!;
              final status = job['status']?.toString() ?? 'pending';
  
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(job['title']?.toString() ?? 'Servicio', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(job['category']?.toString() ?? '', style: const TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  _card('Estado', _statusLabel(status), Icons.timeline),
                  const SizedBox(height: 12),
                  _card('Dirección', job['address']?.toString() ?? '-', Icons.location_on_outlined),
                  if ((job['address_reference']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _card('Referencia', job['address_reference'].toString(), Icons.signpost_outlined),
                  ],
                  if ((job['requested_visit_at']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _card('Preferencia de visita', _formatVisitDate(job['requested_visit_at']), Icons.event_outlined),
                  ],
                  if ((job['description']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _card('Descripción', job['description'].toString(), Icons.description_outlined),
                  ],
                  const SizedBox(height: 24),
                  if (status == 'quote_submitted') ...[
                    const Text('Cotizaciones', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: repo.getQuotesForJob(widget.jobId),
                      builder: (context, quotesSnapshot) {
                        if (quotesSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final quotes = quotesSnapshot.data ?? const [];
                        if (quotes.isEmpty) return const Text('Todavía no hay cotizaciones visibles.');
                        return Column(
                          children: quotes.map((q) => _quoteCard(q)).toList(),
                        );
                      },
                    ),
                  ],
                  if (status == 'authorized')
                    _actionInfo('Cotización aprobada', 'El FIXI preparará su trayecto hacia tu ubicación.', Icons.check_circle, Colors.green),
                  if (status == 'en_route') ...[
                    _actionInfo('Tu FIXI está en camino', 'Su ubicación se está actualizando en tiempo real.', Icons.navigation_rounded, AppTheme.primaryBlue),
                    const SizedBox(height: 12),
                    _liveMapCard(repo, job),
                  ],
                  if (status == 'arrived') ...[
                    _actionInfo('Tu FIXI llegó', 'El profesional registró su llegada al lugar del servicio.', Icons.location_on_rounded, Colors.green),
                    const SizedBox(height: 12),
                    _liveMapCard(repo, job, arrived: true),
                  ],
                  if (status == 'quote_revision_pending') ...[
                    _actionInfo(
                      'Cambio de alcance solicitado',
                      'El FIXI encontró condiciones distintas en el lugar. Revisa la propuesta antes de que empiece el trabajo.',
                      Icons.price_change_rounded,
                      Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: repo.getQuotesForJob(widget.jobId),
                      builder: (context, quotesSnapshot) {
                        if (quotesSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final quotes = quotesSnapshot.data ?? const [];
                        return _revisionDecisionCard(job, quotes);
                      },
                    ),
                  ],
                  if (status == 'in_progress')
                    _actionInfo('Servicio en curso', 'El FIXI está realizando el trabajo.', Icons.handyman, AppTheme.primaryBlue),
                  if (status == 'work_completed') ...[
                    _actionInfo(
                      'Trabajo finalizado por el FIXI',
                      'Revisa el servicio. Si estás conforme, continúa al pago.',
                      Icons.task_alt,
                      Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<Map<String, dynamic>?>(
                      future: repo.getPaymentForJob(widget.jobId),
                      builder: (context, paymentSnapshot) {
                        final payment = paymentSnapshot.data;
                        final paymentStatus =
                            payment?['status']?.toString();
  
                        final label = switch (paymentStatus) {
                          'pending_verification' =>
                            'Pago en verificación',
                          'voucher_uploaded' =>
                            'Pago en verificación',
                          'rejected' =>
                            'Revisar pago rechazado',
                          'paid' =>
                            'Pago confirmado',
                          _ =>
                            'Aprobar y pagar',
                        };
  
                        final icon = paymentStatus == 'paid'
                            ? Icons.verified_rounded
                            : Icons.payments_outlined;
  
                        return SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _loadingAction
                                ? null
                                : _openPayment,
                            icon: Icon(icon),
                            label: Text(label),
                          ),
                        );
                      },
                    ),
                  ],
                  if (status == 'customer_approved')
                    _actionInfo('Servicio confirmado', 'FIXIS confirmó el pago y el servicio quedó cerrado financieramente.', Icons.verified, Colors.green),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatVisitDate(dynamic raw) {
    final dt = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (dt == null) return '-';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} · ${two(dt.hour)}:${two(dt.minute)}';
  }

  Widget _liveMapCard(
    CustomerRepository repo,
    Map<String, dynamic> job, {
    bool arrived = false,
  }) {
    final jobLat = (job['latitude'] as num?)?.toDouble();
    final jobLng = (job['longitude'] as num?)?.toDouble();

    return StreamBuilder<Map<String, dynamic>?>(
      stream: repo.watchLiveLocation(widget.jobId),
      builder: (context, snapshot) {
        final location = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting && location == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (location == null) {
          return _card(
            'FIXIS Live',
            arrived
                ? 'La llegada fue registrada.'
                : 'Esperando la primera actualización de ubicación.',
            Icons.my_location_rounded,
          );
        }

        final proLat = (location['latitude'] as num?)?.toDouble();
        final proLng = (location['longitude'] as num?)?.toDouble();
        final accuracy = (location['accuracy'] as num?)?.toDouble();
        final updatedAt = DateTime.tryParse(location['updated_at']?.toString() ?? '');
        final active = location['sharing_active'] == true;

        if (proLat == null || proLng == null) {
          return _card(
            'FIXIS Live',
            'Recibimos una actualización, pero todavía no contiene una posición válida.',
            Icons.my_location_rounded,
          );
        }

        final professionalPoint = LatLng(proLat, proLng);
        final servicePoint = (jobLat != null && jobLng != null)
            ? LatLng(jobLat, jobLng)
            : null;

        final center = servicePoint == null
            ? professionalPoint
            : LatLng(
                (professionalPoint.latitude + servicePoint.latitude) / 2,
                (professionalPoint.longitude + servicePoint.longitude) / 2,
              );

        final distanceMeters = servicePoint == null
            ? null
            : const Distance().as(
                LengthUnit.Meter,
                professionalPoint,
                servicePoint,
              );

        final zoom = _zoomForDistance(
          _route?.distanceMeters ?? distanceMeters,
        );
        final categoryIcon = _categoryIcon(job['category']?.toString());

        if (!arrived && servicePoint != null) {
          _scheduleRouteRefresh(professionalPoint, servicePoint);
        }

        return FixisSurface(
          padding: EdgeInsets.zero,
          radius: AppTheme.radiusLg,
          border: Border.all(
            color: AppTheme.primaryBlue.withValues(alpha: .14),
          ),
          shadows: AppTheme.softShadow,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 290,
                child: FlutterMap(
                  key: ValueKey(
                    'fixis-live-${professionalPoint.latitude.toStringAsFixed(5)}-${professionalPoint.longitude.toStringAsFixed(5)}',
                  ),
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: zoom,
                    minZoom: 4,
                    maxZoom: 18,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'fixis_pro',
                    ),
                    if (!arrived && _route != null && _route!.points.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _route!.points,
                            strokeWidth: 6,
                            color: AppTheme.primaryBlue.withValues(alpha: .82),
                            borderStrokeWidth: 2,
                            borderColor: Colors.white.withValues(alpha: .88),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: professionalPoint,
                          width: 72,
                          height: 86,
                          child: _fixisPulseMarker(
                            icon: categoryIcon,
                            active: active && !arrived,
                          ),
                        ),
                        if (servicePoint != null)
                          Marker(
                            point: servicePoint,
                            width: 58,
                            height: 72,
                            child: _serviceDestinationMarker(),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active && !arrived ? Colors.green : Colors.black38,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            arrived || !active
                                ? 'Última ubicación registrada'
                                : 'Ubicación en vivo',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!arrived && _route != null)
                      _routeSummary(_route!)
                    else if (!arrived && _routeLoading)
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Calculando ruta y llegada estimada…',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      )
                    else if (!arrived && _routeError != null && distanceMeters != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _distanceLabel(distanceMeters),
                            style: const TextStyle(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'ETA temporalmente no disponible.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      )
                    else if (distanceMeters != null)
                      Text(
                        _distanceLabel(distanceMeters),
                        style: const TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (accuracy != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Precisión aproximada: ${accuracy.toStringAsFixed(0)} m',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                    if (updatedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Actualizado ${_formatLiveTime(updatedAt.toLocal())}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Text(
                      'Mapa © OpenStreetMap contributors',
                      style: TextStyle(fontSize: 11, color: Colors.black45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }


  void _scheduleRouteRefresh(LatLng origin, LatLng destination) {
    if (_routeLoading) return;

    final now = DateTime.now();
    final originMoved = _routeOrigin == null
        ? double.infinity
        : const Distance().as(LengthUnit.Meter, _routeOrigin!, origin);
    final destinationMoved = _routeDestination == null
        ? double.infinity
        : const Distance().as(
            LengthUnit.Meter,
            _routeDestination!,
            destination,
          );
    final ageSeconds = _routeRequestedAt == null
        ? double.infinity
        : now.difference(_routeRequestedAt!).inSeconds.toDouble();

    // Evita pedir una ruta en cada paquete GPS. Recalcula cuando el FIXI
    // se mueve al menos 80 m, cambia el destino o la ruta envejece 45 s.
    if (_route != null &&
        originMoved < 80 &&
        destinationMoved < 20 &&
        ageSeconds < 45) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _routeLoading) return;
      _refreshRoute(origin, destination);
    });
  }

  Future<void> _refreshRoute(LatLng origin, LatLng destination) async {
    if (_routeLoading) return;

    setState(() {
      _routeLoading = true;
      _routeError = null;
      _routeRequestedAt = DateTime.now();
    });

    try {
      final result = await _routeService.getDrivingRoute(
        origin: origin,
        destination: destination,
      );
      if (!mounted) return;
      setState(() {
        _route = result;
        _routeOrigin = origin;
        _routeDestination = destination;
        _routeError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _routeError = 'ROUTE_UNAVAILABLE';
        _routeOrigin = origin;
        _routeDestination = destination;
      });
    } finally {
      if (mounted) {
        setState(() => _routeLoading = false);
      }
    }
  }

  Widget _routeSummary(RouteResult route) {
    final eta = _etaLabel(route.duration);
    final distance = _routeDistanceLabel(route.distanceMeters);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.route_rounded, color: AppTheme.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$eta · $distance',
                  style: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Llegada estimada por ruta vial',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _etaLabel(Duration duration) {
    final minutes = (duration.inSeconds / 60).ceil();
    if (minutes <= 1) return '≈ 1 min';
    if (minutes < 60) return '≈ $minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return remaining == 0 ? '≈ $hours h' : '≈ $hours h $remaining min';
  }

  String _routeDistanceLabel(double distanceMeters) {
    if (distanceMeters < 1000) return '${distanceMeters.round()} m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  Widget _fixisPulseMarker({required IconData icon, required bool active}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: active ? AppTheme.primaryOrange : Colors.black38,
              width: 4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryOrange,
            size: 28,
          ),
        ),
        Container(
          width: 5,
          height: 12,
          decoration: BoxDecoration(
            color: AppTheme.primaryOrange,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }

  Widget _serviceDestinationMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryBlue,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.home_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        Container(
          width: 4,
          height: 10,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }

  IconData _categoryIcon(String? category) {
    final value = (category ?? '').toLowerCase();
    if (value.contains('electric')) return Icons.bolt_rounded;
    if (value.contains('plomer') || value.contains('gasfit')) {
      return Icons.water_drop_rounded;
    }
    if (value.contains('mecan')) return Icons.build_rounded;
    if (value.contains('clima') || value.contains('aire')) {
      return Icons.ac_unit_rounded;
    }
    if (value.contains('limpieza')) return Icons.auto_awesome_rounded;
    if (value.contains('cerraj')) return Icons.key_rounded;
    return Icons.handyman_rounded;
  }

  double _zoomForDistance(double? distanceMeters) {
    if (distanceMeters == null) return 15;
    if (distanceMeters <= 500) return 15.5;
    if (distanceMeters <= 1000) return 14.5;
    if (distanceMeters <= 2500) return 13.5;
    if (distanceMeters <= 5000) return 12.5;
    if (distanceMeters <= 10000) return 11.5;
    if (distanceMeters <= 25000) return 10.5;
    return 9.5;
  }

  String _distanceLabel(double distanceMeters) {
    if (distanceMeters < 1000) {
      return 'El FIXI está a ${distanceMeters.round()} m del servicio';
    }
    return 'El FIXI está a ${(distanceMeters / 1000).toStringAsFixed(1)} km del servicio';
  }

  String _formatLiveTime(DateTime value) {
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    final ss = value.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Widget _revisionDecisionCard(
    Map<String, dynamic> job,
    List<Map<String, dynamic>> quotes,
  ) {
    final pendingId = job['pending_quote_revision_id']?.toString();
    final acceptedId = job['accepted_quote_id']?.toString();

    Map<String, dynamic>? revised;
    Map<String, dynamic>? original;

    for (final quote in quotes) {
      if (quote['id']?.toString() == pendingId) revised = quote;
      if (quote['id']?.toString() == acceptedId) original = quote;
    }

    if (revised == null || original == null) {
      return _card(
        'Cotización revisada',
        'No pudimos cargar la comparación. Desliza hacia abajo para actualizar.',
        Icons.sync_problem_rounded,
      );
    }

    final originalTotal = _asDouble(original['total_amount']);
    final revisedTotal = _asDouble(revised['total_amount']);
    final reason = revised['revision_reason']?.toString() ?? '';

    Widget amountRow(String label, dynamic before, dynamic after) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            SizedBox(
              width: 82,
              child: Text(
                '\$${_asDouble(before).toStringAsFixed(2)}',
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 82,
              child: Text(
                '\$${_asDouble(after).toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }

    return FixisSurface(
      padding: const EdgeInsets.all(18),
      shadows: const [],
      border: Border.all(color: Colors.orange.withValues(alpha: .25)),
      radius: AppTheme.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comparación de cotización',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(child: SizedBox()),
              SizedBox(
                width: 82,
                child: Text('Original', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              SizedBox(width: 10),
              SizedBox(
                width: 82,
                child: Text('Revisada', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const Divider(),
          amountRow('Mano de obra', original['labor_amount'], revised['labor_amount']),
          amountRow('Materiales', original['materials_amount'], revised['materials_amount']),
          amountRow('Otros', original['other_amount'], revised['other_amount']),
          const Divider(),
          Row(
            children: [
              const Expanded(
                child: Text('Total', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              SizedBox(
                width: 82,
                child: Text(
                  '\$${originalTotal.toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 82,
                child: Text(
                  '\$${revisedTotal.toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryOrange,
                  ),
                ),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Motivo del cambio', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(reason, style: const TextStyle(height: 1.4)),
          ],
          if ((revised['notes']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Notas del FIXI', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(revised['notes'].toString()),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryOrange),
            onPressed: _loadingAction ? null : () => _acceptRevision(revised!['id'].toString()),
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Aceptar nueva cotización'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _loadingAction ? null : () => _rejectRevision(revised!['id'].toString()),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Rechazar cambio'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Si rechazas el cambio, la cotización anterior permanece vigente. '
            'El FIXI podrá continuar con el alcance original o coordinar una cancelación por separado.',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.35),
          ),
        ],
      ),
    );
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _quoteCard(Map<String, dynamic> q) {
    final total = (q['total_amount'] as num?)?.toDouble() ?? 0;
    return FixisSurface(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      shadows: const [],
      border: Border.all(color: AppTheme.slate200),
      radius: AppTheme.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              const Text(
                'Propuesta del FIXI',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Mano de obra: \$${_money(q['labor_amount'])}'),
          Text('Materiales: \$${_money(q['materials_amount'])}'),
          Text('Otros: \$${_money(q['other_amount'])}'),
          if ((q['notes']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(q['notes'].toString(), style: const TextStyle(color: Colors.black54)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryOrange),
              onPressed: _loadingAction ? null : () => _acceptQuote(q['id'].toString()),
              child: const Text('Aceptar cotización'),
            ),
          ),
        ],
      ),
    );
  }

  String _money(dynamic value) => ((value as num?)?.toDouble() ?? 0).toStringAsFixed(2);

  Widget _card(String title, String text, IconData icon) => FixisSurface(
        padding: const EdgeInsets.all(16),
        shadows: const [],
        border: Border.all(color: AppTheme.slate200),
        radius: AppTheme.radiusMd,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primaryBlue),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(text),
            ])),
          ],
        ),
      );

  Widget _actionInfo(String title, String subtitle, IconData icon, Color color) => FixisSurface(
        padding: const EdgeInsets.all(18),
        shadows: const [],
        color: color.withValues(alpha: .08),
        border: Border.all(color: color.withValues(alpha: .16)),
        radius: AppTheme.radiusMd,
        child: Row(children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 4),
            Text(subtitle),
          ])),
        ]),
      );

  String _statusLabel(String status) => switch (status) {
        'pending' => 'Buscando FIXI disponible',
        'accepted' => 'FIXI asignado',
        'quote_submitted' => 'Cotización recibida',
        'authorized' => 'Cotización aprobada',
        'en_route' => 'FIXI en camino',
        'arrived' => 'FIXI llegó',
        'quote_revision_pending' => 'Revisión de cotización pendiente',
        'in_progress' => 'Servicio en curso',
        'work_completed' => 'Trabajo terminado · pago pendiente',
        'customer_approved' => 'Servicio confirmado',
        'completed' => 'Completado (legacy)',
        'cancelled' => 'Cancelado',
        _ => status,
      };
}
