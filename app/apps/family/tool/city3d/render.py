"""Renders Kenney's CC0 3D city kits into the city's isometric pictures.

    blender -b --python render.py -- <manifest.json> <kits dir> <out dir> [names...]

Each entry in the manifest names a model (kit/file.glb, or several to
compose on one plot) and is rendered from the city's own angle: an
orthographic camera 30 degrees down and turned 45, which is what makes a
square plot the 2:1 diamond the app draws. The model is scaled to fit one
plot, stood on its middle, lit by a sun with a soft ground shadow, on a
transparent background. Every picture is PLOT_PX wide for one plot, and
out/sprites.json records where the plot's centre is in it, so the app can
stand it exactly where a plot is.

The kits themselves are not in the repository (docs/city-graphics.md):
download them from kenney.nl, CC0.
"""
import bpy, sys, os, json, math
from mathutils import Vector, Euler

args = sys.argv[sys.argv.index('--') + 1:]
# --night renders the evening versions, name@night: moonlight, and the
# windows lit.
NIGHT = '--night' in args
args = [a for a in args if a != '--night']
manifest_path, kits_dir, out_dir = args[0], args[1], args[2]
only = set(args[3:])

PLOT_PX = 256                       # a plot's width in the picture
UNIT_PX = PLOT_PX / math.sqrt(2)    # one grid unit, in pixels
RISE = math.cos(math.radians(30))   # a unit of height, seen from 30 degrees up
FIT = 0.9                           # of a plot a model may cover
MARGIN = 24                         # room for shadows and edges

with open(manifest_path) as f:
    manifest = json.load(f)
os.makedirs(out_dir, exist_ok=True)
index_path = os.path.join(out_dir, 'sprites.json')
index = json.load(open(index_path)) if os.path.exists(index_path) else {}


def scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = 'CYCLES'
    s.cycles.device = 'GPU'
    prefs = bpy.context.preferences.addons['cycles'].preferences
    prefs.compute_device_type = 'METAL'
    prefs.get_devices()
    for d in prefs.devices:
        d.use = True
    s.cycles.samples = 48
    s.cycles.use_denoising = True
    s.render.film_transparent = True
    s.view_settings.view_transform = 'Standard'
    # WebP keeps transparency at a fraction of PNG's size, and Flutter
    # decodes it natively on both platforms.
    s.render.image_settings.file_format = 'WEBP'
    s.render.image_settings.color_mode = 'RGBA'
    s.render.image_settings.quality = 88
    world = bpy.data.worlds.new('w')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs[0].default_value = (
        (0.10, 0.13, 0.28, 1) if NIGHT else (0.82, 0.86, 0.95, 1))
    world.node_tree.nodes['Background'].inputs[1].default_value = 0.45 if NIGHT else 0.9
    s.world = world
    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    sun.data.energy = 0.35 if NIGHT else 3.2
    if NIGHT:
        sun.data.color = (0.65, 0.72, 1.0)
    sun.data.angle = math.radians(8)
    sun.rotation_euler = Euler((math.radians(50), math.radians(10), math.radians(-20)))
    s.collection.objects.link(sun)
    return s


def box(part):
    """A plain coloured block standing on the ground at its 'at': what the
    kits have no model for (a crane's mast and jib, a building's concrete
    frame) is built from these. One marked 'glow' is a warning light,
    lit after dark."""
    sx, sy, sz = part['box']
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.active_object
    o.scale = (sx, sy, sz)
    o.location = (0, 0, sz / 2)
    bpy.ops.object.transform_apply(location=True, scale=True)
    mat = bpy.data.materials.new('box')
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes['Principled BSDF']
    # Colours are given as they look (sRGB); Blender wants linear.
    linear = [c ** 2.2 for c in part.get('colour', (0.8, 0.8, 0.8))]
    bsdf.inputs['Base Color'].default_value = (*linear, 1)
    bsdf.inputs['Roughness'].default_value = 0.75
    if part.get('glow') and NIGHT:
        bsdf.inputs['Emission Color'].default_value = (*linear, 1)
        bsdf.inputs['Emission Strength'].default_value = 6.0
    o.data.materials.append(mat)


def load(parts):
    """Imports the parts, each at its own offset, and returns the meshes."""
    meshes = []
    for part in parts:
        before = set(bpy.context.scene.objects)
        if 'box' in part:
            box(part)
        else:
            bpy.ops.import_scene.gltf(
                filepath=os.path.join(kits_dir, part['model']))
        new = [o for o in bpy.context.scene.objects if o not in before]
        roots = [o for o in new if o.parent is None]
        # One handle for the whole part: a model made of several roots (a
        # truck and its wheels) moves, turns and scales as one, about its
        # own origin, instead of coming apart.
        handle = bpy.data.objects.new('part', None)
        bpy.context.scene.collection.objects.link(handle)
        for r in roots:
            r.parent = handle
        handle.location = Vector(part.get('at', (0, 0, 0)))
        # glTF imports keep rotation as a quaternion, which ignores the
        # Euler angles: the handle is an Euler from the start.
        handle.rotation_mode = 'XYZ'
        handle.rotation_euler.z = math.radians(part.get('turn', 0))
        if 'scale' in part:
            handle.scale = (part['scale'],) * 3
        meshes += [o for o in new if o.type == 'MESH']
    bpy.context.view_layer.update()
    return meshes


def light_windows():
    """The kits colour everything from one palette image, and windows are
    its blues: the only swatches where blue clearly beats both red and
    green. At night those glow warm; nothing else does."""
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        nt = mat.node_tree
        bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
        if bsdf is None or not bsdf.inputs['Base Color'].is_linked:
            continue
        colour = bsdf.inputs['Base Color'].links[0].from_socket
        split = nt.nodes.new('ShaderNodeSeparateColor')
        nt.links.new(colour, split.inputs['Color'])

        def math(op, a, b):
            node = nt.nodes.new('ShaderNodeMath')
            node.operation = op
            for i, v in enumerate((a, b)):
                if isinstance(v, float):
                    node.inputs[i].default_value = v
                else:
                    nt.links.new(v, node.inputs[i])
            return node.outputs[0]

        blue_red = math('SUBTRACT', split.outputs['Blue'], split.outputs['Red'])
        blue_green = math('SUBTRACT', split.outputs['Blue'], split.outputs['Green'])
        green_red = math('SUBTRACT', split.outputs['Green'], split.outputs['Red'])
        mask = math('MULTIPLY',
                    math('MULTIPLY',
                         math('GREATER_THAN', blue_red, 0.18),
                         math('GREATER_THAN', blue_green, 0.04)),
                    math('GREATER_THAN', green_red, 0.0))
        bsdf.inputs['Emission Color'].default_value = (1.0, 0.78, 0.42, 1)
        nt.links.new(math('MULTIPLY', mask, 2.4), bsdf.inputs['Emission Strength'])


def bounds(meshes):
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def render(name, entry):
    s = scene()
    meshes = load(entry['parts'])
    # Roads have no windows, and their pavement is the same pale blue as
    # glass: lit, every street had a glowing outline.
    if NIGHT and not entry.get('flat'):
        light_windows()
    lo, hi = bounds(meshes)
    # Fit to a plot, stand on the ground, centre on the plot.
    size = max(hi.x - lo.x, hi.y - lo.y)
    if entry.get('flat'):
        k = 1 / max(size, 1e-6)
    elif 'unit' in entry:
        # A scene laid out on a square of this side: its scale is the
        # layout's, not whatever its parts happen to reach.
        k = entry.get('fit', FIT) / entry['unit']
    else:
        k = entry.get('fit', FIT) / size
    holder = bpy.data.objects.new('holder', None)
    s.collection.objects.link(holder)
    for o in s.objects:
        if o.parent is None and o not in (holder,) and o.type != 'LIGHT':
            o.parent = holder
    centre = (lo + hi) / 2
    holder.location = Vector((-centre.x * k, -centre.y * k, -lo.z * k))
    holder.scale = (k, k, k)
    bpy.context.view_layer.update()
    lo, hi = bounds(meshes)
    height = hi.z

    # A ground under it to catch its shadow, and nothing else.
    bpy.ops.mesh.primitive_plane_add(size=6)
    ground = bpy.context.active_object
    ground.is_shadow_catcher = True

    width_px = PLOT_PX + 2 * MARGIN
    height_px = int(math.ceil((PLOT_PX / 2 + height * RISE * UNIT_PX + 2 * MARGIN) / 8) * 8)
    s.render.resolution_x = width_px
    s.render.resolution_y = height_px
    # Where the plot's centre falls: half a plot and the margin up from the
    # bottom of the picture.
    anchor = (width_px / 2, height_px - MARGIN - PLOT_PX / 4)

    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = max(width_px, height_px) / UNIT_PX
    rot = Euler((math.radians(60), 0, math.radians(45)))
    cam.rotation_euler = rot
    # Aim so that the plot's centre lands on the anchor: it sits this far
    # below the picture's middle, which a point that high up the vertical
    # axis cancels.
    below = (height_px / 2 - (height_px - anchor[1])) / UNIT_PX
    target = Vector((0, 0, below / RISE))
    forward = rot.to_matrix() @ Vector((0, 0, -1))
    cam.location = target - forward * 40
    s.collection.objects.link(cam)
    s.camera = cam

    # The shadow catcher leaves a faint haze across the whole picture,
    # which shows as a pale rectangle round each building on the grass:
    # only real shadow is kept.
    s.use_nodes = True
    tree = s.node_tree
    for n in list(tree.nodes):
        tree.nodes.remove(n)
    layers = tree.nodes.new('CompositorNodeRLayers')
    ramp = tree.nodes.new('CompositorNodeMapRange')
    ramp.inputs['From Min'].default_value = 0.06
    ramp.inputs['From Max'].default_value = 1.0
    ramp.inputs['To Min'].default_value = 0.0
    ramp.inputs['To Max'].default_value = 1.0
    ramp.use_clamp = True
    alpha = tree.nodes.new('CompositorNodeSetAlpha')
    alpha.mode = 'REPLACE_ALPHA'
    out = tree.nodes.new('CompositorNodeComposite')
    tree.links.new(layers.outputs['Image'], alpha.inputs['Image'])
    tree.links.new(layers.outputs['Alpha'], ramp.inputs['Value'])
    tree.links.new(ramp.outputs['Value'], alpha.inputs['Alpha'])
    tree.links.new(alpha.outputs['Image'], out.inputs['Image'])

    if NIGHT:
        name = name + '@night'
    s.render.filepath = os.path.join(out_dir, name + '.webp')
    bpy.ops.render.render(write_still=True)
    index[name] = {
        'file': name + '.webp',
        'width': width_px,
        'height': height_px,
        'anchorX': anchor[0],
        'anchorY': anchor[1],
        'plotPx': PLOT_PX,
    }
    print(f'RENDERED {name} {width_px}x{height_px} height={height:.2f}')


for name, entry in manifest.items():
    if only and name not in only:
        continue
    render(name, entry)
with open(index_path, 'w') as f:
    json.dump(index, f, indent=1, sort_keys=True)
