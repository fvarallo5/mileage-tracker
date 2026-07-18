import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/trip.dart';
import '../theme/app_theme.dart';

/// Map of logged GPS trips. Uses existing stored points only (no live GPS).
class TripsMap extends StatelessWidget {
  final List<Trip> trips;
  final double height;

  const TripsMap({
    super.key,
    required this.trips,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final mapped = trips.where((t) => t.hasMapGeometry).toList();

    if (mapped.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: p.border),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, size: 32, color: p.textMuted),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Trip map',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'GPS and auto-detect trips appear here after you save them. Manual imports stay list-only.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final polylines = <Polyline>[];
    final markers = <Marker>[];
    final allPoints = <LatLng>[];

    for (var i = 0; i < mapped.length; i++) {
      final trip = mapped[i];
      final pts = trip.mapPoints
          .map((g) => LatLng(g.lat, g.lng))
          .toList(growable: false);
      if (pts.isEmpty) continue;

      allPoints.addAll(pts);
      final color = AppColors.sourceColor(trip.source);
      polylines.add(
        Polyline(
          points: pts,
          color: color.withValues(alpha: 0.85),
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
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mileagetracker.mileage_tracker',
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
                '${mapped.length} GPS trip${mapped.length == 1 ? '' : 's'} on map',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: p.text,
                ),
              ),
            ),
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
