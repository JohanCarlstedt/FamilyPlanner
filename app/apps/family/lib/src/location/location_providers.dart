import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:battery_plus/battery_plus.dart';
import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../common/l10n.dart';
import '../chat/chat_providers.dart';
import '../data/family_repository.dart';
import '../data/store_providers.dart';
import '../membership/membership.dart';
import 'report_pacer.dart';

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

/// Shares this device's member's position, as their choice says (spec §7).
///
/// `whileUsing` reports at start, on coming back, and every two minutes —
/// a timer, which is all that is needed while the app is on screen.
/// `always` also follows a position stream the operating system drives,
/// because a timer stops the moment the app is suspended and that is
/// exactly when background sharing has to work.
///
/// It asks for no permission itself; choosing to share does.
final locationReporterProvider = Provider<LocationReporter>((ref) {
  final reporter = LocationReporter(ref);
  ref.onDispose(reporter.dispose);
  return reporter..start();
});

class LocationReporter with WidgetsBindingObserver {
  LocationReporter(this._ref);

  final Ref _ref;
  Timer? _timer;
  StreamSubscription<Position>? _background;
  var _running = false;
  final _pacer = ReportPacer();

  /// Who may see, remembered for a while: it was fetched from the server
  /// on every report, a round trip on every wake for a list that changes
  /// when someone pairs a phone.
  ChatDevices? _devices;
  DateTime? _devicesAt;
  static const _devicesFor = Duration(minutes: 10);

  static const interval = Duration(minutes: 2);

  /// How far someone has to move before the background stream wakes us.
  ///
  /// A timer cannot do this job: the operating system suspends the app,
  /// and with it any timer. Only a position stream the OS itself drives
  /// keeps running — and only if it is asked to wake for movement rather
  /// than for the clock, which is also what keeps the battery alive. A
  /// hundred metres is far enough not to fire while someone sits still
  /// and near enough to notice them leaving.
  static const backgroundMeters = 150;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(interval, (_) => reportNow());
    unawaited(reportNow());
  }

  void dispose() {
    _timer?.cancel();
    unawaited(_background?.cancel());
    _background = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(reportNow());
  }

  /// Sends what this member's choice says now: a position, a pause, or,
  /// once, that they stopped, before taking the viewers out.
  ///
  /// [fromBackground] is a report the operating system woke us for. The
  /// app is not on screen then, which is the whole point, so the usual
  /// refusal to report from the background does not apply to it.
  ///
  /// [fix] is the position the phone woke us with. Used as it is: asking
  /// for a fresh one on top kept the GPS on for up to twenty seconds on
  /// every wake, which was most of what background sharing cost.
  Future<void> reportNow({bool fromBackground = false, Position? fix}) async {
    if (_running) return;
    if (!fromBackground) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    } else if (!_pacer.take(DateTime.now())) {
      return;
    }
    _running = true;
    try {
      await _report(fix: fix);
    } catch (e) {
      debugPrint('Location not shared: $e');
    } finally {
      _running = false;
    }
  }

  /// Starts or stops the background stream to match what this member has
  /// chosen, or what a parent set for them. Called from every report, so
  /// a change of mind takes effect without anything else having to know.
  Future<void> _followInBackground(bool wanted) async {
    if (wanted == (_background != null)) return;

    if (!wanted) {
      await _background?.cancel();
      _background = null;
      debugPrint('Background sharing stopped');
      return;
    }

    // Only with the permission that actually allows it. Asked for on the
    // screen where the choice is made, never here: a permission prompt
    // arriving out of nowhere is how people learn to refuse them.
    if (await Geolocator.checkPermission() != LocationPermission.always) {
      debugPrint('Background sharing wanted, but not permitted');
      return;
    }

    _background =
        Geolocator.getPositionStream(locationSettings: _backgroundSettings())
            .listen(
              (p) => unawaited(reportNow(fromBackground: true, fix: p)),
              onError: (Object e) =>
                  debugPrint('Background stream stopped: $e'),
            );
    debugPrint('Background sharing started');
  }

  LocationSettings _backgroundSettings() {
    if (Platform.isAndroid) {
      // In the language of the phone it sits on. This notification is a
      // promise made to the person being followed — often a child — and a
      // promise they cannot read is not one.
      final l10n = lookupAppLocalizations(
        resolveAppLocale(PlatformDispatcher.instance.locale, appLocales),
      );
      return AndroidSettings(
        // Balanced power: Wi-Fi and cell towers first, GPS only when they
        // cannot say. About a hundred metres, which is the distance the
        // stream wakes for anyway; exact again as soon as the app is open.
        accuracy: LocationAccuracy.medium,
        distanceFilter: backgroundMeters,
        // At most once a minute, kept by the system rather than the app.
        intervalDuration: const Duration(minutes: 1),
        // The notification is not a cost to be worked around: it is the
        // promise that this is never silent, kept by the operating system
        // rather than by us remembering to.
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'Family Planner',
          notificationText: l10n.sharingOngoing,
          enableWakeLock: false,
        ),
      );
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        // A hundred metres: iOS answers from Wi-Fi and cell towers and
        // keeps the GPS off most of the time.
        accuracy: LocationAccuracy.medium,
        distanceFilter: backgroundMeters,
        activityType: ActivityType.other,
        allowBackgroundLocationUpdates: true,
        // The blue indicator stays up. Same reason as the notification.
        showBackgroundLocationIndicator: true,
        pauseLocationUpdatesAutomatically: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: backgroundMeters,
    );
  }

  Future<ChatDevices> _chatDevices(ChatReader read) async {
    final now = DateTime.now();
    final at = _devicesAt;
    if (_devices case final known?
        when at != null && now.difference(at) < _devicesFor) {
      return known;
    }
    final fresh = await chatDevices(read);
    _devices = fresh;
    _devicesAt = now;
    return fresh;
  }

  Future<void> _report({Position? fix}) async {
    final read = _ref.read;
    final membership = await read(membershipProvider.future);
    // A wall tablet stands in the kitchen and belongs to nobody in
    // particular: it never reports where its member is.
    if (membership == null || membership.isKitchen) return;
    final members = await read(membersProvider.future);
    final me = members.where((m) => m.id == membership.memberId).firstOrNull;
    if (me == null) return;
    final settings = await read(settingsProvider.future);
    final share =
        (await read(locationSharesProvider.future))[me.id] ??
        LocationShare(memberId: me.id);
    final chat = await read(familyChatProvider.future);
    final devices = await _chatDevices(read);
    final own = {...?devices.byMember[me.id], membership.deviceId};
    final now = DateTime.now().toUtc();

    final mode = effectiveMode(me, share, settings);
    // Matched on every report, so turning it on or off — or a parent
    // setting a floor from another phone — takes hold on the next pass
    // without anything here having to be told separately.
    await _followInBackground(
      mode.isBackground &&
          !(share.isPaused(now) && mayPause(me, share, settings)),
    );

    if (mode == ShareMode.off) {
      final readers = chat.readersOf(chat.locationGroup(me.id));
      if (readers.difference(own).isEmpty) return;
      // Say so to those who could see, then take them out: their map shows
      // "stopped sharing", never a stale dot passed off as now.
      await chat.sharePosition(
        me.id,
        const PositionMessage(state: PositionState.off).encode().encode(),
        viewers: readers,
      );
      await chat.reconcileLocation(
        me.id,
        own,
        remove: devices.outside({me.id}),
      );
      return;
    }

    final watching = {
      me.id,
      ...viewersOf(me, share, members, settings: settings),
    };
    final viewers = {...own, ...devices.of(watching)};
    final notViewers = devices.outside(watching);
    if (share.isPaused(now) && mayPause(me, share, settings)) {
      await chat.sharePosition(
        me.id,
        PositionMessage(
          state: PositionState.paused,
          pausedUntil: share.pausedUntil,
        ).encode().encode(),
        viewers: viewers,
        remove: notViewers,
      );
      return;
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    final reading =
        fix ??
        await Geolocator.getCurrentPosition(
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
      at: GeoPoint(reading.latitude, reading.longitude),
      accuracyMeters: reading.accuracy,
      capturedAt: reading.timestamp.toUtc(),
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
      remove: notViewers,
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

/// Asks for the permission that keeps working when the app is closed.
///
/// Both platforms insist on the ordinary permission first and will not
/// consider "always" until they have it — iOS shows its own second prompt,
/// sometimes days later, and Android sends the person to Settings. So this
/// asks twice and reports what it actually got, rather than assuming the
/// second ask succeeded.
///
/// False here is not a failure to handle quietly: the person chose
/// background sharing and did not get it, and the screen has to say so, or
/// they will believe they are sharing when they are not.
Future<bool> askForAlwaysLocation() async {
  if (!await askForLocation()) return false;
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.whileInUse) {
    permission = await Geolocator.requestPermission();
  }
  return permission == LocationPermission.always;
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
