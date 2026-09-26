import 'package:domain/domain.dart';

import '../../common/l10n.dart';
import 'trade_sheet.dart';

/// Names and symbols for what is in a city, in the words a child reads.

String serviceEmoji(Service s) => switch (s) {
  Service.power => '⚡',
  Service.water => '💧',
  Service.fire => '🚒',
  Service.clinic => '🏥',
  Service.bus => '🚌',
};

String serviceName(AppLocalizations l10n, Service s) => switch (s) {
  Service.power => l10n.servicePower,
  Service.water => l10n.serviceWater,
  Service.fire => l10n.serviceFire,
  Service.clinic => l10n.serviceClinic,
  Service.bus => l10n.serviceBus,
};

String serviceWhy(AppLocalizations l10n, Service s) => switch (s) {
  Service.power => l10n.serviceWhyPower,
  Service.water => l10n.serviceWhyWater,
  Service.fire => l10n.serviceWhyFire,
  Service.clinic => l10n.serviceWhyClinic,
  Service.bus => l10n.serviceWhyBus,
};

/// "5 coins" or "6 coins + 2 goods".
String serviceCostText(AppLocalizations l10n, Service s) =>
    switch (serviceGoods[s]) {
      final goods? => l10n.serviceCostGoods(serviceCosts[s]!, goods),
      null => l10n.serviceCost(serviceCosts[s]!),
    };

String happeningEmoji(Happening h) => switch (h) {
  Happening.marketDay => '🛍️',
  Happening.festival => '🎪',
  Happening.touristBus => '📸',
  Happening.balloonRace => '🎈',
  Happening.whale => '🐋',
  Happening.meteorShower => '🌠',
};

String happeningName(AppLocalizations l10n, Happening h) => switch (h) {
  Happening.marketDay => l10n.happeningMarketDay,
  Happening.festival => l10n.happeningFestival,
  Happening.touristBus => l10n.happeningTouristBus,
  Happening.balloonRace => l10n.happeningBalloonRace,
  Happening.whale => l10n.happeningWhale,
  Happening.meteorShower => l10n.happeningMeteorShower,
};

String happeningBody(AppLocalizations l10n, Happening h) => switch (h) {
  Happening.marketDay => l10n.happeningMarketDayBody,
  Happening.festival => l10n.happeningFestivalBody,
  Happening.touristBus => l10n.happeningTouristBusBody,
  Happening.balloonRace ||
  Happening.whale ||
  Happening.meteorShower => l10n.happeningSeenBody,
};

String requestText(AppLocalizations l10n, CityRequest r) => switch (r.kind) {
  RequestKind.parkNear => l10n.requestParkNear(r.who),
  RequestKind.shopNear => l10n.requestShopNear(r.who),
  RequestKind.home => l10n.requestHome(r.who),
  RequestKind.service => l10n.requestService(
    r.who,
    serviceName(l10n, r.service ?? Service.power),
  ),
};

String civicName(AppLocalizations l10n, Civic c) => switch (c) {
  Civic.hall => l10n.civicHall,
  Civic.school => l10n.civicSchool,
  Civic.library => l10n.civicLibrary,
  Civic.observatory => l10n.civicObservatory,
  Civic.university => l10n.civicUniversity,
  Civic.fountain => l10n.civicFountain,
};

String civicEmoji(Civic c) => switch (c) {
  Civic.hall => '🏛️',
  Civic.school => '🏫',
  Civic.library => '📚',
  Civic.observatory => '🔭',
  Civic.university => '🎓',
  Civic.fountain => '⛲',
};

String projectName(AppLocalizations l10n, FamilyProject p) => switch (p) {
  FamilyProject.statue => l10n.projectStatue,
  FamilyProject.clockTower => l10n.projectClockTower,
  FamilyProject.ferrisWheel => l10n.projectFerrisWheel,
};

String projectEmoji(FamilyProject p) => switch (p) {
  FamilyProject.statue => '🗽',
  FamilyProject.clockTower => '🕰️',
  FamilyProject.ferrisWheel => '🎡',
};

/// What a saving goal (`landmark:castle`, `service:fire`) names.
(Landmark?, Service?) goalOf(String? goal) {
  final parts = (goal ?? '').split(':');
  if (parts.length != 2) return (null, null);
  return switch (parts[0]) {
    'landmark' => (Landmark.values.asNameMap()[parts[1]], null),
    'service' => (null, Service.values.asNameMap()[parts[1]]),
    _ => (null, null),
  };
}

/// A thing in the book: its symbol, its name, and the picture to show
/// for it if there is one.
({String emoji, String name, String? sprite}) collectibleOf(
  AppLocalizations l10n,
  Collectible c,
) {
  final [kind, name] = c.contains(':') ? c.split(':') : [c, ''];
  final size = int.tryParse(name);
  return switch (kind) {
    'home' => (
      emoji: '🏠',
      name: [
        l10n.sizeCottage,
        l10n.sizeHouse,
        l10n.sizeApartments,
        l10n.sizeTower,
      ][size!],
      sprite: 'home${size}_0',
    ),
    'park' => (
      emoji: '🌳',
      name: [
        l10n.sizeLawn,
        l10n.sizeTrees,
        l10n.sizePond,
        l10n.sizeBigPark,
      ][size!],
      sprite: 'park${size}_0',
    ),
    'shop' => (
      emoji: '🏪',
      name: [l10n.sizeKiosk, l10n.sizeShop, l10n.sizeStore][size!],
      sprite: 'shop${size}_0',
    ),
    'market' => (emoji: '🏛️', name: l10n.cityMarket, sprite: 'market'),
    'civic' => switch (Civic.values.asNameMap()[name]) {
      final civic? => (
        emoji: civicEmoji(civic),
        name: civicName(l10n, civic),
        sprite: civic == Civic.fountain ? null : 'civic_${civic.name}',
      ),
      null => (emoji: '❔', name: name, sprite: null),
    },
    'service' => switch (Service.values.asNameMap()[name]) {
      final s? => (emoji: serviceEmoji(s), name: serviceName(l10n, s), sprite: null),
      null => (emoji: '❔', name: name, sprite: null),
    },
    'landmark' => switch (Landmark.values.asNameMap()[name]) {
      final l? => (
        emoji: landmarkEmoji(l),
        name: landmarkName(l10n, l),
        sprite: switch (l) {
          Landmark.castle => 'landmark_castle',
          Landmark.bakery => 'landmark_bakery',
          _ => null,
        },
      ),
      null => (emoji: '❔', name: name, sprite: null),
    },
    'happening' => switch (Happening.values.asNameMap()[name]) {
      final h? => (
        emoji: happeningEmoji(h),
        name: happeningName(l10n, h),
        sprite: null,
      ),
      null => (emoji: '❔', name: name, sprite: null),
    },
    'project' => switch (FamilyProject.values.asNameMap()[name]) {
      final p? => (emoji: projectEmoji(p), name: projectName(l10n, p), sprite: null),
      null => (emoji: '❔', name: name, sprite: null),
    },
    _ => (emoji: '❔', name: c, sprite: null),
  };
}

/// One line for a thing to look forward to.
String nextUpText(AppLocalizations l10n, NextUp up) => switch (up) {
  GrowsSoon(zone: Zone.park, :final left) => l10n.nextParkGrows(left),
  GrowsSoon(:final left) => l10n.nextHomeGrows(left),
  WaitsFor(:final zone, :final missing) => switch (zone) {
    Zone.shop => l10n.nextWaitsShop,
    Zone.park => l10n.nextWaitsPark,
    _ => l10n.nextWaitsHome,
  }(missing.map((s) => '${serviceEmoji(s)} ${serviceName(l10n, s)}').join(', ')),
  NextLevel(:final level, :final left) => l10n.nextLevel(left, level),
  NextLearning(:final building, :final left) => l10n.nextLearning(
    left,
    civicName(l10n, building),
  ),
};

String nextUpEmoji(NextUp up) => switch (up) {
  GrowsSoon(zone: Zone.park) => '🌳',
  GrowsSoon() => '🏠',
  WaitsFor(:final missing) => missing.map(serviceEmoji).join(),
  NextLevel() => '🗺️',
  NextLearning(:final building) => civicEmoji(building),
};
