import bpy, bmesh, math
from mathutils import Vector

# ============================================================
# AION  —  CLOCKWORK  |  Roblox-safe FBX
# Kugelförmiger Begleiter: Steampunk-Mechanismus —
# Bronze-Kugel mit rotierenden Zahnrad-Ringen,
# Kolben-Polen, Nieten-Band und Kupfer-Rohren.
# ============================================================

C_IRON   = (0.06, 0.05, 0.04, 1.0)   # dunkles Eisen
C_BRONZE = (0.42, 0.26, 0.06, 1.0)   # Bronze
C_COPPER = (0.62, 0.30, 0.08, 1.0)   # Kupfer
C_BRASS  = (0.72, 0.56, 0.10, 1.0)   # Messing
C_GOLD_M = (0.88, 0.70, 0.12, 1.0)   # Gold-Messing
C_STEAM  = (0.88, 0.88, 0.84, 1.0)   # Dampf-Weiß
C_GLOW_M = (0.90, 0.52, 0.05, 1.0)   # Glüh-Orange (Energie)
C_DARK_M = (0.14, 0.10, 0.04, 1.0)   # sehr dunkles Braun

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

def cyl(name, s, e, r=0.06, v=12):
    sv, ev = Vector(s), Vector(e)
    vec = ev - sv
    bpy.ops.mesh.primitive_cylinder_add(
        radius=r, depth=vec.length, vertices=v, location=(sv+ev)*0.5)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = vec.to_track_quat('Z','Y')
    smooth(obj)
    return obj

def cone(name, s, e, r1=0.05, r2=0.0, v=10):
    sv, ev = Vector(s), Vector(e)
    vec = ev - sv
    bpy.ops.mesh.primitive_cone_add(
        radius1=r1, radius2=r2, depth=vec.length, vertices=v,
        location=(sv+ev)*0.5)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = vec.to_track_quat('Z','Y')
    smooth(obj)
    return obj

# ── Zahnrad-Ring: Torus + Zähne ──────────────────────────────
def gear_ring(prefix, center_z, ring_r, n_teeth, tooth_r, tooth_h,
              ring_col, tooth_col, rot_x=0.0, rot_z=0.0):
    parts = []
    bpy.ops.mesh.primitive_torus_add(
        major_radius=ring_r, minor_radius=0.030,
        major_segments=60, minor_segments=10,
        location=(0,0,center_z), rotation=(rot_x, 0, rot_z))
    ring = bpy.context.active_object; ring.name = f"{prefix}_Ring"
    if rot_x != 0:
        bpy.ops.object.transform_apply(rotation=True)
    vcol(ring, ring_col); parts.append(ring)

    for i in range(n_teeth):
        a = (i/n_teeth)*math.tau
        if rot_x == 0:
            tx = math.cos(a)*ring_r
            ty = math.sin(a)*ring_r
            tz = center_z + tooth_h*0.5 + 0.030
            bpy.ops.mesh.primitive_cylinder_add(
                radius=tooth_r, depth=tooth_h, vertices=6,
                location=(tx, ty, tz))
        else:
            # Für geneigte Ringe: Zähne radial nach außen
            tx = math.cos(a)*(ring_r + tooth_h*0.5)
            ty = math.sin(a)*(ring_r + tooth_h*0.5)
            tz = center_z
            bpy.ops.mesh.primitive_cube_add(
                size=1, scale=(tooth_r*2, tooth_r*2, tooth_h),
                location=(tx, ty, tz), rotation=(0, 0, a))
        tooth = bpy.context.active_object; tooth.name = f"{prefix}_Tooth_{i}"
        smooth(tooth); vcol(tooth, tooth_col); parts.append(tooth)
    return parts


# ═══════════════════════════════════════════════════════════════
# HAUPTKUGEL
# ═══════════════════════════════════════════════════════════════
def create_orb():
    parts = []

    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=1.0, segments=64, ring_count=32, location=(0,0,0))
    orb = bpy.context.active_object; orb.name = "Aion_Orb"
    smooth(orb); vcol(orb, C_IRON); parts.append(orb)

    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.65, segments=32, ring_count=16, location=(0,0,0))
    c1 = bpy.context.active_object; c1.name = "Aion_Orb_Core"
    smooth(c1); vcol(c1, C_BRONZE); parts.append(c1)

    bpy.ops.mesh.primitive_ico_sphere_add(
        radius=0.36, subdivisions=2, location=(0,0,0))
    c2 = bpy.context.active_object; c2.name = "Aion_Energy_Core"
    smooth(c2); vcol(c2, C_GLOW_M); parts.append(c2)

    # Äquator-Nieten-Band (dicker Zylinder-Ring)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.015, minor_radius=0.048,
        major_segments=64, minor_segments=12, location=(0,0,0))
    band = bpy.context.active_object; band.name = "Aion_BeltBand"
    vcol(band, C_BRASS); parts.append(band)

    # 16 Nieten auf dem Band
    for i in range(16):
        a = (i/16)*math.tau
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.032, segments=8, ring_count=6,
            location=(math.cos(a)*1.06, math.sin(a)*1.06, 0))
        bolt = bpy.context.active_object; bolt.name = f"Aion_Bolt_{i}"
        smooth(bolt); vcol(bolt, C_GOLD_M); parts.append(bolt)

    # Längsrillen: 8 Kupfer-Streifen
    for i in range(8):
        a = (i/8)*math.tau
        bpy.ops.mesh.primitive_cube_add(
            size=1, scale=(0.022, 0.022, 1.85),
            location=(math.cos(a)*1.02, math.sin(a)*1.02, 0),
            rotation=(0, 0, a))
        gr = bpy.context.active_object; gr.name = f"Aion_Stripe_{i}"
        vcol(gr, C_COPPER); parts.append(gr)

    # Bullaugen-Fenster (Sichtöffnung vorne)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.35, minor_radius=0.038,
        major_segments=24, minor_segments=10, location=(0,-1.01,0))
    port = bpy.context.active_object; port.name = "Aion_Porthole_Frame"
    vcol(port, C_BRASS); parts.append(port)
    # 8 Nieten am Bullauge
    for i in range(8):
        a = (i/8)*math.tau
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.022, segments=6, ring_count=4,
            location=(math.sin(a)*0.38, -1.01, math.cos(a)*0.38))
        pn = bpy.context.active_object; pn.name = f"Aion_PortNut_{i}"
        smooth(pn); vcol(pn, C_GOLD_M); parts.append(pn)
    # Glasscheibe (kleine dunkle Kugel innen)
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.28, segments=16, ring_count=8, location=(0,-0.98,0))
    glass = bpy.context.active_object; glass.name = "Aion_Porthole_Glass"
    smooth(glass); vcol(glass, C_GLOW_M); parts.append(glass)

    return parts


# ═══════════════════════════════════════════════════════════════
# ZAHNRAD-RINGE
# ═══════════════════════════════════════════════════════════════
def create_gears():
    parts = []

    # Ring 1: Horizontal am Äquator (groß, Bronze)
    parts += gear_ring("Gear_Equator", 0.0, 1.28, 24,
                       0.036, 0.055, C_BRONZE, C_BRASS)

    # Ring 2: Vertikal (senkrecht stehend), geneigt um 90°
    parts += gear_ring("Gear_Vertical_A", 0.0, 1.22, 20,
                       0.030, 0.048, C_COPPER, C_BRASS,
                       rot_x=math.pi/2, rot_z=0.0)

    # Ring 3: Zweiter vertikaler Ring, 60° gedreht
    parts += gear_ring("Gear_Vertical_B", 0.0, 1.22, 20,
                       0.030, 0.048, C_COPPER, C_GOLD_M,
                       rot_x=math.pi/2, rot_z=math.pi/3)

    # Kleiner innerer Hilfs-Ring (schmal, diagonal)
    parts += gear_ring("Gear_Inner", 0.0, 0.88, 14,
                       0.022, 0.038, C_BRASS, C_GLOW_M,
                       rot_x=math.pi/4, rot_z=math.pi/6)

    return parts


# ═══════════════════════════════════════════════════════════════
# NORDPOL: KOLBEN-MECHANISMUS
# ═══════════════════════════════════════════════════════════════
def create_north_mechanism():
    parts = []

    # Basisplatte
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.30, depth=0.06, vertices=16, location=(0,0,0.95))
    base = bpy.context.active_object; base.name = "Aion_N_Base"
    smooth(base); vcol(base, C_BRONZE); parts.append(base)

    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.28, minor_radius=0.022,
        major_segments=24, minor_segments=8, location=(0,0,0.98))
    br = bpy.context.active_object; br.name = "Aion_N_BaseRing"
    vcol(br, C_BRASS); parts.append(br)

    # Zentraler Teleskop-Turm (3 Stufen, nach oben schmaler)
    for i, (z, r, h) in enumerate([
        (1.06, 0.18, 0.18),
        (1.20, 0.12, 0.18),
        (1.34, 0.07, 0.14),
    ]):
        bpy.ops.mesh.primitive_cylinder_add(
            radius=r, depth=h, vertices=12, location=(0,0,z))
        seg = bpy.context.active_object; seg.name = f"Aion_N_Tower_{i}"
        smooth(seg); vcol(seg, C_IRON if i%2==0 else C_BRONZE)
        parts.append(seg)
        # Verbindungsring
        bpy.ops.mesh.primitive_torus_add(
            major_radius=r*1.15, minor_radius=0.016,
            major_segments=20, minor_segments=6, location=(0,0,z+h/2+0.005))
        tr = bpy.context.active_object; tr.name = f"Aion_N_TowerRing_{i}"
        vcol(tr, C_BRASS); parts.append(tr)

    # Spitze: Energie-Kugel + kleine Antenne
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.062, segments=10, ring_count=6, location=(0,0,1.46))
    tip = bpy.context.active_object; tip.name = "Aion_N_EnergyTip"
    smooth(tip); vcol(tip, C_GLOW_M); parts.append(tip)
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.008, depth=0.14, vertices=6, location=(0,0,1.54))
    ant = bpy.context.active_object; ant.name = "Aion_N_Antenna"
    smooth(ant); vcol(ant, C_BRASS); parts.append(ant)

    # 4 Kolben seitlich von der Basis
    for i in range(4):
        a = (i/4)*math.tau + math.pi/4
        px, py = math.cos(a)*0.24, math.sin(a)*0.24
        # Kolben-Zylinder
        bpy.ops.mesh.primitive_cylinder_add(
            radius=0.042, depth=0.26, vertices=8,
            location=(px, py, 1.10))
        piston = bpy.context.active_object; piston.name = f"Aion_Piston_{i}"
        smooth(piston); vcol(piston, C_COPPER); parts.append(piston)
        # Kolben-Kopf
        bpy.ops.mesh.primitive_cylinder_add(
            radius=0.056, depth=0.038, vertices=8,
            location=(px, py, 1.24))
        ph = bpy.context.active_object; ph.name = f"Aion_PistonHead_{i}"
        smooth(ph); vcol(ph, C_BRASS); parts.append(ph)

    return parts


# ═══════════════════════════════════════════════════════════════
# SÜDPOL: ABZUG/TRICHTER
# ═══════════════════════════════════════════════════════════════
def create_south_mechanism():
    parts = []

    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.26, depth=0.06, vertices=16, location=(0,0,-0.94))
    base = bpy.context.active_object; base.name = "Aion_S_Base"
    smooth(base); vcol(base, C_BRONZE); parts.append(base)

    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.24, minor_radius=0.020,
        major_segments=24, minor_segments=8, location=(0,0,-0.97))
    sr = bpy.context.active_object; sr.name = "Aion_S_Ring"
    vcol(sr, C_BRASS); parts.append(sr)

    # Trichter (Exhausts)
    bpy.ops.mesh.primitive_cone_add(
        radius1=0.20, radius2=0.08, depth=0.30,
        vertices=12, location=(0,0,-1.22))
    tr = bpy.context.active_object; tr.name = "Aion_S_Funnel"
    smooth(tr); vcol(tr, C_IRON); parts.append(tr)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.22, minor_radius=0.018,
        major_segments=24, minor_segments=6, location=(0,0,-1.06))
    fr = bpy.context.active_object; fr.name = "Aion_S_FunnelRing"
    vcol(fr, C_COPPER); parts.append(fr)

    # Ablassventil-Kugel am Ende
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.068, segments=10, ring_count=6, location=(0,0,-1.40))
    sv = bpy.context.active_object; sv.name = "Aion_S_Valve"
    smooth(sv); vcol(sv, C_BRASS); parts.append(sv)

    # 3 kleine Kupfer-Rohre diagonal nach unten
    for i in range(3):
        a = (i/3)*math.tau
        px, py = math.cos(a)*0.18, math.sin(a)*0.18
        pipe_end = (px*1.4, py*1.4, -1.55)
        pipe = cyl(f"Aion_Pipe_{i}", (px, py, -1.05), pipe_end, 0.030, 8)
        vcol(pipe, C_COPPER); parts.append(pipe)
        # Rohr-Flansch-Ring
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.048, minor_radius=0.010,
            major_segments=12, minor_segments=6,
            location=pipe_end)
        pf = bpy.context.active_object; pf.name = f"Aion_PipeFlange_{i}"
        vcol(pf, C_BRASS); parts.append(pf)

    return parts


# ═══════════════════════════════════════════════════════════════
# HAUPT
# ═══════════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════════
# AURA — Dampf- und Energie-Feld
# ═══════════════════════════════════════════════════════════════
def create_aura():
    parts = []
    # Dunkle Eisen-Aura-Hülle (glühend orange)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=1.58, subdivisions=1, location=(0,0,0))
    shell = bpy.context.active_object; shell.name = "Aura_Shell"
    vcol(shell, C_IRON); parts.append(shell)
    # Innerer Energie-Ring
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.52, minor_radius=0.022,
        major_segments=60, minor_segments=8, location=(0,0,0))
    igr = bpy.context.active_object; igr.name = "Aura_InnerRing"
    vcol(igr, C_GLOW_M); parts.append(igr)
    # 3 Orbit-Ringe: Messing-Zahnrad-Zirkel
    for i, (rx, rz, mr, col) in enumerate([
        (0.0,       0.0,        1.80, C_BRASS),
        (math.pi/2, 0.0,        1.76, C_GLOW_M),
        (math.pi/2, math.pi/3,  1.72, C_BRONZE),
    ]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=mr, minor_radius=0.018,
            major_segments=64, minor_segments=10,
            location=(0,0,0), rotation=(rx, 0, rz))
        r = bpy.context.active_object; r.name = f"Aura_GearRing_{i}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(r, col); parts.append(r)
        # 8 Zahnrad-Zähne auf dem Ring
        from mathutils import Euler
        rot_m = Euler((rx, 0, rz), 'XYZ').to_matrix()
        for j in range(8):
            a = (j / 8) * math.tau
            lp = rot_m @ Vector((math.cos(a)*mr, math.sin(a)*mr, 0))
            bpy.ops.mesh.primitive_cylinder_add(
                radius=0.015, depth=0.052, vertices=5, location=lp)
            tooth = bpy.context.active_object; tooth.name = f"Aura_Tooth_{i}_{j}"
            vcol(tooth, C_GOLD_M); parts.append(tooth)
    # Dampf-Partikelwolke (14 Wolken-Orbs)
    for i in range(14):
        a = (i / 14) * math.tau
        h = math.sin(i * 1.1) * 0.45
        rd = 1.85 + (i % 3) * 0.08
        pos = (math.cos(a)*rd*math.cos(h), math.sin(a)*rd*math.cos(h), rd*math.sin(h))
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.036 + (i%3)*0.010, segments=6, ring_count=3, location=pos)
        p = bpy.context.active_object; p.name = f"Aura_Steam_{i}"
        smooth(p); vcol(p, C_STEAM if i%2==0 else C_GLOW_M); parts.append(p)
    # 6 Energie-Funken (Kegel nach außen)
    for i in range(6):
        a = (i / 6) * math.tau
        elev = math.pi / 6 * (1 if i%2==0 else -1)
        r1, r2 = 1.64, 2.02
        cx, cy = math.cos(a), math.sin(a)
        ce, se = math.cos(elev), math.sin(elev)
        sp = cone(f"Aura_EnergySpark_{i}",
                  (cx*r1*ce, cy*r1*ce, r1*se),
                  (cx*r2*ce, cy*r2*ce, r2*se),
                  0.020, 0.001, 4)
        vcol(sp, C_GLOW_M if i%2==0 else C_BRASS); parts.append(sp)
    return parts


clear_scene()
col = bpy.data.collections.new("Aion_Clockwork")
bpy.context.scene.collection.children.link(col)

all_parts = (create_orb() + create_gears()
             + create_north_mechanism() + create_south_mechanism()
             + create_aura())

for obj in all_parts:
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)

print(f"✅ Aion Clockwork — {len(all_parts)} Teile")
