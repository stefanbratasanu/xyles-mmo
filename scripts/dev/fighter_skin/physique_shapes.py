"""Build the 5 x 5 body grid on one topology and one unchanged skeleton.

Each selectable combination has one target. This avoids adding two independently
sculpted endpoint deltas, which previously exaggerated limb loss and kept the
source's carved abdomen on otherwise soft bodies. Units are Blender metres.
"""
import numpy as np


def ramp(a, b, value):
    t = np.clip((value - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def bell(value, center, width):
    return np.exp(-((value - center) / width) ** 2)


def build(body, armature):
    coords = np.array([v.co[:] for v in body.data.vertices], dtype=np.float64)
    unique, inverse = np.unique(np.round(coords, 6), axis=0, return_inverse=True)
    edges = np.array([(inverse[e.vertices[0]], inverse[e.vertices[1]])
                      for e in body.data.edges], dtype=np.int32)
    edges = edges[edges[:, 0] != edges[:, 1]]
    edges = np.unique(np.vstack((edges, edges[:, ::-1])), axis=0)
    degree = np.maximum(np.bincount(edges[:, 0], minlength=len(unique)), 1)
    multiplicity = np.bincount(inverse, minlength=len(unique))

    def compact(values):
        return np.column_stack([
            np.bincount(inverse, weights=values[:, axis], minlength=len(unique))
            / multiplicity for axis in range(3)])

    def average(values):
        return np.column_stack([
            np.bincount(edges[:, 0], weights=values[edges[:, 1], axis],
                        minlength=len(unique)) / degree for axis in range(3)])

    def fair(values, iterations, mask):
        """Taubin smoothing removes bumps while retaining cross-section volume."""
        values = compact(values)
        mask = compact(np.repeat(mask[:, None], 3, axis=1))
        for _ in range(iterations):
            values += 0.45 * (average(values) - values) * mask
            values -= 0.47 * (average(values) - values) * mask
        return values[inverse]

    weights = np.zeros((len(coords), len(body.vertex_groups)), dtype=np.float64)
    group_names = {g.name: g.index for g in body.vertex_groups}
    for v in body.data.vertices:
        for group in v.groups:
            weights[v.index, group.group] = group.weight

    # The auto-rig lets both thighs influence the abdomen well above the hip
    # joint. A larger belly amplifies that leg motion into irregular creases.
    # Fade those influences into Hips across the lower abdomen, retaining the
    # original thigh/shorts bindings below the pelvis and all hand/finger weights.
    axial = sum(weights[:, group_names[n]] for n in ('Hips', 'Spine', 'Spine1', 'Spine2'))
    transfer = (ramp(.15, .245, coords[:, 2])
                * (1 - ramp(.12, .21, np.abs(coords[:, 0]))) * ramp(.45, .8, axial))
    moved = np.zeros(len(coords))
    for name in ('LeftUpLeg', 'RightUpLeg', 'LeftLeg', 'RightLeg'):
        if name not in group_names:
            continue
        index = group_names[name]
        amount = weights[:, index] * transfer
        moved += amount
        weights[:, index] -= amount
        for vertex in np.flatnonzero(amount > 1e-7):
            body.vertex_groups[index].add([int(vertex)], float(weights[vertex, index]), 'REPLACE')
    hip = group_names['Hips']
    weights[:, hip] += moved
    for vertex in np.flatnonzero(moved > 1e-7):
        body.vertex_groups[hip].add([int(vertex)], float(weights[vertex, hip]), 'REPLACE')
    print('TORSO SKIN: removed thigh bleed from', int(np.sum(moved > 1e-5)), 'vertices', flush=True)

    def group(name):
        return weights[:, group_names[name]] if name in group_names else np.zeros(len(coords))

    torso = sum(group(n) for n in ('Hips', 'Spine', 'Spine1', 'Spine2', 'Neck',
                                  'LeftShoulder', 'RightShoulder'))
    torso = np.clip(torso, 0, 1)
    x, y, z = coords.T
    trunk = torso
    fixed_neck = 1.0 - ramp(0.54, 0.63, z)
    fixed_feet = ramp(-0.88, -0.74, z)
    body_mask = fixed_neck * fixed_feet
    limb_fields = {name: np.zeros_like(coords) for name in
                   ('upper_arm', 'forearm', 'thigh', 'calf')}
    for bone in armature.data.bones:
        name = bone.name
        if name.endswith('ForeArm'):
            part = 'forearm'
        elif name.endswith('Arm'):
            part = 'upper_arm'
        elif name.endswith('UpLeg'):
            part = 'thigh'
        elif name.endswith('Leg'):
            part = 'calf'
        else:
            continue
        a = np.array(bone.head_local[:])
        segment = np.array(bone.tail_local[:]) - a
        t = np.clip((coords - a) @ segment / (segment @ segment), 0, 1)
        radial = coords - (a + t[:, None] * segment)
        taper = 0.45 + 0.55 * np.sin(np.pi * t)
        limb_fields[part] += radial * (group(name) * taper)[:, None]

    # Relax source sculpt grooves, then explicitly reshape the front of the
    # torso. Smoothing displacement alone leaves those grooves in every target.
    relaxed = fair(coords, 100, body_mask)
    torso_soft = (ramp(0.25, 0.85, trunk)
                  * ramp(0.035, 0.14, z) * (1 - ramp(0.52, 0.605, z)))
    section_z = [.05, .12, .2, .3, .4, .49, .55, .6]
    section_x = [.19, .18, .166, .158, .178, .202, .217, .17]
    section_depth = [.132, .132, .127, .131, .137, .14, .125, .075]
    rx = np.interp(z, section_z, section_x)
    ry = np.interp(z, section_z, section_depth)
    angle = np.arctan2((y - .025) / ry, x / rx)
    envelope = np.column_stack((rx * np.cos(angle), .025 + ry * np.sin(angle), z))
    soft = relaxed.copy()
    soft += (envelope - soft) * torso_soft[:, None]
    # Reduce biceps, quadriceps and calf sculpting as well as abdominal detail.
    # Circular sections follow the limb's own axis, with small joint radii and
    # unchanged hands/feet. Volume is then controlled by the size axis below.
    for bone in armature.data.bones:
        name = bone.name
        if name.endswith('ForeArm'):
            radii = [.047, .056, .043, .031]
        elif name.endswith('Arm'):
            radii = [.076, .073, .059, .043]
        elif name.endswith('UpLeg'):
            radii = [.109, .103, .084, .067]
        elif name.endswith('Leg'):
            radii = [.060, .071, .057, .037]
        else:
            continue
        a = np.array(bone.head_local[:])
        segment = np.array(bone.tail_local[:]) - a
        t = np.clip((coords - a) @ segment / (segment @ segment), 0, 1)
        axis = a + t[:, None] * segment
        radial = coords - axis
        length = np.maximum(np.linalg.norm(radial, axis=1), 1e-6)
        radius = np.interp(t, [0, .3, .7, 1], radii)
        target = axis + radial * (radius / length)[:, None]
        weight = group(name) * (.45 + .4 * np.sin(np.pi * t)) * body_mask
        soft += (target - soft) * weight[:, None]
    soft_delta = (soft - coords) * body_mask[:, None]

    body.shape_key_add(name='Basis')
    for size in range(5):
        for muscle in range(5):
            if (size, muscle) == (2, 3):
                continue
            fat = max(0, (size - 2) / 2)
            lean = max(0, (2 - size) / 2)
            low_muscle = max(0, (3 - muscle) / 3)
            high_muscle = max(0, muscle - 3)
            # Fat covers surface definition while muscle volume can still vary.
            softness = max(low_muscle, fat * .96)
            points = coords + soft_delta * softness
            px, py, _ = points.T
            chest = bell(z, .49, .15)
            waist = bell(z, .245, .23)
            front = 1 - ramp(-.015, .06, y)
            delta = np.zeros_like(points)
            # Concentrate added width around the abdomen while tapering into
            # the original hips, shoulders, wrists and ankles.
            width = -.20 * lean - .065 * low_muscle * chest + .10 * high_muscle * chest
            delta[:, 0] = px * width * trunk
            delta[:, 1] = (-(py - .025) * .20 * lean
                           + (py - .025) * .12 * high_muscle * chest) * trunk
            # Fat uses a continuous spatial cage, not discontinuous skin
            # weights. Its X field is independent of Y, and its front Y field
            # moves increasingly outward toward the front, keeping neighboring
            # surface points in order instead of projecting them onto a shell.
            fat_width = (.085 * fat * bell(z, .25, .25) * np.sign(x)
                         * ramp(0, .12, np.abs(x)) * (1 - ramp(.20, .42, np.abs(x))))
            delta[:, 0] += fat_width
            fat_depth = (.13 * fat * bell(z, .23, .24) * ramp(-.02, .10, z)
                         * (1 - ramp(.50, .62, z)))
            fat_central = 1 - ramp(.12, .32, np.abs(x))
            delta[:, 1] += (-fat_depth * front + .018 * fat * waist * (1 - front)) * fat_central
            factors = {
                'upper_arm': -.10 * lean - .035 * low_muscle + .50 * fat + .16 * high_muscle,
                'forearm': -.07 * lean - .025 * low_muscle + .25 * fat + .08 * high_muscle,
                'thigh': -.08 * lean - .025 * low_muscle + .45 * fat + .13 * high_muscle,
                'calf': -.06 * lean - .015 * low_muscle + .24 * fat + .07 * high_muscle,
            }
            for part, factor in factors.items():
                delta += limb_fields[part] * factor
            points += delta * body_mask[:, None]
            points = fair(points, 18, body_mask * .8)
            # Restrain the central lower back while smoothly relaxing the
            # sculpt. The size control adds most of its depth to the abdomen.
            back_mask = (ramp(.045, .060, y) * (1 - ramp(.104, .16, np.abs(x)))
                         * ramp(.10, .13, z) * (1 - ramp(.34, .40, z)))
            back_delta = points[:, 1] - coords[:, 1]
            bounded_back = coords[:, 1] + .032 * np.tanh(back_delta / .032)
            points[:, 1] += (bounded_back - points[:, 1]) * back_mask
            # Copy preserved regions exactly, including all UV split duplicates.
            points[body_mask == 0] = coords[body_mask == 0]
            key = body.shape_key_add(name=f'Physique_{size}_{muscle}')
            key.data.foreach_set('co', points.astype(np.float32).ravel())
            print(f'PHYSIQUE {size}/{muscle}: ready', flush=True)
