// FIXIS PRO v1.10.1 - Map-first professional home.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/fixis_ui.dart';
import '../../auth/providers/auth_repository.dart';
import '../../activity/screens/professional_activity_screen.dart';
import '../../gamification/screens/gamification_screen.dart';
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

  static const String _keyLocationAccepted =
      'has_accepted_location_disclosure';

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
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(
        top: 54,
        left: 20,
        right: 20,
        bottom: 22,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.midnight,
            AppTheme.midnightSoft,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.radiusXl),
          bottomRight: Radius.circular(AppTheme.radiusXl),
        ),
        boxShadow: AppTheme.floatingShadow,
      ),
      child: Column(
        children: [
          const Row(
            children: [
              FixisBrandMark(compact: true),
              Spacer(),
              FixisStatusPill(
                label: 'PROFESIONAL',
                color: AppTheme.primaryOrange,
                icon: Icons.verified_rounded,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final profileAsync = ref.watch(userProfileProvider);
                    return profileAsync.when(
                      data: (profile) {
                        final firstName =
                            profile?['full_name']?.toString().split(' ').first ??
                                'Experto';
                        final category =
                            profile?['category']?.toString() ?? 'Profesional';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Buenas, $firstName',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              category,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.68),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      error: (_, __) => const Text(
                        'Buenas, Experto',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              FixisIconButton(
                icon: Icons.account_balance_wallet_rounded,
                tooltip: 'Billetera',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WalletScreen()),
                ),
              ),
              const SizedBox(width: 8),
              Consumer(
                builder: (context, ref, _) {
                  final unread =
                      ref.watch(unreadNotificationsCountProvider);

                  return Stack(
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
                  );
                },
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                child: Consumer(
                  builder: (context, ref, _) {
                    final profile =
                        ref.watch(userProfileProvider).valueOrNull;
                    final avatarUrl = profile?['avatar_url']?.toString();
                    return Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryOrange,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.12),
                        radius: 19,
                        backgroundImage:
                            avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 19,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: _isOnline
                    ? AppTheme.success.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.radar,
                  color: _isOnline ? AppTheme.success : Colors.white54,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isOnline ? 'Estás en Línea' : 'Estás Desconectado',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isOnline
                              ? Colors.white
                              : Colors.white70,
                        ),
                      ),
                      Text(
                        _isOnline
                            ? 'Recibiendo nuevas solicitudes'
                            : 'Tus trabajos aceptados siguen disponibles abajo',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _isLoadingLocation
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Switch(
                        value: _isOnline,
                        activeTrackColor: Colors.green.withValues(alpha: 0.5),
                        activeThumbColor: Colors.green,
                        onChanged: _toggleOnlineStatus,
                      ),
              ],
            ),
          ),
          if (_isOnline) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: AppTheme.primaryOrange,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Radio',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [5.0, 8.0, 15.0, 25.0]
                        .map(
                          (radius) => ChoiceChip(
                            label: Text('${radius.toInt()} km'),
                            selected: _serviceRadiusKm == radius,
                            onSelected: (_) => _changeRadius(radius),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        _buildPremiumQuickActions(),
        const SizedBox(height: 22),
        _buildMapFirstRadar(),
        const SizedBox(height: 22),
        _buildMyActiveJobs(),
        const SizedBox(height: 22),
        FixisSectionHeader(
          title: 'Nuevas oportunidades',
          subtitle: _isOnline
              ? 'Solicitudes compatibles dentro de tu radio'
              : 'Activa el radar para descubrir servicios cercanos',
          trailing: FixisStatusPill(
            label: _isOnline ? 'RADAR ACTIVO' : 'OFFLINE',
            color: _isOnline ? AppTheme.success : AppTheme.slate500,
            icon: _isOnline ? Icons.radar_rounded : Icons.location_off_rounded,
          ),
        ),
        const SizedBox(height: 12),
        if (_isOnline) _buildRealtimeJobsArea() else _buildOfflineRadar(),
      ],
    );
  }

  Widget _buildPremiumQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.workspace_premium_rounded,
            label: 'Nivel FIXIS',
            caption: 'Progreso y logros',
            color: AppTheme.warning,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const GamificationScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.insights_rounded,
            label: 'Mi actividad',
            caption: 'Servicios y rendimiento',
            color: AppTheme.primaryBlue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ProfessionalActivityScreen(),
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildMapFirstRadar() {
    final position = _currentPosition;

    return FixisSurface(
      padding: EdgeInsets.zero,
      radius: AppTheme.radiusLg,
      border: Border.all(color: AppTheme.slate200),
      shadows: AppTheme.softShadow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
            child: Row(
              children: [
                const Expanded(
                  child: FixisSectionHeader(
                    title: 'Radar FIXIS',
                    subtitle: 'Tu zona de servicio en tiempo real',
                  ),
                ),
                FixisStatusPill(
                  label: _isOnline ? 'EN LÍNEA' : 'OFFLINE',
                  color: _isOnline ? AppTheme.success : AppTheme.slate500,
                  icon: _isOnline
                      ? Icons.location_on_rounded
                      : Icons.location_off_rounded,
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(AppTheme.radiusLg),
              bottomRight: Radius.circular(AppTheme.radiusLg),
            ),
            child: SizedBox(
              height: 260,
              child: position == null
                  ? _buildMapPlaceholder()
                  : FlutterMap(
                      key: ValueKey(
                        'professional-radar-${position.latitude.toStringAsFixed(5)}-${position.longitude.toStringAsFixed(5)}-${_serviceRadiusKm.toInt()}',
                      ),
                      options: MapOptions(
                        initialCenter: LatLng(
                          position.latitude,
                          position.longitude,
                        ),
                        initialZoom: _zoomForRadius(_serviceRadiusKm),
                        minZoom: 4,
                        maxZoom: 18,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'fixis_pro',
                        ),
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
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 15),
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
                  TextButton.icon(
                    onPressed:
                        _isLoadingNearbyJobs ? null : _loadNearbyJobs,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Actualizar'),
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

    return Marker(
      point: LatLng(lat, lng),
      width: 54,
      height: 64,
      child: GestureDetector(
        onTap: () => _showMapOpportunity(job),
        child: Container(
          alignment: Alignment.topCenter,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: AppTheme.softShadow,
            ),
            child: const Icon(
              Icons.home_repair_service_rounded,
              color: Colors.white,
              size: 21,
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
      return _InfoCard(
        icon: Icons.radar_rounded,
        title: 'Sin oportunidades dentro de ${_serviceRadiusKm.toInt()} km',
        message:
            'El radar solo muestra solicitudes con tu categoría y ubicación dentro de tu radio de servicio.',
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

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String caption;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.caption,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.slate200),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.darkSlate,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.slate500,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
