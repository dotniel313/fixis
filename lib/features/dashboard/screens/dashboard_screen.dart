// FIXIS PRO v1.10.1 - Map-first professional home.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/fixis_map_tiles.dart';
import '../../../core/widgets/fixis_ui.dart';
import '../../auth/providers/auth_repository.dart';
import '../../activity/screens/professional_activity_screen.dart';
import '../../jobs/providers/jobs_repository.dart';
import '../../jobs/screens/job_detail_screen.dart';
import '../../notifications/providers/notifications_repository.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../wallet/screens/wallet_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isOnline = false;
  bool _isLoadingLocation = false;
  bool _isAcceptingJob = false;
  bool _isLoadingNearbyJobs = false;
  Position? _currentPosition;
  double _serviceRadiusKm = 8;
  List<Map<String, dynamic>> _nearbyJobs = const [];
  final MapController _radarMapController = MapController();
  bool _radarMapReady = false;
  int _selectedTab = 0;
  bool _activityVisited = false;
  bool _walletVisited = false;

  static const String _keyLocationAccepted =
      'has_accepted_location_disclosure';

  @override
  void dispose() {
    _radarMapController.dispose();
    super.dispose();
  }

  Future<bool> _showLegalLocationDisclosureIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final hasAccepted = prefs.getBool(_keyLocationAccepted) ?? false;

    if (hasAccepted) return true;
    if (!mounted) return false;

    final userAgreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Row(
          children: [
            Icon(Icons.location_on, color: AppTheme.primaryBlue, size: 28),
            SizedBox(width: 8),
            Text(
              'Uso de Ubicación',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.darkSlate,
              ),
            ),
          ],
        ),
        content: const Text(
          'Fixis PRO utiliza tu ubicación para buscar clientes cercanos cuando estás “En Línea”. La ubicación solo debe activarse cuando quieras recibir nuevas oportunidades.',
          style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    if (userAgreed == true) {
      await prefs.setBool(_keyLocationAccepted, true);
      return true;
    }

    return false;
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    final repository = ref.read(jobsRepositoryProvider);

    if (!value) {
      try {
        await repository.updateProfessionalPresence(isAvailable: false);
      } catch (_) {
        // La UI puede apagarse aunque falle el sync; se revalidará al volver online.
      }
      if (!mounted) return;
      setState(() {
        _isOnline = false;
        _currentPosition = null;
        _nearbyJobs = const [];
      });
      _radarMapReady = false;
      return;
    }

    final userAgreed = await _showLegalLocationDisclosureIfNeeded();
    if (!userAgreed || !mounted) return;

    setState(() => _isLoadingLocation = true);

    if (!await Geolocator.isLocationServiceEnabled()) {
      _showError('Los servicios de ubicación están desactivados.');
      if (mounted) setState(() => _isLoadingLocation = false);
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      _showError('Permisos de ubicación denegados.');
      if (mounted) setState(() => _isLoadingLocation = false);
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      _showError('Los permisos de ubicación están bloqueados en tu celular.');
      if (mounted) setState(() => _isLoadingLocation = false);
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await repository.updateProfessionalPresence(
        isAvailable: true,
        latitude: position.latitude,
        longitude: position.longitude,
        serviceRadiusKm: _serviceRadiusKm,
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _isOnline = true;
        _isLoadingLocation = false;
      });

      await _loadNearbyJobs();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Radar activo! Mostrando oportunidades compatibles.'),
          backgroundColor: Colors.green,
        ),
      );
    } on JobActionException catch (e) {
      _showError(e.message);
      if (mounted) setState(() => _isLoadingLocation = false);
    } catch (_) {
      _showError('No se pudo activar tu ubicación profesional.');
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _loadNearbyJobs() async {
    if (!_isOnline) return;
    setState(() => _isLoadingNearbyJobs = true);
    try {
      final jobs = await ref.read(jobsRepositoryProvider).getNearbyJobs();
      if (!mounted) return;
      setState(() {
        _nearbyJobs = jobs;
        _isLoadingNearbyJobs = false;
      });
    } on JobActionException catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingNearbyJobs = false);
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingNearbyJobs = false);
      _showError('No pudimos actualizar las oportunidades cercanas.');
    }
  }

  Future<void> _changeRadius(double radius) async {
    setState(() => _serviceRadiusKm = radius);
    if (_radarMapReady && _currentPosition != null) {
      _radarMapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        _zoomForRadius(radius),
      );
    }
    if (!_isOnline || _currentPosition == null) return;

    try {
      await ref.read(jobsRepositoryProvider).updateProfessionalPresence(
            isAvailable: true,
            latitude: _currentPosition!.latitude,
            longitude: _currentPosition!.longitude,
            serviceRadiusKm: radius,
          );
      await _loadNearbyJobs();
    } on JobActionException catch (e) {
      _showError(e.message);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _handleAcceptJob(Map<String, dynamic> job) async {
    setState(() => _isAcceptingJob = true);

    try {
      final acceptedJob = await ref
          .read(jobsRepositoryProvider)
          .acceptNearbyJob((job['job_id'] ?? job['id']).toString());

      if (!mounted) return;
      setState(() {
        _isAcceptingJob = false;
        _nearbyJobs = _nearbyJobs
            .where((item) => item['job_id']?.toString() != job['job_id']?.toString())
            .toList(growable: false);
      });

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => JobDetailScreen(job: acceptedJob),
        ),
      );
    } on JobActionException catch (e) {
      if (!mounted) return;
      setState(() => _isAcceptingJob = false);
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isAcceptingJob = false);
      _showError('No fue posible aceptar este trabajo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: IndexedStack(
        index: _selectedTab,
        children: [
          SafeArea(
            top: false,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
          _activityVisited
              ? const ProfessionalActivityScreen()
              : const SizedBox.shrink(),
          _walletVisited ? const WalletScreen() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 70,
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.primaryBlue.withValues(alpha: 0.12),
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) {
          if (index == _selectedTab) return;
          setState(() {
            _selectedTab = index;
            if (index == 1) _activityVisited = true;
            if (index == 2) _walletVisited = true;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.radar_outlined),
            selectedIcon: Icon(Icons.radar_rounded),
            label: 'Radar',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Actividad',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Billetera',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final firstName = profile?['full_name']?.toString().split(' ').first ?? 'Experto';
    final category = profile?['category']?.toString() ?? 'Profesional';
    final avatarUrl = profile?['avatar_url']?.toString();
    final unread = ref.watch(unreadNotificationsCountProvider);

    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.paddingOf(context).top + 10,
        18,
        14,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.midnight, AppTheme.midnightSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const FixisBrandMark(compact: true),
              const Spacer(),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  FixisIconButton(
                    icon: Icons.notifications_none_rounded,
                    tooltip: 'Notificaciones',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: -3,
                      top: -4,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.danger,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.midnightSoft,
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primaryOrange,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.midnightSoft,
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? const Icon(Icons.person_rounded, color: Colors.white)
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buenas, $firstName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.only(left: 10, right: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _isOnline
                        ? AppTheme.success.withValues(alpha: 0.45)
                        : Colors.white24,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isOnline ? 'En línea' : 'Desconectado',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _isLoadingLocation
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Switch(
                            value: _isOnline,
                            activeTrackColor:
                                AppTheme.success.withValues(alpha: 0.55),
                            activeThumbColor: AppTheme.success,
                            onChanged: _toggleOnlineStatus,
                          ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        _buildMapFirstRadar(),
        const SizedBox(height: 18),
        _buildMyActiveJobs(),
        FixisSectionHeader(
          title: 'Nuevas oportunidades',
          subtitle: _isOnline
              ? 'Solicitudes compatibles dentro de tu radio'
              : 'Activa el radar para buscar servicios cercanos',
        ),
        const SizedBox(height: 10),
        if (_isOnline) _buildRealtimeJobsArea() else _buildOfflineRadar(),
      ],
    );
  }

  Widget _buildMapFirstRadar() {
    final position = _currentPosition;

    return FixisSurface(
      padding: EdgeInsets.zero,
      radius: AppTheme.radiusLg,
      border: Border.all(color: AppTheme.slate200),
      shadows: const [],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusLg),
            ),
            child: SizedBox(
              height: (MediaQuery.sizeOf(context).height * 0.52)
                  .clamp(330.0, 500.0)
                  .toDouble(),
              child: position == null
                  ? _buildMapPlaceholder()
                  : Stack(
                      children: [
                        FlutterMap(
                      mapController: _radarMapController,
                      options: MapOptions(
                        initialCenter: LatLng(
                          position.latitude,
                          position.longitude,
                        ),
                        initialZoom: _zoomForRadius(_serviceRadiusKm),
                        minZoom: 4,
                        maxZoom: 18,
                        backgroundColor: fixisMapCanvas(),
                        onMapReady: () => _radarMapReady = true,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                      ),
                      children: [
                        const FixisMapTiles(),
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: LatLng(
                                position.latitude,
                                position.longitude,
                              ),
                              radius: _serviceRadiusKm * 1000,
                              useRadiusInMeter: true,
                              color: AppTheme.primaryOrange.withValues(
                                alpha: 0.075,
                              ),
                              borderColor:
                                  AppTheme.primaryOrange.withValues(alpha: 0.65),
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(
                                position.latitude,
                                position.longitude,
                              ),
                              width: 62,
                              height: 72,
                              child: _professionalMapMarker(),
                            ),
                            ..._nearbyJobs
                                .map(_jobMarker)
                                .whereType<Marker>(),
                          ],
                        ),
                        const RichAttributionWidget(
                          attributions: [
                            TextSourceAttribution(
                              'OpenStreetMap contributors',
                            ),
                          ],
                        ),
                      ],
                    ),
                        Positioned(
                          right: 14,
                          top: 14,
                          child: Material(
                            color: Colors.white,
                            elevation: 3,
                            shape: const CircleBorder(),
                            child: IconButton(
                              tooltip: 'Centrar mi zona',
                              icon: const Icon(Icons.my_location_rounded),
                              color: AppTheme.primaryBlue,
                              onPressed: () => _radarMapController.move(
                                LatLng(position.latitude, position.longitude),
                                _zoomForRadius(_serviceRadiusKm),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    position == null
                        ? 'Activa el radar para visualizar tu cobertura.'
                        : '${_nearbyJobs.length} oportunidades · radio ${_serviceRadiusKm.toInt()} km',
                    style: const TextStyle(
                      color: AppTheme.slate500,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_isOnline)
                  PopupMenuButton<double>(
                    tooltip: 'Cambiar radio de servicio',
                    onSelected: _changeRadius,
                    itemBuilder: (_) => [5.0, 8.0, 15.0, 25.0]
                        .map((radius) => PopupMenuItem<double>(
                              value: radius,
                              child: Text('Radio ${radius.toInt()} km'),
                            ))
                        .toList(),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Icon(Icons.tune_rounded,
                          color: AppTheme.primaryBlue),
                    ),
                  ),
                if (_isOnline)
                  IconButton(
                    tooltip: 'Actualizar oportunidades',
                    onPressed: _isLoadingNearbyJobs ? null : _loadNearbyJobs,
                    icon: const Icon(Icons.refresh_rounded,
                        color: AppTheme.primaryBlue),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    return Container(
      color: AppTheme.midnight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RadarGridPainter(),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryOrange.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Icon(
                    Icons.radar_rounded,
                    color: AppTheme.primaryOrange,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Activa tu Radar FIXIS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Verás tu cobertura y oportunidades cercanas',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
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

  Marker? _jobMarker(Map<String, dynamic> job) {
    double? readDouble(List<String> keys) {
      for (final key in keys) {
        final raw = job[key];
        if (raw is num) return raw.toDouble();
        final parsed = double.tryParse(raw?.toString() ?? '');
        if (parsed != null) return parsed;
      }
      return null;
    }

    final lat = readDouble(
      const ['latitude', 'lat', 'job_latitude', 'service_latitude'],
    );
    final lng = readDouble(
      const ['longitude', 'lng', 'lon', 'job_longitude', 'service_longitude'],
    );

    if (lat == null || lng == null) return null;

    final category = job['category']?.toString().toLowerCase() ?? '';
    final categoryIcon = category.contains('electric')
        ? Icons.bolt_rounded
        : category.contains('plomer') || category.contains('gasfit')
            ? Icons.water_drop_rounded
            : category.contains('cerraj')
                ? Icons.key_rounded
                : Icons.handyman_rounded;

    return Marker(
      point: LatLng(lat, lng),
      width: 48,
      height: 48,
      child: GestureDetector(
        onTap: () => _showMapOpportunity(job),
        child: Container(
          alignment: Alignment.topCenter,
          child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: AppTheme.softShadow,
            ),
            child: Icon(
              categoryIcon,
              color: Colors.white,
              size: 17,
            ),
          ),
        ),
      ),
    );
  }

  Widget _professionalMapMarker() {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
        ),
        Positioned(
          top: 8,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: AppTheme.softShadow,
            ),
            child: const Icon(
              Icons.person_pin_circle_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  void _showMapOpportunity(Map<String, dynamic> job) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        final distance = job['distance_km'];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FixisStatusPill(
                  label: job['category']?.toString().toUpperCase() ??
                      'SERVICIO',
                  color: AppTheme.primaryOrange,
                  icon: Icons.handyman_rounded,
                ),
                const SizedBox(height: 12),
                Text(
                  job['title']?.toString() ?? 'Oportunidad FIXIS',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 7),
                Text(
                  job['address']?.toString() ?? 'Ubicación del servicio',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (distance != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '$distance km de ti',
                    style: const TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isAcceptingJob
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            _handleAcceptJob(job);
                          },
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Aceptar oportunidad'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _zoomForRadius(double radiusKm) {
    if (radiusKm <= 5) return 12.4;
    if (radiusKm <= 8) return 11.7;
    if (radiusKm <= 15) return 10.8;
    return 10.0;
  }

  Widget _buildMyActiveJobs() {
    final activeAsync = ref.watch(myActiveJobsStreamProvider);

    return activeAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (jobs) {
        if (jobs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FixisSectionHeader(
              title: 'Mis servicios activos',
              subtitle: 'Continúa donde lo dejaste',
            ),
            const SizedBox(height: 12),
            ...jobs.map(_buildActiveJobCard),
          ],
        );
      },
    );
  }

  Widget _buildActiveJobCard(Map<String, dynamic> job) {
    final status = job['status']?.toString() ?? '';
    final label = switch (status) {
      'accepted' => 'COTIZAR',
      'quote_submitted' => 'ESPERANDO CLIENTE',
      'authorized' => 'AUTORIZADO',
      'en_route' => 'EN CAMINO',
      'arrived' => 'LLEGÓ',
      'in_progress' => 'EN PROGRESO',
      _ => status.toUpperCase(),
    };

    return FixisSurface(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      radius: AppTheme.radiusMd,
      border: Border.all(color: AppTheme.slate200),
      shadows: const [],
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.handyman_outlined,
            color: AppTheme.primaryBlue,
          ),
        ),
        title: Text(
          job['title']?.toString() ?? 'Servicio',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => JobDetailScreen(job: job),
          ),
        ),
      ),
    );
  }

  Widget _buildRealtimeJobsArea() {
    if (_isLoadingNearbyJobs) return _buildRadarLoading();

    if (_nearbyJobs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Text(
          'Sin solicitudes compatibles en ${_serviceRadiusKm.toInt()} km. '
          'Te avisaremos cuando aparezcan.',
          style: const TextStyle(color: AppTheme.slate500, fontSize: 13),
        ),
      );
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _loadNearbyJobs,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Actualizar radar'),
          ),
        ),
        ..._nearbyJobs.map(_buildJobCard),
      ],
    );
  }

  Widget _buildRadarLoading() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryOrange),
          const SizedBox(height: 18),
          const Text(
            'Buscando clientes cerca de ti...',
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_currentPosition != null) ...[
            const SizedBox(height: 6),
            Text(
              'Tu ubicación está activa',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOfflineRadar() {
    return const _InfoCard(
      icon: Icons.location_off_rounded,
      title: 'Radar desconectado',
      message:
          'Activa tu disponibilidad para recibir nuevas oportunidades. Tus servicios ya aceptados permanecen accesibles.',
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.primaryOrange.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        job['category']?.toString() ?? 'Servicio',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'NUEVA SOLICITUD',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  job['title']?.toString() ?? 'Sin título',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkSlate,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Cliente FIXIS',
                  style: TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 6),
                Text(
                  job['address']?.toString() ?? 'Dirección no especificada',
                  style: const TextStyle(color: Colors.grey),
                ),
                if (job['distance_km'] != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.near_me_rounded, size: 16, color: AppTheme.primaryBlue),
                      const SizedBox(width: 6),
                      Text(
                        '${job['distance_km']} km de ti',
                        style: const TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          InkWell(
            onTap: _isAcceptingJob ? null : () => _handleAcceptJob(job),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: const BoxDecoration(
                color: AppTheme.primaryOrange,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Center(
                child: _isAcceptingJob
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'ACEPTAR OPORTUNIDAD',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _RadarGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide * 0.62;

    for (final factor in [0.25, 0.5, 0.75, 1.0]) {
      canvas.drawCircle(center, maxRadius * factor, paint);
    }

    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return FixisSurface(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      shadows: const [],
      border: Border.all(color: AppTheme.slate200),
      child: Column(
        children: [
          Icon(icon, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.darkSlate,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, height: 1.4),
          ),
        ],
      ),
    );
  }
}
