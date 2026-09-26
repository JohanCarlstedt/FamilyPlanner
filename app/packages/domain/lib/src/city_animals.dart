import 'dart:math';

import 'city.dart';
import 'contributions.dart';

/// The zoo's animals, in the order they arrive. The first few are the
/// ones that make the news when they get out.
enum ZooAnimal { lion, elephant, giraffe, tiger, monkey, panda, polar, penguin }

/// A farm's animals, in the order they arrive.
enum FarmAnimal { cow, pig, chick, bunny, cow2, pig2 }

/// Things done after the zoo opened, for each new animal.
const zooEvery = 3;

/// Things done after a park became a farm, for each new animal.
const farmEvery = 4;

/// A farm's yard is full at this many.
const farmMax = 6;

/// How many animals live on the farm at [lot]: one from the day it became
/// a farm, and one more for every [farmEvery] things done after that
/// ([mine]: the child's own), up to [farmMax]. None on a park that is no
/// farm. Each one brings a coin as it arrives (`coinsOf`).
int farmAnimalsOf(CityLot lot, List<Contribution> mine) {
  if (lot.zone != Zone.park) return 0;
  final since = lot.upgrades
      .where((u) => u.path == UpgradePath.farm)
      .firstOrNull
      ?.at;
  if (since == null) return 0;
  final done = mine.where((c) => c.growsWorld && c.at.isAfter(since)).length;
  return min(farmMax, 1 + done ~/ farmEvery);
}
