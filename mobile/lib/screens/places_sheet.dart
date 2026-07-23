import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../models/saved_place.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_sheet.dart';

Future<void> showPlacesSheet(BuildContext context) async {
  await showAppBottomSheet(
    context,
    const _PlacesSheetBody(),
  );
}

class _PlacesSheetBody extends StatelessWidget {
  const _PlacesSheetBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final p = context.palette;
        final places = state.places.places;

        return AppBottomSheet(
          title: 'Places',
          subtitle:
              'Skip auto-start near home, or mark trips personal/business when they end nearby.',
          children: [
            FilledButton.icon(
              onPressed: () => _addCurrentLocation(context, state),
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Add current location'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (places.isEmpty)
              Text(
                'No places yet. Add home as “Skip auto-start” so driveway rolls don’t become trips.',
                style: TextStyle(color: p.textMuted, height: 1.4, fontSize: 13),
              )
            else
              ...places.map(
                (place) => Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    title: Text(place.name),
                    subtitle: Text(
                      '${place.modeLabel} · ${place.radiusMeters.round()} m',
                      style: TextStyle(fontSize: 12, color: p.textMuted),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: p.textMuted),
                      onPressed: () => state.places.remove(place.id),
                    ),
                    onTap: () => _editPlace(context, state, place),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _addCurrentLocation(BuildContext context, AppState state) async {
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Turn on Location Services first.')),
          );
        }
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is required.')),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      if (!context.mounted) return;
      await _editPlace(
        context,
        state,
        SavedPlace(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'Home',
          lat: pos.latitude,
          lng: pos.longitude,
          radiusMeters: 120,
          mode: PlaceMode.exclude,
        ),
        isNew: true,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    }
  }

  Future<void> _editPlace(
    BuildContext context,
    AppState state,
    SavedPlace place, {
    bool isNew = false,
  }) async {
    final nameController = TextEditingController(text: place.name);
    var mode = place.mode;
    var radius = place.radiusMeters;

    final saved = await showDialog<SavedPlace>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(isNew ? 'New place' : 'Edit place'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PlaceMode>(
                      // ignore: deprecated_member_use
                      value: mode,
                      decoration: const InputDecoration(labelText: 'Behavior'),
                      items: PlaceMode.values
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(switch (m) {
                                PlaceMode.exclude => 'Skip auto-start nearby',
                                PlaceMode.personal => 'End nearby → personal',
                                PlaceMode.business => 'End nearby → business',
                              }),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setLocal(() => mode = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    Text('Radius: ${radius.round()} m'),
                    Slider(
                      value: radius.clamp(50, 400),
                      min: 50,
                      max: 400,
                      divisions: 14,
                      label: '${radius.round()} m',
                      onChanged: (v) => setLocal(() => radius = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(
                      ctx,
                      place.copyWith(
                        name: name,
                        mode: mode,
                        radiusMeters: radius,
                      ),
                    );
                  },
                  child: Text(isNew ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    if (saved == null) return;
    if (isNew) {
      await state.places.add(saved);
    } else {
      await state.places.update(saved);
    }
  }
}
