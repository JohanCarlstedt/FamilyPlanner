# The city's pictures

The children's cities (spec section 3, "Contributions") are drawn from
pictures rendered once from free 3D models, with the old hand-drawn shapes
as the fallback for anything that has no picture yet.

## Nothing about a city is a picture

A child's city is stored as what they built, where and when; how big each
thing has grown is counted from what they have done. The pictures are only
how that is drawn now (`citySpriteName` in
`app/apps/family/lib/src/features/rewards/city_sprites.dart` picks one per
plot). So every city built before there were pictures looks like this at
once, nothing is converted, and changing or adding pictures later changes
no one's city.

## Where they come from

Kenney's 3D kits, **CC0 (public domain)**: free, commercial use allowed,
no attribution required (kenney.nl/support). Credit is still given here
and in the licence note below.

| Kit | Used for |
|---|---|
| City Kit (Suburban) | cottages, houses, the school |
| City Kit (Commercial) | apartments, towers, shops, hall, library, university, bakery, the market's parasols |
| City Kit (Roads) | every road shape |
| Nature Kit | parks, trees (summer and autumn), flowers |
| Castle Kit | the castle, the observatory |
| Car Kit | the traffic |

The kits are **not** in the repository. To render again, download them
from kenney.nl into one folder (e.g. `~/Tools/kenney`, each unzipped into
a folder named after its zip), install Blender 4.5 LTS (free,
blender.org), and run from `app/apps/family`:

```bash
python3 tool/city3d/manifest.py > tool/city3d/manifest.json
blender -b --python tool/city3d/render.py -- \
  tool/city3d/manifest.json ~/Tools/kenney assets/city [names…]
```

Naming only some pictures renders just those. About 15 seconds a picture
on an M2.

## How a picture is made

`render.py` imports a model (or several, composed, for parks and the
castle), scales it to fit one plot, stands it on the plot's middle, and
renders it with Cycles from the city's own angle: orthographic, 30° down,
turned 45°, which is what makes a square plot the 2:1 diamond the app
draws. A sun gives it a soft shadow on a shadow-catcher ground; the
background is transparent. Every picture is 256 px per plot, saved as
WebP, and `assets/city/sprites.json` records where the plot's centre falls
in it, so the app stands it exactly on its plot at any zoom.

Directions were measured, not guessed: a model's +X is the city's +x
(screen right-down), +Y is the city's −y (north). Road pieces' openings
were measured by ray-casting just inside each edge (road surface 0.01,
pavement 0.02). One trap: glTF imports keep rotation as a quaternion, so
setting Euler angles did nothing until the object's rotation mode was
switched.

## What is still drawn by hand

Water, the fountain, construction sites, and the zoo, stadium and harbour:
no kit has them. They keep their drawings until one does. People on the
pavements, birds, the balloon and the plane are drawn too.

## Licence

The models are by Kenney (www.kenney.nl), CC0 1.0
(creativecommons.org/publicdomain/zero/1.0). The rendered pictures in
`assets/city` are derived from them and carry no further restriction.
