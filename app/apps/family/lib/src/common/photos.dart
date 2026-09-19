import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../data/store_providers.dart';
import 'l10n.dart';

/// Longest side a photo is kept at: sharp on a phone, a few hundred KB.
const _maxSide = 1600;

/// Downscales and re-encodes [bytes] as JPEG with only its pixels, so
/// location and device metadata never leave the phone (spec §3
/// "Strip EXIF on ingest": with end-to-end encryption, the phone is the
/// only place it can be done). Orientation is applied first, so nothing
/// comes out sideways.
Uint8List preparePhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('not an image');
  var image = img.bakeOrientation(decoded);
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > _maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: _maxSide)
        : img.copyResize(image, height: _maxSide);
  }
  // The encoder writes back whatever metadata the image carries: drop it.
  image.exif = img.ExifData();
  return Uint8List.fromList(img.encodeJpg(image, quality: 80));
}

/// Asks for a photo (camera or library), prepares it off the UI thread and
/// adds it sealed to [groups]. Returns its id, or null if none was picked.
Future<String?> pickPhoto(
  BuildContext context,
  WidgetRef ref, {
  required List<String> groups,
}) async {
  final l10n = context.l10n;
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.takePhoto),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.choosePhoto),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  final picked = await ImagePicker().pickImage(
    source: source,
    // A first, cheap cut by the platform; ours below is the one that counts.
    maxWidth: 2400,
    maxHeight: 2400,
  );
  if (picked == null) return null;
  final jpeg = await compute(preparePhoto, await picked.readAsBytes());
  final store = await ref.read(familyStoreProvider.future);
  return store.addPhoto(jpeg, groups: groups);
}

final _photoBytes = FutureProvider.family<Uint8List?, String>((ref, id) async {
  final store = await ref.watch(familyStoreProvider.future);
  return store.photo(id);
});

/// A photo by id, decrypted on this phone; a quiet placeholder while it
/// comes, or where this device may not see it.
class EncryptedPhoto extends ConsumerWidget {
  const EncryptedPhoto(this.id, {super.key, this.size = 96});

  final String id;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(_photoBytes(id)).value;
    final scheme = Theme.of(context).colorScheme;
    final child = bytes == null
        ? Container(
            color: scheme.surfaceContainerHighest,
            child: Icon(Icons.image_outlined, color: scheme.onSurfaceVariant),
          )
        : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    return GestureDetector(
      onTap: bytes == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  body: InteractiveViewer(
                    child: Center(child: Image.memory(bytes)),
                  ),
                ),
              ),
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(dimension: size, child: child),
      ),
    );
  }
}

/// Photos on something, with a button to add one. [onChanged] gets the new
/// list of ids to store on the owner.
class PhotoStrip extends ConsumerWidget {
  const PhotoStrip({
    super.key,
    required this.ids,
    required this.groups,
    required this.onChanged,
    this.mayEdit = true,
  });

  final List<String> ids;
  final List<String> groups;
  final ValueChanged<List<String>> onChanged;
  final bool mayEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final id in ids)
          GestureDetector(
            onLongPress: !mayEdit
                ? null
                : () => showModalBottomSheet<void>(
                    context: context,
                    builder: (context) => ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: Text(l10n.removePhoto),
                      onTap: () {
                        Navigator.pop(context);
                        onChanged([
                          for (final x in ids)
                            if (x != id) x,
                        ]);
                      },
                    ),
                  ),
            child: EncryptedPhoto(id),
          ),
        if (mayEdit)
          SizedBox.square(
            dimension: 96,
            child: OutlinedButton(
              onPressed: () async {
                final id = await pickPhoto(context, ref, groups: groups);
                if (id != null) onChanged([...ids, id]);
              },
              child: const Icon(Icons.add_a_photo_outlined),
            ),
          ),
      ],
    );
  }
}
