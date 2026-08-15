import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/sample_map_trips.dart';
import '../models/trip.dart';
import '../theme/app_theme.dart';

/// Map of logged GPS trips. Uses stored points only (no live GPS).
///
/// - Trips with geometry → real routes
/// - Trips exist but none have GPS paths → empty state (not samples)
/// - No trips at all → optional sample preview
class TripsMap extends StatelessWidget {
  final List<Trip> trips;
  final double height;
  final VoidCallback? onSaveSamples;
  final bool savingSamples;

  const TripsMap({
    super.key,
    required this.trips,
    this.height = 220,
    this.onSaveSamples,
    this.savingSamples = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final real = trips.where((t) => t.hasMapGeometry).toList();
    final hasAnyTrips = trips.isNotEmpty;
    final isSample = real.isEmpty && !hasAnyTrips;
    final noGeometryYet = real.isEmpty && hasAnyTrips;
    final mapped = isSample ? SampleMapTrips.asTrips() : real;

    if (noGeometryYet) {
      return _EmptyMapShell(
        height: height,
        message:
            'You have ${trips.length} trip${trips.length == 1 ? '' : 's'}, '
            'but none have a GPS route yet. New tracked trips will draw here. '
            'If they still don\'t, run Supabase migration 002_trip_routes.sql.',
      );
    }

    if (mapped.isEmpty) {
      return _EmptyMapShell(
        height: height,
        message: 'No routes to show yet. Start a GPS trip or log one with a path.',
      );
    }

    final polylines = <Polyline>[];
    final markers = <Marker>[];
    final allPoints = <LatLng>[];

    for (final trip in mapped) {
      final pts = trip.mapPoints
          .map((g) => LatLng(g.lat, g.lng))
          .toList(growable: false);
      if (pts.isEmpty) continue;

      allPoints.addAll(pts);
      final color = AppColors.sourceColor(trip.source);
      polylines.add(
        Polyline(
          points: pts,
          color: color.withValues(alpha: isSample ? 0.7 : 0.85),
          strokeWidth: 3.5,
        ),
      );
      markers.add(
        Marker(
          point: pts.first,
          width: 28,
          height: 28,
          child: _Dot(color: AppColors.green, label: 'S'),
        ),
      );
      if (pts.length > 1) {
        markers.add(
          Marker(
            point: pts.last,
            width: 28,
            height: 28,
            child: _Dot(color: AppColors.red, label: 'E'),
          ),
        );
      }
    }

    if (allPoints.isEmpty) {
      return _EmptyMapShell(
        height: height,
        message: 'No map points available.',
      );
    }

    final bounds = LatLngBounds.fromPoints(allPoints);

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(36),
                maxZoom: 14,
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              // Carto Voyager — cleaner, more modern basemap than plain OSM.
              TileLayer(
                urlTemplate:
                    'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ultraforge.trektrack',
                retinaMode: RetinaMode.isHighDensity(context),
              ),
              PolylineLayer(polylines: polylines),
              MarkerLayer(markers: markers),
            ],
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: p.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.border),
              ),
              child: Text(
                isSample
                    ? 'Sample routes (preview)'
                    : '${mapped.length} GPS trip${mapped.length == 1 ? '' : 's'} on map',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: p.text,
                ),
              ),
            ),
          ),
          if (isSample && onSaveSamples != null)
            Positioned(
              right: 10,
              bottom: 10,
              child: FilledButton.tonal(
                onPressed: savingSamples ? null : onSaveSamples,
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: savingSamples
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save samples', style: TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyMapShell extends StatelessWidget {
  final double height;
  final String message;

  const _EmptyMapShell({required this.height, required this.message});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: p.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, color: p.textMuted, size: 36),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: p.textMuted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final String label;

  const _Dot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
