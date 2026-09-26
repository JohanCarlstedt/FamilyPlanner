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
IND = 'kenney_city-kit-industrial_2.0/Models/GLB format/'

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

# Services: what keeps a growing town going.
scene('service_power', [
    p(IND + 'windmill.glb', x=-0.15, y=0.15),
    p(IND + 'solar-panel-landscape-group.glb', x=0.25, y=-0.25, scale=0.5),
], fit=0.9)
one('service_water', IND + 'water-tower.glb', fit=0.7)
scene('service_fire', [
    p(IND + 'building-j.glb', y=0.2),
    p(CAR + 'firetruck.glb', x=0.1, y=-0.45, turn=90, scale=0.3),
], fit=0.95)
scene('service_clinic', [
    p(IND + 'building-p.glb', y=0.15),
    p(CAR + 'ambulance.glb', x=0.25, y=-0.45, turn=90, scale=0.3),
], fit=0.95)
scene('service_bus', [
    p(COM + 'detail-overhang-wide.glb', z=0.35),
    p(ROAD + 'road-sign-street.glb', x=0.4, y=-0.25),
    p(SUB + 'planter.glb', x=-0.3, y=-0.3),
], fit=0.7)

# Construction sites: something being built today, which can still
# change. A few different ones, and tall enough to see across the town.
def box(sx, sy, sz, x=0.0, y=0.0, z=0.0, colour=(0.8, 0.8, 0.8), turn=0,
        glow=False):
    part = {'box': [sx, sy, sz], 'at': [x, y, z], 'turn': turn,
            'colour': list(colour)}
    if glow:
        part['glow'] = True
    return part


YELLOW = (0.96, 0.72, 0.16)
CONCRETE = (0.78, 0.77, 0.74)
STEEL = (0.35, 0.37, 0.4)
EARTH = (0.52, 0.38, 0.25)
RED_LIGHT = (1.0, 0.2, 0.15)


def crane(cx, cy, height=1.7, jib=1.1, turn=0):
    # A tower crane: a lattice mast, the cab, a jib out one way and a
    # counterweight the other, a load hanging from the hook.
    import math
    a = math.radians(turn)
    ca, sa = math.cos(a), math.sin(a)

    def at(dx, dy):
        return cx + dx * ca - dy * sa, cy + dx * sa + dy * ca

    parts = [box(0.24, 0.24, 0.05, cx, cy, colour=CONCRETE)]
    h = 0.05
    for dx in (-0.045, 0.045):
        for dy in (-0.045, 0.045):
            parts.append(box(0.02, 0.02, height, cx + dx, cy + dy, h,
                             colour=YELLOW))
    for level in range(1, int(height / 0.17)):
        z = h + level * 0.17
        parts.append(box(0.11, 0.012, 0.012, cx, cy - 0.045, z, colour=YELLOW))
        parts.append(box(0.012, 0.11, 0.012, cx + 0.045, cy, z, colour=YELLOW))
    top = h + height
    parts.append(box(0.13, 0.11, 0.1, cx, cy, top, colour=YELLOW))
    parts.append(box(0.03, 0.03, 0.28, cx, cy, top + 0.1, colour=YELLOW))
    x, y = at(-jib / 2 + 0.05, 0)
    parts.append(box(jib, 0.05, 0.05, x, y, top + 0.1, colour=YELLOW,
                     turn=turn))
    x, y = at(0.22, 0)
    parts.append(box(0.4, 0.05, 0.05, x, y, top + 0.1, colour=YELLOW,
                     turn=turn))
    x, y = at(0.36, 0)
    parts.append(box(0.12, 0.1, 0.12, x, y, top + 0.02, colour=STEEL,
                     turn=turn))
    tip = -jib + 0.12
    x, y = at(tip, 0)
    parts.append(box(0.01, 0.01, top + 0.1 - 0.55, x, y, 0.55, colour=STEEL))
    parts.append(box(0.18, 0.12, 0.05, x, y, 0.48, colour=EARTH, turn=turn))
    x, y = at(-jib + 0.07, 0)
    parts.append(box(0.03, 0.03, 0.03, x, y, top + 0.15, colour=RED_LIGHT,
                     glow=True))
    parts.append(box(0.03, 0.03, 0.03, cx, cy, top + 0.38, colour=RED_LIGHT,
                     glow=True))
    return parts


def frame(cx, cy, floors=2, w=0.5, d=0.45):
    # A building's concrete frame going up: columns, and a slab a floor.
    parts = []
    for i in range(3):
        for j in range(3):
            x = cx - w / 2 + i * w / 2
            y = cy - d / 2 + j * d / 2
            parts.append(box(0.035, 0.035, floors * 0.3, x, y,
                             colour=CONCRETE))
    for f in range(1, floors + 1):
        # The top floor only half poured.
        size = (w + 0.05) if f < floors else (w + 0.05) / 2
        off = 0 if f < floors else -(w + 0.05) / 4
        parts.append(box(size, d + 0.05, 0.03, cx + off, cy, f * 0.3 - 0.03,
                         colour=CONCRETE))
    return parts


scene('site_0', crane(0.3, 0.3) + frame(-0.1, -0.08, floors=2) + [
    p(ROAD + 'construction-barrier.glb', x=-0.05, y=-0.44, scale=0.8),
    p(ROAD + 'construction-cone.glb', x=0.38, y=-0.3, scale=0.8),
    p(ROAD + 'construction-cone.glb', x=0.44, y=-0.12, scale=0.8),
], fit=1.0, unit=1.0)
ORANGE = (0.95, 0.5, 0.15)


def piling_rig(cx, cy, height=1.2):
    # A piling rig: tracks, a cab, and a tall mast driving piles in.
    return [
        box(0.26, 0.2, 0.07, cx, cy, colour=STEEL),
        box(0.16, 0.16, 0.14, cx + 0.04, cy, 0.07, colour=ORANGE),
        box(0.07, 0.07, height, cx - 0.1, cy, 0.07, colour=ORANGE),
        box(0.1, 0.1, 0.06, cx - 0.1, cy, 0.07 + height, colour=STEEL),
        box(0.012, 0.012, height - 0.1, cx - 0.16, cy, 0.1, colour=STEEL),
        box(0.05, 0.05, 0.35, cx - 0.16, cy, 0.0, colour=CONCRETE),
        box(0.03, 0.03, 0.03, cx - 0.1, cy, 0.13 + height, colour=RED_LIGHT,
            glow=True),
    ]


scene('site_1', piling_rig(0.3, 0.25) + [
    p(IND + 'shipping-container-b.glb', x=-0.2, y=0.32, turn=90, scale=0.35),
    box(0.3, 0.26, 0.07, 0.1, 0.12, colour=EARTH),
    box(0.18, 0.14, 0.14, 0.12, 0.14, colour=EARTH),
    box(0.08, 0.07, 0.2, 0.14, 0.15, colour=EARTH),
    p(CAR + 'tractor-shovel.glb', x=-0.18, y=-0.08, turn=45, scale=0.15),
    p(ROAD + 'dumpster.glb', x=0.36, y=-0.22, scale=0.5),
    p(ROAD + 'construction-barrier.glb', x=-0.1, y=-0.44, scale=0.8),
    p(ROAD + 'construction-light.glb', x=0.42, y=0.38, scale=0.9),
    p(ROAD + 'construction-cone.glb', x=0.2, y=-0.42, scale=0.8),
], fit=1.0, unit=1.0)
scene('site_2', crane(-0.28, 0.3, height=1.4, jib=0.9, turn=180)
      + frame(0.12, 0.0, floors=1) + [
    p(CAR + 'truck.glb', x=0.15, y=-0.38, turn=90, scale=0.15),
    p(NAT + 'log_stack.glb', x=-0.3, y=-0.25, scale=0.4),
    p(CAR + 'box.glb', x=0.42, y=0.3, scale=0.2),
    p(ROAD + 'construction-light.glb', x=0.44, y=-0.1, scale=0.8),
], fit=1.0, unit=1.0)

# What the family builds together.
scene('project_statue', [
    p(NAT + 'path_stoneCircle.glb', scale=0.8),
    p(NAT + 'statue_head.glb', scale=0.6),
], fit=1.0, unit=1.0)
scene('project_clockTower', [
    p(CAS + 'tower-square-base.glb'),
    p(CAS + 'tower-square-mid-windows.glb', z=1.0),
    p(CAS + 'tower-square-top-roof-high.glb', z=2.0),
], fit=0.6)

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

# The police station keeps thieves away: a station, a patrol car, and a
# blue light on the roof that shows in the evening.
scene('service_police', [
    p(IND + 'building-h.glb', y=0.25),
    p(CAR + 'police.glb', x=0.35, y=-0.75, turn=90, scale=0.3),
    box(0.12, 0.12, 0.08, 0.35, -0.75, 0.42, colour=(0.2, 0.45, 1.0),
        glow=True),
], fit=0.95)

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
