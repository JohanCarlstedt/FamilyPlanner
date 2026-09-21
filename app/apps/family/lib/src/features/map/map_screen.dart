import 'dart:async';

import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../chat/chat_providers.dart';
import '../../common/l10n.dart';
import '../../common/member_style.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../location/location_providers.dart';
import '../../membership/membership.dart';
import 'osm_map.dart';

/// Whether this build has a Google Maps key (gitignored, per platform).
/// Without one the Maps SDK stops the app dead the moment a map is built,
/// so Google's map is only drawn when the answer is yes; OpenStreetMap's
/// tiles are what the screen falls back to, and they need no key at all.
final mapsKeyProvider = FutureProvider<bool>((ref) async {
  try {
    return await const MethodChannel('family/maps')
            .invokeMethod<bool>('hasKey') ??
        false;
  } on Object {
    return false;
  }
});

/// Spec §7, the family map: latest positions only, each with its age, and
/// everyone on it able to see who sees them.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  static const segment = 'map';

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  Timer? _poll;
  GoogleMapController? _map;
  final _osm = OsmCamera();

  /// Whose dot the map is following, or null for everyone.
  String? _focus;

  Future<void> _lookAt(Iterable<GeoPoint> points) async {
    final map = _map;
    if (map == null) {
      // No Google key: OpenStreetMap is the map on screen.
      _osm.lookAt(points);
      return;
    }
    if (points.isEmpty) return;
    if (points.length == 1) {
      final only = points.first;
      await map.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(only.lat, only.lng), 15),
      );
      return;
    }
    final lats = [for (final p in points) p.lat];
    final lngs = [for (final p in points) p.lng];
    await map.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            lats.reduce((a, b) => a < b ? a : b),
            lngs.reduce((a, b) => a < b ? a : b),
          ),
          northeast: LatLng(
            lats.reduce((a, b) => a > b ? a : b),
            lngs.reduce((a, b) => a > b ? a : b),
          ),
        ),
        64,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Positions aren't pushed (they'd wake every phone every two minutes):
    // they're fetched while someone looks.
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _osm.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      await ref.read(locationReporterProvider).reportNow();
      await syncChat(ref.read);
      if (mounted) setState(() {});
    } catch (_) {
      // Offline: the next tick tries again.
    }
  }

  Future<void> _saveShare(LocationShare share) async {
    final store = await ref.read(familyStoreProvider.future);
    await store.saveLocationShare(share);
    ref.read(syncControllerProvider.notifier).syncNow();
    unawaited(ref.read(locationReporterProvider).reportNow());
  }

  Future<void> _checkIn(bool pickUp, String? where) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final chat = await ref.read(familyChatProvider.future);
      final text = pickUp ? l10n.checkInPickUp : l10n.checkInHere;
      await chat.send(where == null ? text : '$text · $where');
      messenger.showSnackBar(SnackBar(content: Text(l10n.checkInSent)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.sendFailed)));
    }
  }

  /// The map when the build has a key: Google's own tiles, which see roughly
  /// the area viewed (the privacy note on the screen says so).
  Widget _googleMap(
    BuildContext context, {
    required List<(Member, GeoPoint)> dots,
    required List<(Member, GeoPoint)> shown,
    required List<Place> places,
    required Map<String, int> index,
    required String? meId,
    required String Function(Member) status,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(dots.first.$2.lat, dots.first.$2.lng),
        zoom: 14,
      ),
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      onMapCreated: (controller) {
        _map = controller;
        _lookAt([for (final (_, p) in shown) p]);
      },
      circles: {
        for (final p in places)
          Circle(
            circleId: CircleId(p.id),
            center: LatLng(p.location!.lat, p.location!.lng),
            radius: p.radiusMeters,
            fillColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            strokeColor: theme.colorScheme.primary,
            strokeWidth: 1,
          ),
      },
      markers: {
        for (final (m, p) in shown)
          Marker(
            markerId: MarkerId(m.id),
            position: LatLng(p.lat, p.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _hueFor(MemberStyle.colorOf(m, index[m.id]!)),
            ),
            infoWindow: InfoWindow(
              title: m.id == meId ? l10n.you : m.displayName,
              snippet: status(m),
            ),
            onTap: () => setState(() => _focus = m.id),
          ),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final shares = ref.watch(locationSharesProvider).value ?? const {};
    final positions = ref.watch(positionsProvider).value ?? const {};
    final places = ref.watch(placesProvider).value ?? const <Place>[];
    final settings =
        ref.watch(settingsProvider).value ?? FamilySettings.defaults;
    final meId = ref.watch(membershipProvider).value?.memberId;
    final hasMapKey = ref.watch(mapsKeyProvider).value ?? false;
    final byId = {for (final m in members) m.id: m};
    final index = {for (final (i, m) in members.indexed) m.id: i};
    final placeById = {for (final p in places) p.id: p};
    final me = byId[meId];
    final now = DateTime.now().toUtc();
    final time = DateFormat('HH:mm');
    final day = DateFormat.MMMd(l10n.localeName);

    String clock(DateTime at) {
      final local = at.toLocal();
      return DateUtils.isSameDay(local, DateTime.now())
          ? time.format(local)
          : '${day.format(local)} ${time.format(local)}';
    }

    String names(Iterable<String> ids) =>
        [for (final id in ids) byId[id]?.displayName ?? l10n.someone]
            .join(', ');

    final people = [
      for (final m in members)
        if (m.isActive && m.role != MemberRole.helper && !m.isCoParent) m,
    ];

    String status(Member m) {
      final share = shares[m.id] ?? LocationShare(memberId: m.id);
      final message = positions[m.id];
      if (effectiveMode(m, share, settings) == ShareMode.off) {
        return message?.state == PositionState.off
            ? l10n.stoppedSharing
            : l10n.notSharing;
      }
      return switch (message) {
        null => l10n.noPositionYet,
        PositionMessage(state: PositionState.off) => l10n.stoppedSharing,
        PositionMessage(state: PositionState.paused, :final pausedUntil) =>
          pausedUntil == null
              ? l10n.sharingPaused
              : l10n.pausedUntil(clock(pausedUntil)),
        PositionMessage(:final position?) => [
          if (placeById[position.placeId] case final place?)
            l10n.atPlaceSince(place.name, clock(position.since))
          else if (position.point == null)
            l10n.notAtAPlace
          else if ((position.accuracyMeters ?? 0) >= 1000)
            l10n.roughlyHere,
          isFresh(position.capturedAt, now)
              ? l10n.seenNow
              : l10n.seenAt(clock(position.capturedAt)),
          if (position.battery case final b?) '🔋 $b %',
        ].join(' · '),
        _ => l10n.noPositionYet,
      };
    }

    final dots = [
      for (final m in people)
        if (positions[m.id] case PositionMessage(
          state: PositionState.sharing,
          position: SharedPosition(point: final point?),
        ))
          (m, point),
    ];
    // One person followed, or the whole family at once.
    final shown = [
      for (final d in dots)
        if (_focus == null || d.$1.id == _focus) d,
    ];
    final spots = [
      for (final p in places)
        if (p.location != null) p,
    ];
    final myShare = me == null
        ? null
        : shares[me.id] ?? LocationShare(memberId: me.id);
    final mySharing =
        me != null && effectiveMode(me, myShare!, settings) != ShareMode.off;
    final myPlace = positions[meId]?.position?.placeId;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.familyMap)),
      body: ListView(
        children: [
          if (dots.isNotEmpty) ...[
            SizedBox(
              height: 300,
              child: hasMapKey
                  ? _googleMap(
                      context,
                      dots: dots,
                      shown: shown,
                      places: spots,
                      index: index,
                      meId: meId,
                      status: status,
                    )
                  : OsmMap(
                      camera: _osm,
                      dots: shown,
                      places: spots,
                      colorOf: (m) => MemberStyle.colorOf(m, index[m.id]!),
                      onTap: (m) => setState(() => _focus = m.id),
                    ),
            ),
            // Everyone at once, or one person followed on their own.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text(l10n.mapEveryone),
                      selected: _focus == null,
                      onSelected: (_) {
                        setState(() => _focus = null);
                        _lookAt([for (final (_, p) in dots) p]);
                      },
                    ),
                    for (final (m, p) in dots)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          avatar: CircleAvatar(
                            backgroundColor: MemberStyle.colorOf(
                              m,
                              index[m.id]!,
                            ),
                            foregroundColor: Colors.white,
                            child: Text(m.displayName.characters.first),
                          ),
                          label: Text(m.id == meId ? l10n.you : m.displayName),
                          selected: _focus == m.id,
                          onSelected: (_) {
                            setState(() => _focus = m.id);
                            _lookAt([p]);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],

          for (final m in people)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: MemberStyle.colorOf(m, index[m.id]!),
                foregroundColor: Colors.white,
                child: Text(m.displayName.characters.first),
              ),
              title: Text(m.id == meId ? l10n.you : m.displayName),
              subtitle: Text(status(m)),
              selected: _focus == m.id,
              onTap: switch (positions[m.id]?.position?.point) {
                final point? => () {
                  setState(() => _focus = m.id);
                  _lookAt([point]);
                },
                null => null,
              },
              trailing: me != null && maySetFloor(me, m, settings)
                  ? _FloorButton(
                      share: shares[m.id] ?? LocationShare(memberId: m.id),
                      onChanged: _saveShare,
                    )
                  : null,
            ),
          if (me != null && myShare != null) ...[
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l10n.yourSharing, style: theme.textTheme.titleMedium),
            ),
            _MySharing(
              me: me,
              share: myShare,
              settings: settings,
              viewers: names(
                viewersOf(me, myShare, members, settings: settings),
              ),
              onChanged: _saveShare,
            ),
            if (mySharing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          _checkIn(false, placeById[myPlace]?.name),
                      icon: const Icon(Icons.where_to_vote_outlined),
                      label: Text(l10n.checkInHere),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _checkIn(true, placeById[myPlace]?.name),
                      icon: const Icon(Icons.directions_car_outlined),
                      label: Text(l10n.checkInPickUp),
                    ),
                  ],
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              // Whichever provider is drawing the tiles is the one that
              // sees the area, so the note names that one.
              '${l10n.mapPrivacy} '
              '${hasMapKey ? l10n.mapTilesGoogle : l10n.mapTilesOsm}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Google's markers take a hue, not a colour.
double _hueFor(Color color) =>
    HSVColor.fromColor(color).hue.clamp(0, 359.9).toDouble();

/// This member's own choices: on or off, who, how precisely, a pause.
class _MySharing extends StatelessWidget {
  const _MySharing({
    required this.me,
    required this.share,
    required this.settings,
    required this.viewers,
    required this.onChanged,
  });

  final Member me;
  final LocationShare share;
  final FamilySettings settings;
  final String viewers;
  final ValueChanged<LocationShare> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final on = effectiveMode(me, share, settings) != ShareMode.off;
    // A parent's floor: on, and not the child's to turn off or pause.
    final floored = on && !mayPause(me, share, settings);
    final now = DateTime.now().toUtc();
    final paused = share.isPaused(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: Text(l10n.shareWhileUsing),
          subtitle: Text(
            floored
                ? l10n.parentAskedToShare
                : on
                ? (viewers.isEmpty
                      ? l10n.nobodySeesYou
                      : l10n.whoSeesYou(viewers))
                : l10n.shareWhileUsingHelp,
          ),
          value: on,
          onChanged: floored
              ? null
              : (v) async {
                  if (v && !await askForLocation()) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.locationDenied)),
                      );
                    }
                    return;
                  }
                  onChanged(
                    share.copyWith(
                      mode: v ? ShareMode.whileUsing : ShareMode.off,
                    ),
                  );
                },
        ),
        if (on) ...[
          // Never silent: whether this is on, and whose decision it was,
          // is on the screen of the person it follows — including a child
          // who cannot turn it off (sharingNotice, domain).
          Builder(
            builder: (context) {
              final notice = sharingNotice(me, share, settings);
              final imposed = notice.imposed && notice.mode.isBackground;
              return SwitchListTile(
                title: Text(l10n.shareAlways),
                subtitle: Text(
                  imposed
                      ? l10n.shareAlwaysParentSet
                      : notice.mode.isBackground
                      ? l10n.shareAlwaysOn
                      : l10n.shareAlwaysHelp,
                ),
                value: notice.mode.isBackground,
                onChanged: notice.mayChange
                    ? (v) async {
                        if (v && !await askForAlwaysLocation()) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.shareAlwaysDenied),
                              ),
                            );
                          }
                          return;
                        }
                        onChanged(
                          share.copyWith(
                            mode: v
                                ? ShareMode.always
                                : ShareMode.whileUsing,
                          ),
                        );
                      }
                    : null,
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: SegmentedButton<ShareAudience>(
              segments: [
                ButtonSegment(
                  value: ShareAudience.parents,
                  label: Text(l10n.shareWithParents),
                ),
                ButtonSegment(
                  value: ShareAudience.family,
                  label: Text(l10n.shareWithFamily),
                ),
              ],
              selected: {share.audience},
              onSelectionChanged: (s) =>
                  onChanged(share.copyWith(audience: s.single)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: SegmentedButton<SharePrecision>(
              segments: [
                ButtonSegment(
                  value: SharePrecision.exact,
                  label: Text(l10n.precisionExact),
                ),
                ButtonSegment(
                  value: SharePrecision.approximate,
                  label: Text(l10n.precisionApproximate),
                ),
                ButtonSegment(
                  value: SharePrecision.placeOnly,
                  label: Text(l10n.precisionPlace),
                ),
              ],
              selected: {share.precision},
              onSelectionChanged: (s) =>
                  onChanged(share.copyWith(precision: s.single)),
            ),
          ),
          if (mayPause(me, share, settings))
            ListTile(
              leading: Icon(
                paused ? Icons.play_arrow_outlined : Icons.pause_outlined,
              ),
              title: Text(paused ? l10n.resumeSharing : l10n.pauseHour),
              subtitle: Text(l10n.pauseVisible),
              onTap: () => onChanged(
                share.copyWith(
                  pausedUntil: () =>
                      paused ? null : now.add(const Duration(hours: 1)),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// A parent asks a supervised child to share while using the app (spec §7
/// `minimum_mode`); the child's map says so.
class _FloorButton extends StatelessWidget {
  const _FloorButton({required this.share, required this.onChanged});

  final LocationShare share;
  final ValueChanged<LocationShare> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final asked = share.floor == ShareMode.whileUsing;
    return IconButton(
      tooltip: asked ? l10n.stopAskingToShare : l10n.askToShare,
      isSelected: asked,
      icon: const Icon(Icons.location_off_outlined),
      selectedIcon: const Icon(Icons.location_on),
      onPressed: () => onChanged(
        share.copyWith(floor: () => asked ? null : ShareMode.whileUsing),
      ),
    );
  }
}
