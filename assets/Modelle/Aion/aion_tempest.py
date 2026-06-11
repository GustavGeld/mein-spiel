import bpy, bmesh, math
from mathutils import Vector

# ============================================================
# AION  —  TEMPEST SOVEREIGN  |  Roblox-safe FBX
# Sturmkugel im Zentrum eines kosmischen Wirbelsturms.
# 4 spiralförmige Sturmarm-Ketten, Blitz-Netzwerk,
# schwebende Trümmer-Brocken, Tornado-Auge-Wand.
# ============================================================

C_STORM   = (0.08, 0.10, 0.14, 1.0)  # Gewitterwolke Dunkelgrau
C_CLOUD2  = (0.15, 0.18, 0.22, 1.0)  # mittleres Wolkengrau
C_CLOUD3  = (0.28, 0.32, 0.38, 1.0)  # helles Grau
C_ELEC    = (0.25, 0.70, 1.00, 1.0)  # Elektrisches Blau
C_BOLT    = (0.88, 0.96, 1.00, 1.0)  # Blitz Weiß
C_CORE    = (0.10, 0.55, 0.95, 1.0)  # Sturmkern Blau
C_ORB     = (0.05, 0.08, 0.18, 1.0)  # Kugel Dunkelblau
C_DEBRIS  = (0.30, 0.25, 0.20, 1.0)  # Trümmer Stein-Braun
C_DEBRIS2 = (0.20, 0.18, 0.14, 1.0)  # dunkler Stein
C_RING    = (0.18, 0.42, 0.72, 1.0)  # Ringen-Blau
C_PLASMA  = (0.40, 0.18, 0.82, 1.0)  # Plasma-Lila

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for col in list(bpy.data.collections):
        bpy.data.collections.remove(col)

def vcol(obj, color):
    if obj.type != 'MESH': return
    mesh = obj.data
    if "Color" not in mesh.color_attributes:
        mesh.color_attributes.new(name="Color", type='FLOAT_COLOR', domain='CORNER')
    for d in mesh.color_attributes["Color"].data:
        d.color = color

def smooth(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth()

def cyl(name, s, e, r=0.04, v=8):
    sv, ev = Vector(s), Vector(e)
    vec = ev - sv
    bpy.ops.mesh.primitive_cylinder_add(
        radius=r, depth=vec.length, vertices=v, location=(sv+ev)*0.5)
    obj = bpy.context.active_object; obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = vec.to_track_quat('Z','Y')
    smooth(obj); return obj

def cone(name, s, e, r1=0.05, r2=0.0, v=6):
    sv, ev = Vector(s), Vector(e)
    vec = ev - sv
    bpy.ops.mesh.primitive_cone_add(
        radius1=r1, radius2=r2, depth=vec.length, vertices=v,
        location=(sv+ev)*0.5)
    obj = bpy.context.active_object; obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = vec.to_track_quat('Z','Y')
    smooth(obj); return obj


# ═══════════════════════════════════════════════════════════════
# STURMKUGEL
# ═══════════════════════════════════════════════════════════════
def create_orb():
    parts = []
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=64, ring_count=32, location=(0,0,0))
    orb = bpy.context.active_object; orb.name = "Aion_Orb"; smooth(orb); vcol(orb, C_ORB); parts.append(orb)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.65, segments=32, ring_count=16, location=(0,0,0))
    c1 = bpy.context.active_object; c1.name = "Storm_Core1"; smooth(c1); vcol(c1, (0.06,0.12,0.30,1.0)); parts.append(c1)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.35, subdivisions=2, location=(0,0,0))
    c2 = bpy.context.active_object; c2.name = "Storm_Core2"; smooth(c2); vcol(c2, C_CORE); parts.append(c2)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.15, segments=10, ring_count=6, location=(0,0,0))
    c3 = bpy.context.active_object; c3.name = "Storm_Eye"; smooth(c3); vcol(c3, C_BOLT); parts.append(c3)
    # Tornado-Auge-Wand: 4 konzentrische elektrische Ringe
    for i, (z, maj, col) in enumerate([
        (0.0,  1.01, C_ELEC),
        (0.0,  1.26, C_RING),
        (0.0,  1.52, C_STORM),
        (0.0,  1.76, C_STORM),
    ]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=maj, minor_radius=0.028-i*0.003,
            major_segments=72, minor_segments=10, location=(0,0,z))
        r = bpy.context.active_object; r.name = f"Storm_EyeWall_{i}"
        vcol(r, col); parts.append(r)
    # 12 Plasma-Energie-Funken auf dem inneren Auge-Wall
    for i in range(12):
        a = (i/12)*math.tau
        pos = (math.cos(a)*1.01, math.sin(a)*1.01, 0)
        bpy.ops.mesh.primitive_cone_add(
            vertices=4, radius1=0.025, depth=0.065,
            location=pos, rotation=(0, math.pi/2, a))
        sp = bpy.context.active_object; sp.name = f"Storm_Spark_{i}"
        smooth(sp); vcol(sp, C_BOLT if i%3==0 else C_ELEC); parts.append(sp)
    # 3 vertikale Blitz-Ringe
    for i, rz in enumerate([0, math.pi/3, 2*math.pi/3]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=1.20, minor_radius=0.015,
            major_segments=64, minor_segments=8,
            location=(0,0,0), rotation=(math.pi/2, 0, rz))
        vr = bpy.context.active_object; vr.name = f"Storm_VRing_{i}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(vr, C_ELEC); parts.append(vr)
    return parts


# ═══════════════════════════════════════════════════════════════
# STURMARM (spiralförmig nach außen wachsend)
# ═══════════════════════════════════════════════════════════════
def create_storm_arm(arm_idx, n_seg=28):
    parts = []
    phi0 = arm_idx * (math.tau / 4)  # 4 Arme gleichmäßig verteilt

    prev = Vector((math.cos(phi0)*1.85, math.sin(phi0)*1.85, 0))
    for si in range(n_seg):
        t = si / (n_seg - 1)
        # Spirale: Radius wächst mit t, Winkel dreht sich
        r_spiral = 1.85 + t * 1.40
        phi_spiral = phi0 + t * math.pi * 0.75  # 135° Drehung
        z_spiral   = math.sin(t * math.pi) * (0.35 - t*0.20)  # Auf- dann Abschwung

        curr = Vector((math.cos(phi_spiral)*r_spiral,
                       math.sin(phi_spiral)*r_spiral,
                       z_spiral))

        # Segment-Größe wächst mit Abstand (Wolken werden größer)
        seg_r = 0.10 + t * 0.28

        seg = cyl(f"Arm{arm_idx}_Seg{si:02d}", prev, curr, seg_r, 10)
        # Farbe: innen dunkler, außen heller
        vcol(seg, C_STORM if t < 0.35 else (C_CLOUD2 if t < 0.65 else C_CLOUD3))
        parts.append(seg)

        # Wolken-Cluster auf jedem Segment (kleine Satelliten-Kugeln)
        mid = (prev + curr) * 0.5
        for ci in range(2 + int(t*2)):
            a_cl = (ci / (2+int(t*2)))*math.tau + si*0.4
            cl_offset = Vector((math.cos(a_cl)*seg_r*0.8,
                                math.sin(a_cl)*seg_r*0.8,
                                math.sin(a_cl)*seg_r*0.5))
            cl_pos = mid + cl_offset
            bpy.ops.mesh.primitive_uv_sphere_add(
                radius=seg_r*0.45 + (ci%2)*0.06, segments=7, ring_count=4, location=cl_pos)
            cl = bpy.context.active_object; cl.name = f"Arm{arm_idx}_Cloud{si}_{ci}"
            smooth(cl); vcol(cl, C_CLOUD2 if t < 0.5 else C_CLOUD3); parts.append(cl)

        # Elektrische Blitz-Punkte alle 4 Segmente
        if si % 4 == 2:
            bpy.ops.mesh.primitive_uv_sphere_add(
                radius=seg_r*0.20, segments=6, ring_count=4, location=curr)
            bp = bpy.context.active_object; bp.name = f"Arm{arm_idx}_BlitzNode{si}"
            smooth(bp); vcol(bp, C_ELEC); parts.append(bp)

        prev = curr
    return parts


# ═══════════════════════════════════════════════════════════════
# BLITZ-NETZWERK
# ═══════════════════════════════════════════════════════════════
def make_lightning(label, p0_tup, p1_tup, n_segs=5):
    parts = []
    p0, p1 = Vector(p0_tup), Vector(p1_tup)
    total_dir = (p1 - p0)
    seg_len = total_dir.length / n_segs
    prev = p0
    for i in range(n_segs):
        t = i / (n_segs - 1)
        # Zickzack: leichte seitliche Ablenkung
        side_offset = Vector((-total_dir.y, total_dir.x, 0)).normalized() * (0.08 * (1 if i%2==0 else -1))
        nxt = p0 + total_dir * ((i+1)/n_segs) + side_offset * math.sin(i*1.4)
        seg = cyl(f"{label}_S{i}", prev, nxt, 0.014, 4)
        vcol(seg, C_BOLT if i%2==0 else C_ELEC); parts.append(seg)
        prev = nxt
    return parts

def create_lightning_network():
    parts = []
    # Blitze zwischen je 2 benachbarten Sturmarm-Spitzen + zur Hauptkugel
    for ai in range(4):
        phi0 = ai * (math.tau/4)
        phi1 = (ai+1) % 4 * (math.tau/4)
        r0 = 2.30
        p_this = (math.cos(phi0)*r0, math.sin(phi0)*r0, 0.30)
        p_next = (math.cos(phi1)*r0, math.sin(phi1)*r0, -0.20)
        parts += make_lightning(f"Bolt_Cross_{ai}", p_this, p_next, 6)
        # Blitz zum Kern
        p_core = (math.cos(phi0)*1.10, math.sin(phi0)*1.10, 0)
        parts += make_lightning(f"Bolt_Core_{ai}", (math.cos(phi0)*1.85, math.sin(phi0)*1.85, 0), p_core, 4)
    # Zusätzliche diagonale Blitze
    extra = [
        ((1.60, 0.80, 0.60), (-1.40, -0.70, -0.40)),
        ((-1.50, 0.90, -0.30), (1.20, -1.10, 0.50)),
        ((0.30, 1.80, 0.80), (0.20, -1.70, -0.60)),
    ]
    for ei, (a, b) in enumerate(extra):
        parts += make_lightning(f"Bolt_Extra_{ei}", a, b, 5)
    return parts


# ═══════════════════════════════════════════════════════════════
# TRÜMMER-BROCKEN (schwebende Felsbrocken im Sturm)
# ═══════════════════════════════════════════════════════════════
def create_debris():
    parts = []
    debris_cfg = [
        # (pos, scale, rot, color)
        (( 2.60,-0.15, 0.55), (0.7,1.3,0.9), (0.5,0.3,0.8),  C_DEBRIS),
        ((-2.50,-0.10, 0.48), (0.9,1.1,0.7), (-0.3,0.2,-0.7), C_DEBRIS2),
        (( 1.10,-0.14,-1.20), (0.8,1.0,1.1), (0.6,0.4,0.5),  C_DEBRIS),
        ((-1.20, 0.16, 1.25), (0.7,1.2,0.8), (-0.5,0.1,-0.6), C_DEBRIS2),
        (( 2.10,-0.08,-0.75), (1.1,0.9,0.7), (0.3,0.6,0.4),  C_DEBRIS),
        ((-1.95, 0.10, 0.68), (0.8,0.8,1.0), (-0.4,0.2,-0.5), C_DEBRIS2),
        (( 0.60,-0.16, 1.80), (0.6,1.4,0.8), (0.7,0.1,0.6),  C_DEBRIS),
        ((-0.65, 0.18,-1.70), (0.7,1.1,0.9), (-0.3,0.3,-0.4), C_DEBRIS2),
        (( 1.80,-0.06,-0.35), (0.5,1.0,0.6), (0.2,0.5,0.3),  C_DEBRIS),
        ((-1.72, 0.08, 0.42), (0.6,0.9,0.7), (-0.2,0.1,-0.3), C_DEBRIS2),
        (( 2.90,-0.12, 0.20), (0.4,1.2,0.5), (0.4,0.2,0.7),  C_DEBRIS),
        ((-2.85, 0.14, 0.25), (0.5,1.0,0.6), (-0.3,0.1,-0.5), C_DEBRIS),
    ]
    for i, (pos, sc, rot, col) in enumerate(debris_cfg):
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.12, subdivisions=1, location=pos)
        d = bpy.context.active_object; d.name = f"Debris_{i:02d}"
        d.scale = sc
        bpy.ops.object.transform_apply(scale=True)
        d.rotation_euler = rot
        bpy.ops.object.transform_apply(rotation=True)
        vcol(d, col); parts.append(d)
        # Elektrisches Glühen auf großen Brocken
        if i % 3 == 0:
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.038, segments=6, ring_count=4, location=pos)
            glow = bpy.context.active_object; glow.name = f"Debris_Glow_{i}"
            smooth(glow); vcol(glow, C_ELEC); parts.append(glow)
    return parts


clear_scene()
col = bpy.data.collections.new("Aion_TempestSovereign")
bpy.context.scene.collection.children.link(col)

all_parts = (create_orb()
    + create_storm_arm(0) + create_storm_arm(1)
    + create_storm_arm(2) + create_storm_arm(3)
    + create_lightning_network()
    + create_debris())

for obj in all_parts:
    for c in list(obj.users_collection): c.objects.unlink(obj)
    col.objects.link(obj)
print(f"✅ Aion Tempest Sovereign — {len(all_parts)} Teile")
