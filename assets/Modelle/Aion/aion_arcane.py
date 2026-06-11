import bpy, bmesh, math
from mathutils import Vector

# ============================================================
# AION  —  ARCANE SPHERE  |  Roblox-safe FBX
# Kugelförmiger Begleiter: Tiefindigokugel umgeben von einem
# Armillarsphären-System aus Runenzirkeln in verschiedenen
# Winkeln — mit Runenstein-Markierungen, arkanen Blitzen,
# Zaubergem-Fragmenten und einem magischen Kronenstab.
# ============================================================

C_INDIGO  = (0.04, 0.02, 0.16, 1.0)  # Mitternachts-Indigo
C_ARCANE  = (0.14, 0.08, 0.48, 1.0)  # Arkanes Violett
C_MAGIC   = (0.16, 0.62, 0.98, 1.0)  # Magisches Blau-Cyan
C_GOLD_A  = (0.84, 0.70, 0.12, 1.0)  # Runen-Gold
C_STAR_W  = (0.92, 0.96, 1.00, 1.0)  # Sternweiß
C_SIGIL   = (0.48, 0.18, 0.88, 1.0)  # Sigillen-Lila
C_ETHER   = (0.06, 0.88, 0.62, 1.0)  # Ätherisches Grün
C_BLITZ   = (0.88, 0.96, 1.00, 1.0)  # Blitz-Weiß

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
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = vec.to_track_quat('Z','Y')
    smooth(obj)
    return obj

def cone(name, s, e, r1=0.05, r2=0.0, v=6):
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

def sph_pt(theta, phi, r=1.0):
    return (r*math.sin(theta)*math.cos(phi),
            r*math.sin(theta)*math.sin(phi),
            r*math.cos(theta))


# ═══════════════════════════════════════════════════════════════
# HAUPTKUGEL
# ═══════════════════════════════════════════════════════════════
def create_orb():
    parts = []
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=64, ring_count=32, location=(0,0,0))
    orb = bpy.context.active_object; orb.name = "Aion_Orb"
    smooth(orb); vcol(orb, C_INDIGO); parts.append(orb)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.65, segments=32, ring_count=16, location=(0,0,0))
    c1 = bpy.context.active_object; c1.name = "Aion_Core1"
    smooth(c1); vcol(c1, C_ARCANE); parts.append(c1)

    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.36, subdivisions=3, location=(0,0,0))
    c2 = bpy.context.active_object; c2.name = "Aion_Core2"
    smooth(c2); vcol(c2, C_SIGIL); parts.append(c2)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.15, segments=12, ring_count=6, location=(0,0,0))
    c3 = bpy.context.active_object; c3.name = "Aion_Nucleus"
    smooth(c3); vcol(c3, C_MAGIC); parts.append(c3)

    # Innerer Kern-Stern (kleines Ico-Sphere)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.06, subdivisions=1, location=(0,0,0))
    c4 = bpy.context.active_object; c4.name = "Aion_StarCore"
    smooth(c4); vcol(c4, C_STAR_W); parts.append(c4)

    # 3 Breitengrad-Ringe
    for i, (z, maj, mn, col) in enumerate([
        (0.65, 0.76, 0.018, C_ARCANE),
        (0.00, 1.01, 0.028, C_GOLD_A),
        (-0.65, 0.76, 0.018, C_ARCANE),
    ]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=maj, minor_radius=mn,
            major_segments=60, minor_segments=10, location=(0,0,z))
        ring = bpy.context.active_object; ring.name = f"Aion_Ring_{i}"
        vcol(ring, col); parts.append(ring)

    # 8 Gold-Markierungen auf Äquator
    for i in range(8):
        a = (i/8)*math.tau
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.034, segments=6, ring_count=4,
            location=(math.cos(a)*1.02, math.sin(a)*1.02, 0))
        m = bpy.context.active_object; m.name = f"Aion_EqMark_{i}"
        smooth(m); vcol(m, C_GOLD_A if i%2==0 else C_STAR_W); parts.append(m)

    # Großer Schwebering (Arkanes Blau)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.46, minor_radius=0.022,
        major_segments=80, minor_segments=10, location=(0,0,0))
    halo = bpy.context.active_object; halo.name = "Aion_Halo"
    vcol(halo, C_MAGIC); parts.append(halo)

    # 10 Zauber-Gems auf großem Ring
    for i in range(10):
        a = (i/10)*math.tau
        bpy.ops.mesh.primitive_cone_add(
            vertices=4, radius1=0.036, depth=0.08,
            location=(math.cos(a)*1.46, math.sin(a)*1.46, 0),
            rotation=(0, math.pi/2, a+math.pi/4))
        gem = bpy.context.active_object; gem.name = f"Aion_RingGem_{i}"
        smooth(gem)
        vcol(gem, C_MAGIC if i%3==0 else (C_GOLD_A if i%3==1 else C_SIGIL))
        parts.append(gem)

    return parts


# ═══════════════════════════════════════════════════════════════
# RUNENZIRKEL-SYSTEM (Armillarsphäre)
# ═══════════════════════════════════════════════════════════════
def rune_ring(name, major_r, minor_r, tilt_x, tilt_z, color, n_markers, marker_col):
    """Ein Torus-Ring in beliebiger Neigung mit Runenstein-Markierungen."""
    parts = []
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_r, minor_radius=minor_r,
        major_segments=80, minor_segments=10,
        location=(0,0,0), rotation=(tilt_x, 0, tilt_z))
    ring = bpy.context.active_object; ring.name = name
    bpy.ops.object.transform_apply(rotation=True)
    vcol(ring, color); parts.append(ring)

    # Runenstein-Markierungen: kleine Quader auf dem Ring
    # Nach transform_apply liegt der Ring in seiner endgültigen Geometrie.
    # Wir platzieren Markierungen mithilfe der Rotationsmatrix.
    from mathutils import Euler, Matrix
    rot_mat = Euler((tilt_x, 0, tilt_z), 'XYZ').to_matrix()
    for i in range(n_markers):
        a = (i/n_markers)*math.tau
        # Punkt auf dem Torus-Mittelpfad (vor Rotation)
        lx = math.cos(a)*major_r
        ly = math.sin(a)*major_r
        local = Vector((lx, ly, 0))
        world = rot_mat @ local
        bpy.ops.mesh.primitive_cube_add(
            size=0.06, scale=(0.5, 0.5, 1.8), location=world)
        mk = bpy.context.active_object; mk.name = f"{name}_mk{i}"
        mk.rotation_euler = (tilt_x, 0, tilt_z + a)
        bpy.ops.object.transform_apply(rotation=True)
        vcol(mk, marker_col); parts.append(mk)

    return parts

def create_rune_rings():
    parts = []
    # 6 Ringe bei verschiedenen Winkeln: (name, major_r, minor_r, tilt_x, tilt_z, color, n_marks, mark_col)
    ring_defs = [
        ("RRing_Equator",  1.22, 0.016, 0.0,           0.0,           C_GOLD_A,  8,  C_STAR_W),
        ("RRing_Vert0",    1.18, 0.014, math.pi/2,      0.0,           C_MAGIC,   6,  C_GOLD_A),
        ("RRing_Vert60",   1.18, 0.014, math.pi/2,      math.pi/3,     C_SIGIL,   6,  C_MAGIC),
        ("RRing_Vert120",  1.18, 0.014, math.pi/2,      2*math.pi/3,   C_ETHER,   6,  C_STAR_W),
        ("RRing_Tilt40",   1.20, 0.012, math.pi*0.44,   math.pi*0.25,  C_ARCANE,  5,  C_GOLD_A),
        ("RRing_Tilt140",  1.20, 0.012, math.pi*0.44,   math.pi*0.75,  C_MAGIC,   5,  C_SIGIL),
    ]
    for args in ring_defs:
        parts += rune_ring(*args)
    return parts


# ═══════════════════════════════════════════════════════════════
# ARKANE BLITZE (Zickzack-Stäbe)
# ═══════════════════════════════════════════════════════════════
def create_lightning():
    parts = []

    bolt_defs = [
        # (Wurzelpunkt theta/phi, Richtung theta/phi)
        (0.52, 0.80,  0.38, 0.70),
        (0.95, 2.50,  0.82, 2.62),
        (1.40, 4.10,  1.28, 4.25),
        (0.65, 5.20,  0.50, 5.35),
        (1.72, 1.20,  1.62, 1.08),
        (1.20, 3.40,  1.10, 3.55),
    ]
    for i, (th, ph, eth, eph) in enumerate(bolt_defs):
        # 3-segmentiger Blitz mit Knicken
        p0 = sph_pt(th,  ph,  1.02)
        p1 = sph_pt(th+(eth-th)*0.4, ph+(eph-ph)*0.4 + 0.08, 1.18)  # Knick
        p2 = sph_pt(eth, eph, 1.38)  # Spitze

        s1 = cyl(f"Bolt_{i}_s1", p0, p1, 0.012, 4)
        vcol(s1, C_BLITZ); parts.append(s1)
        s2 = cyl(f"Bolt_{i}_s2", p1, p2, 0.008, 4)
        vcol(s2, C_MAGIC); parts.append(s2)
        # Blitz-Spitze
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.022, segments=6, ring_count=4, location=p2)
        tip = bpy.context.active_object; tip.name = f"Bolt_{i}_tip"
        smooth(tip); vcol(tip, C_STAR_W); parts.append(tip)

    return parts


# ═══════════════════════════════════════════════════════════════
# ARKANE KRONE (Nordpol)
# ═══════════════════════════════════════════════════════════════
def create_crown():
    parts = []

    # Kronen-Basis-Ring
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.22, minor_radius=0.028,
        major_segments=20, minor_segments=8, location=(0,0,0.88))
    base = bpy.context.active_object; base.name = "Aion_CrownBase"
    vcol(base, C_GOLD_A); parts.append(base)

    # 6 Kron-Spitzen abwechselnd hoch/niedrig
    for i in range(6):
        a = (i/6)*math.tau
        x, y = math.cos(a)*0.22, math.sin(a)*0.22
        h = 0.32 if i%2==0 else 0.18
        s = (x, y, 0.94)
        e = (x*0.8, y*0.8, 0.94+h)
        sp = cone(f"Aion_CrownSpike_{i}", s, e, 0.028, 0.002, 5)
        vcol(sp, C_GOLD_A if i%2==0 else C_ARCANE); parts.append(sp)
        # Kristall auf Haupt-Spitzen
        if i%2==0:
            bpy.ops.mesh.primitive_cone_add(
                vertices=4, radius1=0.022, depth=0.055,
                location=(x*0.75, y*0.75, 1.28))
            gem = bpy.context.active_object; gem.name = f"Aion_CrownGem_{i}"
            smooth(gem); vcol(gem, C_MAGIC); parts.append(gem)

    # Innerer Kreis (zweite Krons-Ebene)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.14, minor_radius=0.016,
        major_segments=14, minor_segments=6, location=(0,0,1.00))
    inner = bpy.context.active_object; inner.name = "Aion_CrownInner"
    vcol(inner, C_SIGIL); parts.append(inner)

    # Zentrum-Orb der Krone
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.065, segments=10, ring_count=6, location=(0,0,1.05))
    co = bpy.context.active_object; co.name = "Aion_CrownOrb"
    smooth(co); vcol(co, C_STAR_W); parts.append(co)

    # Magie-Strahlen aus dem Orb (8 dünne Kegel)
    for i in range(8):
        a = (i/8)*math.tau
        sx, sy = math.cos(a)*0.065, math.sin(a)*0.065
        ex, ey = math.cos(a)*0.20, math.sin(a)*0.20
        ray = cone(f"Aion_Ray_{i}", (sx,sy,1.05), (ex,ey,1.05), 0.010, 0.001, 4)
        vcol(ray, C_MAGIC if i%2==0 else C_GOLD_A); parts.append(ray)

    # Südpol: Power-Kristall-Anhänger
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.16, minor_radius=0.020,
        major_segments=14, minor_segments=6, location=(0,0,-0.90))
    sr = bpy.context.active_object; sr.name = "Aion_SouthRing"
    vcol(sr, C_ARCANE); parts.append(sr)

    cone("Aion_PowerCrystal", (0,0,-0.98), (0,0,-1.28), 0.06, 0.002, 6)
    pc = bpy.context.active_object
    vcol(pc, C_SIGIL); parts.append(pc)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.038, segments=8, ring_count=5, location=(0,0,-1.30))
    pct = bpy.context.active_object; pct.name = "Aion_PowerTip"
    smooth(pct); vcol(pct, C_STAR_W); parts.append(pct)

    return parts


# ═══════════════════════════════════════════════════════════════
# SCHWEBENDE ZAUBER-GEMS
# ═══════════════════════════════════════════════════════════════
def create_gems():
    parts = []
    gem_cfg = [
        (( 1.42,-0.08, 0.52), C_SIGIL),
        ((-1.38, 0.06, 0.48), C_MAGIC),
        (( 0.70,-0.10,-0.80), C_ETHER),
        ((-0.76, 0.12, 0.85), C_GOLD_A),
        (( 1.18,-0.06,-0.38), C_SIGIL),
        ((-1.12, 0.08, 0.35), C_MAGIC),
        (( 0.50,-0.12, 1.15), C_ETHER),
        ((-0.56, 0.14,-0.78), C_STAR_W),
    ]
    for i, (pos, col) in enumerate(gem_cfg):
        bpy.ops.mesh.primitive_ico_sphere_add(
            radius=0.052, subdivisions=1, location=pos)
        gem = bpy.context.active_object; gem.name = f"Aion_FloatGem_{i}"
        vcol(gem, col); parts.append(gem)
        # Aura-Ring um Gem
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.075, minor_radius=0.006,
            major_segments=12, minor_segments=4,
            location=pos, rotation=(i*0.6, i*0.4, 0))
        ar = bpy.context.active_object; ar.name = f"Aion_GemAura_{i}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(ar, C_MAGIC if i%2==0 else C_GOLD_A); parts.append(ar)

    return parts


# ═══════════════════════════════════════════════════════════════
# AURA — Arkanes Magie-Energiefeld
# ═══════════════════════════════════════════════════════════════
def create_aura():
    parts = []
    # Arkane Aura-Hülle (tiefes Indigo-Schild)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=1.58, subdivisions=1, location=(0,0,0))
    shell = bpy.context.active_object; shell.name = "Aura_Shell"
    vcol(shell, C_INDIGO); parts.append(shell)
    # Innerer Gold-Sigillen-Ring
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.52, minor_radius=0.022,
        major_segments=60, minor_segments=8, location=(0,0,0))
    igr = bpy.context.active_object; igr.name = "Aura_InnerRing"
    vcol(igr, C_GOLD_A); parts.append(igr)
    # 3 Orbit-Ringe: Arkane Zirkel
    for i, (rx, rz, mr, col) in enumerate([
        (0.0,       0.0,        1.80, C_GOLD_A),
        (math.pi/2, 0.0,        1.76, C_MAGIC),
        (math.pi/2, math.pi/3,  1.72, C_SIGIL),
    ]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=mr, minor_radius=0.016,
            major_segments=64, minor_segments=8,
            location=(0,0,0), rotation=(rx, 0, rz))
        r = bpy.context.active_object; r.name = f"Aura_Ring_{i}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(r, col); parts.append(r)
    # Zauber-Funken-Partikel (14 Stern-Orbs)
    for i in range(14):
        a = (i / 14) * math.tau
        h = math.sin(i * 1.1) * 0.44
        rd = 1.84 + (i % 3) * 0.07
        pos = (math.cos(a)*rd*math.cos(h), math.sin(a)*rd*math.cos(h), rd*math.sin(h))
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.026 + (i%3)*0.008, segments=6, ring_count=3, location=pos)
        p = bpy.context.active_object; p.name = f"Aura_Spark_{i}"
        smooth(p); vcol(p, C_STAR_W if i%3==0 else (C_MAGIC if i%3==1 else C_GOLD_A))
        parts.append(p)
    # 6 Arkane Energie-Strahlen (dünne Zauberkegel nach außen)
    for i in range(6):
        a = (i / 6) * math.tau
        elev = math.pi / 5 * (1 if i%2==0 else -1)
        r1, r2 = 1.64, 2.08
        cx, cy = math.cos(a), math.sin(a)
        ce, se = math.cos(elev), math.sin(elev)
        ray = cone(f"Aura_Ray_{i}",
                   (cx*r1*ce, cy*r1*ce, r1*se),
                   (cx*r2*ce, cy*r2*ce, r2*se),
                   0.022, 0.001, 4)
        vcol(ray, C_MAGIC if i%2==0 else C_ETHER); parts.append(ray)
    # 4 Rune-Marker auf dem äußeren Ring (kleine leuchtende Quader)
    for i in range(4):
        a = (i / 4) * math.tau
        pos = (math.cos(a)*1.82, math.sin(a)*1.82, 0)
        bpy.ops.mesh.primitive_cube_add(
            size=0.06, scale=(0.4, 0.4, 2.2), location=pos, rotation=(0, 0, a))
        mk = bpy.context.active_object; mk.name = f"Aura_RuneMark_{i}"
        vcol(mk, C_GOLD_A); parts.append(mk)
    return parts


clear_scene()
col = bpy.data.collections.new("Aion_ArcaneSphere")
bpy.context.scene.collection.children.link(col)

all_parts = (create_orb()
    + create_rune_rings()
    + create_lightning()
    + create_crown()
    + create_gems()
    + create_aura())

for obj in all_parts:
    for c in list(obj.users_collection): c.objects.unlink(obj)
    col.objects.link(obj)
print(f"✅ Aion Arcane Sphere — {len(all_parts)} Teile")
