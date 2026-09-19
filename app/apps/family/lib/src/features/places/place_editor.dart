import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';

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
