import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../location/location_providers.dart';

/// Creates or edits a place in a dialog; returns its id, or null if
/// cancelled. Editing keeps the fields this client doesn't know.
Future<String?> editPlace(
  BuildContext context,
  WidgetRef ref, {
  Place? place,
  String? initialName,
}) => showDialog<String>(
  context: context,
  builder: (context) =>
      _PlaceDialog(place: place, initialName: initialName, ref: ref),
);

class _PlaceDialog extends StatefulWidget {
  const _PlaceDialog({this.place, this.initialName, required this.ref});

  final Place? place;
  final String? initialName;
  final WidgetRef ref;

  @override
  State<_PlaceDialog> createState() => _PlaceDialogState();
}

class _PlaceDialogState extends State<_PlaceDialog> {
  static const _parkingOptions = [0, 5, 10, 15, 20];

  late final _name = TextEditingController(
    text: widget.place?.name ?? widget.initialName ?? '',
  );
  late final _address = TextEditingController(
    text: widget.place?.address ?? '',
  );
  late var _home = widget.place?.isHome ?? false;
  late var _parking = widget.place?.parkingBufferMinutes ?? 0;
  late var _spot = widget.place?.location;
  late var _radius = widget.place?.radiusMeters ?? 100;
  var _locating = false;
  static const _radiusOptions = [50.0, 100.0, 200.0, 400.0];
  String? _error;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = context.l10n.placeNameRequired);
      return;
    }
    setState(() => _saving = true);
    final store = await widget.ref.read(familyStoreProvider.future);
    final id = widget.place?.id;
    final existing = id == null ? null : await store.payloadOf(id);
    final saved = await store.savePlace(
      PlacePayload.write(
        existing: existing,
        name: name,
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        isHome: _home,
        parkingBufferMinutes: _parking,
      ),
      id: id,
    );
    if (_spot != widget.place?.location ||
        _radius != widget.place?.radiusMeters) {
      await store.setPlaceLocation(saved, _spot, radiusMeters: _radius);
    }
    widget.ref.read(syncControllerProvider.notifier).syncNow();
    if (mounted) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.place == null ? l10n.newPlace : l10n.editPlace),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.place == null,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.placeName,
                hintText: l10n.placeNameHint,
                errorText: _error,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _address,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.placeAddress),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _parkingOptions.contains(_parking) ? _parking : 0,
              decoration: InputDecoration(labelText: l10n.parkingBuffer),
              items: [
                for (final m in _parkingOptions)
                  DropdownMenuItem(
                    value: m,
                    child: Text(
                      m == 0 ? l10n.parkingNone : l10n.parkingMinutes(m),
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _parking = v ?? 0),
            ),
            // Spec §7: where it is, for "at school since 08:12". From this
            // phone standing there: no address lookup service involved.
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.my_location),
              title: Text(
                _spot == null ? l10n.placeSpotUnset : l10n.placeSpotSet,
              ),
              subtitle: Text(l10n.placeSpotHelp),
              trailing: _locating
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _spot == null
                  ? null
                  : IconButton(
                      tooltip: l10n.clear,
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _spot = null),
                    ),
              onTap: _locating
                  ? null
                  : () async {
                      setState(() => _locating = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final denied = l10n.locationDenied;
                      GeoPoint? here;
                      try {
                        here = await whereAmI();
                      } catch (_) {
                        here = null;
                      }
                      if (!mounted) return;
                      setState(() {
                        _locating = false;
                        _spot = here ?? _spot;
                      });
                      if (here == null) {
                        messenger.showSnackBar(SnackBar(content: Text(denied)));
                      }
                    },
            ),
            if (_spot != null)
              DropdownButtonFormField<double>(
                initialValue: _radiusOptions.contains(_radius) ? _radius : 100,
                decoration: InputDecoration(labelText: l10n.placeRadius),
                items: [
                  for (final r in _radiusOptions)
                    DropdownMenuItem(
                      value: r,
                      child: Text(l10n.metres(r.round())),
                    ),
                ],
                onChanged: (v) => setState(() => _radius = v ?? 100),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.placeIsHome),
              subtitle: Text(l10n.placeIsHomeSubtitle),
              value: _home,
              onChanged: (v) => setState(() => _home = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(onPressed: _saving ? null : _save, child: Text(l10n.save)),
      ],
    );
  }
}

/// Picks a place for an event: the family's places, a new one, or none.
/// Returns the chosen id, '' for none, or null if dismissed.
Future<String?> pickPlace(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final places = ref.watch(placesProvider).value ?? const <Place>[];
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  l10n.choosePlace,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final p in places)
                ListTile(
                  leading: Icon(
                    p.isHome ? Icons.home_outlined : Icons.place_outlined,
                  ),
                  title: Text(p.name),
                  subtitle: p.address == null ? null : Text(p.address!),
                  onTap: () => Navigator.pop(context, p.id),
                ),
              ListTile(
                leading: const Icon(Icons.add_location_alt_outlined),
                title: Text(l10n.newPlace),
                onTap: () async {
                  final id = await editPlace(context, ref);
                  if (id != null && context.mounted) {
                    Navigator.pop(context, id);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.location_off_outlined),
                title: Text(l10n.noPlace),
                onTap: () => Navigator.pop(context, ''),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ),
  );
}
