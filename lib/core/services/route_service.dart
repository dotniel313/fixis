import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final DateTime calculatedAt;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.calculatedAt,
  });

  Duration get duration => Duration(seconds: durationSeconds.round());
}

abstract class RouteService {
  Future<RouteResult> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  });
}

class OsrmRouteService implements RouteService {
  final http.Client _client;
  final String baseUrl;

  OsrmRouteService({
    http.Client? client,
    this.baseUrl = 'https://router.project-osrm.org',
  }) : _client = client ?? http.Client();

  @override
  Future<RouteResult> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final coordinates = '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}';

    final uri = Uri.parse('$baseUrl/route/v1/driving/$coordinates').replace(
      queryParameters: const {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
      },
    );

    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RouteServiceException(
        'ROUTE_HTTP_${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const RouteServiceException('ROUTE_INVALID_RESPONSE');
    }

    if (decoded['code'] != 'Ok') {
      throw RouteServiceException(decoded['code']?.toString() ?? 'NO_ROUTE');
    }

    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty || routes.first is! Map) {
      throw const RouteServiceException('NO_ROUTE');
    }

    final route = Map<String, dynamic>.from(routes.first as Map);
    final geometry = route['geometry'];
    if (geometry is! Map) {
      throw const RouteServiceException('ROUTE_GEOMETRY_MISSING');
    }

    final coordinatesList = geometry['coordinates'];
    if (coordinatesList is! List || coordinatesList.length < 2) {
      throw const RouteServiceException('ROUTE_GEOMETRY_MISSING');
    }

    final points = <LatLng>[];
    for (final coordinate in coordinatesList) {
      if (coordinate is List && coordinate.length >= 2) {
        final lng = coordinate[0];
        final lat = coordinate[1];
        if (lng is num && lat is num) {
          points.add(LatLng(lat.toDouble(), lng.toDouble()));
        }
      }
    }

    if (points.length < 2) {
      throw const RouteServiceException('ROUTE_GEOMETRY_MISSING');
    }

    final distance = route['distance'];
    final duration = route['duration'];
    if (distance is! num || duration is! num) {
      throw const RouteServiceException('ROUTE_METRICS_MISSING');
    }

    return RouteResult(
      points: List.unmodifiable(points),
      distanceMeters: distance.toDouble(),
      durationSeconds: duration.toDouble(),
      calculatedAt: DateTime.now(),
    );
  }
}

class RouteServiceException implements Exception {
  final String code;
  const RouteServiceException(this.code);

  @override
  String toString() => code;
}
