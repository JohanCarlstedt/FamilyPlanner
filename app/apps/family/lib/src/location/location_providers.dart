import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../chat/chat_providers.dart';
import '../data/family_repository.dart';
import '../data/store_providers.dart';
import '../membership/membership.dart';

/// Everyone's sharing choices, by member (spec §7).
final locationSharesProvider = StreamProvider<Map<String, LocationShare>>((
  ref,
) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchLocationShares();
});

/// The latest word from everyone this device may see, by member: a
/// position, a pause or "stopped". Nothing older is kept anywhere.
final positionsProvider = StreamProvider<Map<String, PositionMessage>>((
  ref,
) async* {
  final chat = await ref.watch(familyChatProvider.future);
  final members = await ref.watch(membersProvider.future);
  final me = ref.watch(membershipProvider).value?.memberId;
  final groups = {for (final m in members) chat.locationGroup(m.id): m.id};
  yield* chat.watchPositions().map(
    (rows) => {
      for (final MapEntry(key: group, value: (_, payload)) in rows.entries)
        if (groups[group] case final member?
            when member == me || chat.seesLocationOf(member))
          member: ?PositionMessage.decode(payload),
    },
  );
});

/// Shares this device's member's position while the app is in use (spec §7
/// `while_using`): at start, on coming back, and every two minutes. It asks
/// for no permission itself; turning sharing on does.
final locationReporterProvider = Provider<LocationReporter>((ref) {
  final reporter = LocationReporter(ref);
  ref.onDispose(reporter.dispose);
  return reporter..start();
});

class LocationReporter with WidgetsBindingObserver {
  LocationReporter(this._ref);

  final Ref _ref;
  Timer? _timer;
  var _running = false;

  static const interval = Duration(minutes: 2);

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(interval, (_) => reportNow());
    unawaited(reportNow());
  }

  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(reportNow());
  }

  /// Sends what this member's choice says now: a position, a pause, or,
  /// once, that they stopped, before taking the viewers out.
  Future<void> reportNow() async {
    if (_running) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    _running = true;
    try {
      await _report();
    } catch (e) {
      debugPrint('Location not shared: $e');
    } finally {
      _running = false;
    }
  }

  Future<void> _report() async {
    final read = _ref.read;
    final membership = await read(membershipProvider.future);
    if (membership == null) return;
    final members = await read(membersProvider.future);
    final me = members.where((m) => m.id == membership.memberId).firstOrNull;
    if (me == null) return;
    final settings = await read(settingsProvider.future);
    final share =
        (await read(locationSharesProvider.future))[me.id] ??
        LocationShare(memberId: me.id);
    final chat = await read(familyChatProvider.future);
    final byMember = await chatDevicesByMember(read);
    final own = {...?byMember[me.id], membership.deviceId};
    final now = DateTime.now().toUtc();

    if (effectiveMode(me, share, settings) == ShareMode.off) {
      final readers = chat.readersOf(chat.locationGroup(me.id));
      if (readers.difference(own).isEmpty) return;
      // Say so to those who could see, then take them out: their map shows
      // "stopped sharing", never a stale dot passed off as now.
      await chat.sharePosition(
        me.id,
        const PositionMessage(state: PositionState.off).encode().encode(),
        viewers: readers,
      );
      await chat.reconcileLocation(me.id, own);
      return;
    }

    final viewers = {
      ...own,
      ...devicesOf(byMember, viewersOf(me, share, members, settings: settings)),
    };
    if (share.isPaused(now) && mayPause(me, share, settings)) {
      await chat.sharePosition(
        me.id,
        PositionMessage(
          state: PositionState.paused,
          pausedUntil: share.pausedUntil,
        ).encode().encode(),
        viewers: viewers,
      );
      return;
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    final fix = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    final previous = (await read(positionsProvider.future))[me.id]?.position;
    int? battery;
    try {
      battery = await Battery().batteryLevel;
    } catch (_) {
      // Not every device says.
    }
    final position = reducePosition(
      at: GeoPoint(fix.latitude, fix.longitude),
      accuracyMeters: fix.accuracy,
      capturedAt: fix.timestamp.toUtc(),
      precision: share.precision,
      places: await read(placesProvider.future),
      previous: previous,
      battery: battery,
    );
    await chat.sharePosition(
      me.id,
      PositionMessage(
        state: PositionState.sharing,
        position: position,
      ).encode().encode(),
      viewers: viewers,
    );
  }
}

/// Asks for location permission when someone turns sharing on. Returns
/// whether it was given.
Future<bool> askForLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) return false;
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  return permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;
}

/// Where this phone is now, for setting a place's spot.
Future<GeoPoint?> whereAmI() async {
  if (!await askForLocation()) return null;
  final fix = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 20),
    ),
  );
  return GeoPoint(fix.latitude, fix.longitude);
}
