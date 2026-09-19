import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../membership/membership.dart';

/// How far the founder got through setup. Kept beside the device secret so a
/// restart mid-setup comes back to it: spec §9 step 7 doesn't let setup
/// finish until the recovery words are confirmed.
enum SetupProgress {
  /// Nothing pending: a finished setup, a device that joined, or an install
  /// from before setup was tracked.
  none,
  started,

  /// The usual week is written; don't write it twice.
  seeded;

  bool get pending => this != none;
}

final setupProgressProvider =
    AsyncNotifierProvider<SetupProgressNotifier, SetupProgress>(
      SetupProgressNotifier.new,
    );

class SetupProgressNotifier extends AsyncNotifier<SetupProgress> {
  static const _key = 'setup_progress.v1';

  @override
  Future<SetupProgress> build() async {
    final bytes = await ref.read(secretStoreProvider).read(_key);
    if (bytes == null) return SetupProgress.none;
    return SetupProgress.values.asNameMap()[utf8.decode(bytes)] ??
        SetupProgress.none;
  }

  Future<void> set(SetupProgress progress) async {
    final store = ref.read(secretStoreProvider);
    if (progress == SetupProgress.none) {
      await store.delete(_key);
    } else {
      await store.write(_key, Uint8List.fromList(utf8.encode(progress.name)));
    }
    state = AsyncData(progress);
  }
}
