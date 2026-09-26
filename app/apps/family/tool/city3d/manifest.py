"""Writes manifest.json: which of Kenney's CC0 models make which picture.

    python3 manifest.py > manifest.json

Names are what the app asks for (lib/src/features/rewards/city_sprites.dart):
home<size>_<variant>, shop<size>_<variant>, park<stage>_<variant>,
civic_<building>, landmark_<which>, market, tree_<variant>,
road_<mask> and car_<model>_<heading>.

Directions, measured rather than guessed (see render.py): a model's +X is
the city's +x (screen right-down) and its +Y the city's -y (north). A
road mask is N=1 E=2 S=4 W=8 in city terms; turning a model 90 degrees
takes an opening E->N, N->W, W->S, S->E.
"""
import json

SUB = 'kenney_city-kit-suburban_20/Models/GLB format/'
COM = 'kenney_city-kit-commercial_2.1/Models/GLB format/'
ROAD = 'kenney_city-kit-roads/Models/GLB format/'
NAT = 'kenney_nature-kit/Models/GLTF format/'
CAS = 'kenney_castle-kit/Models/GLB format/'
CAR = 'kenney_car-kit/Models/GLB format/'

m = {}


def one(name, model, **extra):
    m[name] = {'parts': [{'model': model}], **extra}


def scene(name, parts, **extra):
    m[name] = {'parts': parts, **extra}


def p(model, x=0.0, y=0.0, z=0.0, turn=0, scale=None):
    part = {'model': model, 'at': [x, y, z], 'turn': turn}
    if scale is not None:
        part['scale'] = scale
    return part


# Homes by size: cottage, house, apartments, tower.
for i, b in enumerate('aghim'):
    one(f'home0_{i}', SUB + f'building-type-{b}.glb')
for i, b in enumerate('ceklor'):
    one(f'home1_{i}', SUB + f'building-type-{b}.glb')
for i, b in enumerate('abdhc'):
    one(f'home2_{i}', COM + f'building-{b}.glb')
for i, b in enumerate(['skyscraper-a', 'skyscraper-b', 'skyscraper-c',
                       'skyscraper-d', 'skyscraper-e', 'm']):
    one(f'home3_{i}', COM + f'building-{b}.glb')

# Shops grow with the homes round them.
one('shop0_0', COM + 'building-e.glb')
one('shop1_0', COM + 'building-k.glb')
one('shop2_0', COM + 'building-j.glb')

# The town's own buildings.
one('civic_hall', COM + 'building-n.glb', fit=0.95)
one('civic_school', SUB + 'building-type-n.glb')
one('civic_library', COM + 'building-g.glb')
one('civic_university', COM + 'building-l.glb', fit=0.95)
scene('civic_observatory', [
    p(CAS + 'tower-hexagon-base.glb'),
    p(CAS + 'tower-hexagon-roof.glb', z=1.31),
], fit=0.7)

# The trading house: a market of parasols round a planter.
scene('market', [
    p(COM + 'detail-parasol-a.glb', x=-0.22, y=0.18),
    p(COM + 'detail-parasol-b.glb', x=0.22, y=0.18),
    p(COM + 'detail-parasol-a.glb', x=0.0, y=-0.22),
    p(SUB + 'planter.glb', x=0.3, y=-0.3),
], fit=1.0, unit=1.0)

# Special buildings the kits can make.
scene('landmark_castle', [
    p(CAS + 'tower-square.glb', x=-1.0),
    p(CAS + 'gate.glb', x=0.0, turn=90),
    p(CAS + 'tower-square.glb', x=1.0),
    p(CAS + 'flag.glb', x=-1.0, z=1.31),
    p(CAS + 'flag.glb', x=1.0, z=1.31),
], fit=0.95)
one('landmark_bakery', COM + 'building-h.glb')

# Parks by stage, each laid out on a one-unit square (the app paints the
# lawn under them).
scene('park0_0', [p(NAT + 'tree_small.glb', 0.15, -0.1),
                  p(NAT + 'flower_redA.glb', -0.3, 0.25),
                  p(NAT + 'flower_yellowB.glb', -0.1, 0.32)], fit=1.0, unit=1.0)
scene('park0_1', [p(NAT + 'plant_bushSmall.glb', 0.2, 0.1),
                  p(NAT + 'flower_purpleA.glb', -0.25, -0.2),
                  p(NAT + 'flower_redB.glb', -0.3, 0.25)], fit=1.0, unit=1.0)
scene('park1_0', [p(NAT + 'tree_oak.glb', -0.2, 0.15),
                  p(NAT + 'tree_small.glb', 0.25, -0.2),
                  p(NAT + 'plant_bush.glb', 0.25, 0.3)], fit=1.0, unit=1.0)
scene('park1_1', [p(NAT + 'tree_pineRoundA.glb', 0.2, 0.2),
                  p(NAT + 'tree_small.glb', -0.25, -0.2),
                  p(NAT + 'stump_round.glb', -0.3, 0.3)], fit=1.0, unit=1.0)
scene('park2_0', [p(NAT + 'path_stoneCircle.glb', scale=0.8),
                  p(NAT + 'tree_default.glb', -0.3, 0.3),
                  p(NAT + 'flower_yellowA.glb', 0.3, -0.3),
                  p(NAT + 'flower_redA.glb', 0.35, 0.3)], fit=1.0, unit=1.0)
scene('park2_1', [
    p(NAT + f'flower_{c}.glb', x, y)
    for c, x, y in [('redA', -0.3, -0.3), ('yellowA', -0.1, -0.3),
                    ('purpleA', 0.1, -0.3), ('redB', -0.3, -0.05),
                    ('yellowB', -0.1, -0.05), ('purpleB', 0.1, -0.05)]
] + [p(NAT + 'tree_small.glb', 0.3, 0.25), p(NAT + 'plant_bush.glb', -0.25, 0.3)],
    fit=1.0, unit=1.0)
scene('park2_2', [p(NAT + 'tent_smallOpen.glb', 0.15, 0.1),
                  p(NAT + 'tree_fat.glb', -0.3, -0.25),
                  p(NAT + 'campfire_stones.glb', -0.2, 0.3)], fit=1.0, unit=1.0)
scene('park3_0', [p(NAT + 'path_stoneCircle.glb'),
                  p(NAT + 'statue_obelisk.glb'),
                  p(NAT + 'tree_default.glb', -0.35, 0.35),
                  p(NAT + 'tree_oak.glb', 0.35, 0.35),
                  p(NAT + 'flower_redA.glb', 0.35, -0.35),
                  p(NAT + 'flower_yellowA.glb', -0.35, -0.35)], fit=1.0, unit=1.0)
scene('park3_1', [p(NAT + 'path_stoneCircle.glb'),
                  p(NAT + 'statue_column.glb'),
                  p(NAT + 'tree_pineRoundA.glb', 0.35, 0.35),
                  p(NAT + 'plant_bushLarge.glb', -0.35, 0.3),
                  p(NAT + 'flower_purpleA.glb', 0.35, -0.35)], fit=1.0, unit=1.0)

# The nature kit is built bigger than the city kits (its trees stand
# 1.2-1.7 units against a house's 1): shrunk in park scenes to the town's
# scale.
_shrink = {'tree': 0.55, 'statue': 0.6, 'tent': 0.6, 'plant_bushLarge': 0.7,
           'campfire': 0.7}
for _name, _entry in m.items():
    if not _name.startswith('park'):
        continue
    for _part in _entry['parts']:
        _model = _part['model'].rsplit('/', 1)[-1]
        for _prefix, _k in _shrink.items():
            if _model.startswith(_prefix) and 'scale' not in _part:
                _part['scale'] = _k

# Trees on open ground, summer and autumn.
for name, model in [('tree_0', 'tree_default'), ('tree_1', 'tree_oak'),
                    ('tree_2', 'tree_fat'), ('tree_3', 'tree_pineRoundA'),
                    ('tree_4', 'tree_small'), ('tree_5', 'tree_pineTallA'),
                    ('treefall_0', 'tree_default_fall'),
                    ('treefall_1', 'tree_oak_fall'),
                    ('treefall_2', 'tree_fat_fall')]:
    one(name, NAT + model + '.glb', fit=0.5)

# Roads: every combination of neighbours, from the five pieces.
pieces = {  # the piece's openings with no turn, as a mask
    'road-straight': 2 | 8,
    'road-end': 2,
    'road-bend': 8 | 4,
    'road-intersection': 2 | 8 | 4,
    'road-crossroad': 15,
}


def turn_once(mask):
    out = 0
    if mask & 2: out |= 1   # E -> N
    if mask & 1: out |= 8   # N -> W
    if mask & 8: out |= 4   # W -> S
    if mask & 4: out |= 2   # S -> E
    return out


for piece, base in pieces.items():
    mask = base
    for quarter in range(4):
        name = f'road_{mask}'
        if name not in m:
            m[name] = {'parts': [p(ROAD + piece + '.glb', turn=90 * quarter)],
                       'flat': True}
        mask = turn_once(mask)
m['road_0'] = {'parts': [p(ROAD + 'road-square.glb')], 'flat': True}

# Cars, one picture per heading along the streets.
for model in ['sedan', 'taxi', 'van', 'police', 'suv', 'delivery']:
    for heading, turn in [('s', 0), ('e', 90), ('n', 180), ('w', 270)]:
        m[f'car_{model}_{heading}'] = {
            'parts': [p(CAR + model + '.glb', turn=turn)], 'fit': 0.32}

print(json.dumps(m, indent=1))
