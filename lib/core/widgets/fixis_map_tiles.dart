import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../theme/theme.dart';

/// A quiet, branded treatment for the existing raster basemap. The tile URL
/// stays in one place so a licensed provider can replace it before launch.
class FixisMapTiles extends StatefulWidget {
  const FixisMapTiles({super.key});

  @override
  State<FixisMapTiles> createState() => _FixisMapTilesState();
}

class _FixisMapTilesState extends State<FixisMapTiles>
    with WidgetsBindingObserver {
  late bool _isNight;
  Timer? _clock;

  static bool _nightNow() {
    final hour = DateTime.now().hour;
    return hour < 6 || hour >= 18;
  }

  @override
  void initState() {
    super.initState();
    _isNight = _nightNow();
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    final next = _nightNow();
    if (next != _isNight) setState(() => _isNight = next);
  }

  @override
  void dispose() {
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The night matrix maps light land to midnight and dark labels to slate.
    // It applies only to raster tiles, leaving FIXIS pins and routes intact.
    const nightPalette = ColorFilter.matrix(<double>[
      -0.18, -0.35, -0.07, 0, 175,
      -0.19, -0.37, -0.07, 0, 190,
      -0.20, -0.39, -0.07, 0, 210,
      0, 0, 0, 1, 0,
    ]);
    const dayPalette = ColorFilter.matrix(<double>[
      0.55, 0.34, 0.11, 0, 0,
      0.25, 0.64, 0.11, 0, 0,
      0.20, 0.42, 0.38, 0, 0,
      0, 0, 0, 1, 0,
    ]);

    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'ec.com.geotactics.fixis_pro',
      tileBuilder: (_, tileWidget, __) => ColorFiltered(
        colorFilter: _isNight ? nightPalette : dayPalette,
        child: tileWidget,
      ),
    );
  }
}

Color fixisMapCanvas() {
  final hour = DateTime.now().hour;
  return hour < 6 || hour >= 18
      ? AppTheme.midnight
      : AppTheme.slate100;
}
