import bpy, bmesh, math
from mathutils import Vector

# ============================================================
# AION  —  ABYSSAL KRAKEN  |  Roblox-safe FBX
# Tiefsee-Monster: 8 Tentakel winden sich um die Kugel,
# 2 riesige Fangtentakel, Mantel-Haube, Compound-Augen,
# Saugnäpfe, Biolumineszenz-Muster, Tintenwolken.
# ============================================================

C_MANTLE  = (0.04, 0.05, 0.12, 1.0)   # Mantel Tiefsee-Dunkel
C_TENT    = (0.06, 0.07, 0.18, 1.0)   # Tentakel Dunkelblau
C_TENT2   = (0.10, 0.12, 0.28, 1.0)   # Tentakel Mittel
C_SUCKER  = (0.08, 0.35, 0.55, 1.0)   # Saugnäpfe Cyan-Blau
C_BIO     = (0.04, 0.88, 0.72, 1.0)   # Biolumineszenz Cyan-Grün
C_BIO2    = (0.10, 0.55, 0.95, 1.0)   # Bio Blau
C_EYE_S   = (0.60, 0.08, 0.06, 1.0)   # Auge Sklera Blutig
C_EYE_P   = (0.02, 0.01, 0.05, 1.0)   # Pupille Schwarz
C_INK     = (0.05, 0.04, 0.10, 1.0)   # Tinte Dunkel
C_ORB     = (0.02, 0.03, 0.12, 1.0)   # Kugel Tiefschwarz
C_FIN     = (0.08, 0.10, 0.22, 1.0)   # Flossen
C_CLAW    = (0.14, 0.16, 0.32, 1.0)   # Fang-Spitzen

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)

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

def cyl(name, s, e, r=0.05, v=8):
    sv, ev = Vector(s), Vector(e)
    vec = ev - sv
    bpy.ops.mesh.primitive_cylinder_add(
        radius=r, depth=vec.length, vertices=v, location=(sv+ev)*0.5)
    obj = bpy.context.active_object; obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = vec.to_track_quat('Z','Y')
    smooth(obj); return obj

def cone_obj(name, s, e, r1=0.05, r2=0.0, v=6):
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
# KUGEL & MANTEL
# ═══════════════════════════════════════════════════════════════
def create_orb_and_mantle():
    parts = []
    # Hauptkugel
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=64, ring_count=32, location=(0,0,0))
    orb = bpy.context.active_object; orb.name = "Aion_Orb"; smooth(orb); vcol(orb, C_ORB); parts.append(orb)
    # Leuchtendes Inneres
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.60, segments=24, ring_count=12, location=(0,0,0))
    c1 = bpy.context.active_object; c1.name = "Kraken_InnerGlow"; smooth(c1); vcol(c1, (0.04,0.12,0.30,1.0)); parts.append(c1)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.28, segments=12, ring_count=7, location=(0,0,0))
    c2 = bpy.context.active_object; c2.name = "Kraken_Core"; smooth(c2); vcol(c2, C_BIO); parts.append(c2)

    # Mantel-Haube (Cone + Zylinder über der Kugel)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.68, depth=0.55, vertices=14, location=(0,0,1.28))
    mantle_cyl = bpy.context.active_object; mantle_cyl.name = "Mantle_Body"; smooth(mantle_cyl); vcol(mantle_cyl, C_MANTLE); parts.append(mantle_cyl)
    bpy.ops.mesh.primitive_cone_add(radius1=0.68, radius2=0.08, depth=0.60, vertices=14, location=(0,0,1.82))
    mantle_top = bpy.context.active_object; mantle_top.name = "Mantle_Tip"; smooth(mantle_top); vcol(mantle_top, C_MANTLE); parts.append(mantle_top)
    # Mantel-Rippen (8 vertikale Wülste)
    for i in range(8):
        a = (i/8)*math.tau
        bpy.ops.mesh.primitive_cylinder_add(
            radius=0.042, depth=0.80, vertices=5,
            location=(math.cos(a)*0.65, math.sin(a)*0.65, 1.35),
            rotation=(0,0,a))
        rib = bpy.context.active_object; rib.name = f"Mantle_Rib_{i}"; smooth(rib); vcol(rib, C_TENT2); parts.append(rib)
    # Mantel-Basis-Ring
    bpy.ops.mesh.primitive_torus_add(major_radius=0.72, minor_radius=0.04, major_segments=40, minor_segments=8, location=(0,0,1.02))
    br = bpy.context.active_object; br.name = "Mantle_BaseRing"; vcol(br, C_BIO2); parts.append(br)
    # Bio-Leuchtflecken auf dem Mantel (10 Punkte)
    for i in range(10):
        a = (i/10)*math.tau
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.038, segments=6, ring_count=4,
            location=(math.cos(a)*0.58, math.sin(a)*0.58, 1.25 + math.sin(a)*0.15))
        bp = bpy.context.active_object; bp.name = f"Mantle_BioSpot_{i}"; smooth(bp); vcol(bp, C_BIO if i%2==0 else C_BIO2); parts.append(bp)

    # 2 Compound-Augen
    for side, sx in [("L", -1), ("R", 1)]:
        ax, ay, az = sx*0.40, -0.52, 1.20
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.12, segments=12, ring_count=8, location=(ax,ay,az))
        sclera = bpy.context.active_object; sclera.name = f"Eye_Sclera_{side}"; smooth(sclera); vcol(sclera, C_EYE_S); parts.append(sclera)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.07, segments=10, ring_count=6, location=(ax, ay-0.10, az))
        iris = bpy.context.active_object; iris.name = f"Eye_Iris_{side}"; smooth(iris); vcol(iris, C_BIO2); parts.append(iris)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.040, segments=8, ring_count=5, location=(ax, ay-0.14, az))
        pupil = bpy.context.active_object; pupil.name = f"Eye_Pupil_{side}"; smooth(pupil); vcol(pupil, C_EYE_P); parts.append(pupil)
        # Auge-Rim
        bpy.ops.mesh.primitive_torus_add(major_radius=0.13, minor_radius=0.022, major_segments=20, minor_segments=6, location=(ax,ay,az))
        erim = bpy.context.active_object; erim.name = f"Eye_Rim_{side}"; vcol(erim, C_TENT); parts.append(erim)
    # 4 kleine Mantel-Finnen
    for i in range(4):
        a = math.pi/4 + (i/4)*math.tau
        fp = (math.cos(a)*0.65, math.sin(a)*0.65, 1.55)
        ft = (math.cos(a)*0.92, math.sin(a)*0.92, 1.68)
        fin = cone_obj(f"Mantle_Fin_{i}", fp, ft, 0.10, 0.02, 5)
        vcol(fin, C_FIN); parts.append(fin)
    return parts


# ═══════════════════════════════════════════════════════════════
# TENTAKEL
# ═══════════════════════════════════════════════════════════════
def tentacle_pts(phi0, n=14, coil=0.60, z_drop=-0.80, r_start=1.04, r_end=2.40):
    pts = []
    for i in range(n):
        t = i / (n-1)
        r = r_start + (r_end - r_start)*t
        phi = phi0 + coil*math.tau*t
        z = -t * abs(z_drop) + math.sin(t*math.pi)*0.30
        pts.append(Vector((math.cos(phi)*r, math.sin(phi)*r, z)))
    return pts

def create_tentacle(prefix, phi0, coil_dir=1.0, n=14, is_fang=False):
    parts = []
    pts = tentacle_pts(phi0, n=n, coil=0.45*coil_dir, z_drop=-1.20 if not is_fang else -0.40,
                       r_end=2.80 if is_fang else 2.20)
    for i in range(len(pts)-1):
        t = i/(len(pts)-2)
        r = (0.095 - t*0.062) if not is_fang else (0.130 - t*0.080)
        seg = cyl(f"{prefix}_Seg{i:02d}", pts[i], pts[i+1], r, 9)
        vcol(seg, C_TENT if t < 0.5 else C_TENT2); parts.append(seg)

        # Saugnäpfe auf jeder geraden Seite
        if i % 2 == 0:
            mid = (pts[i] + pts[i+1]) * 0.5
            inward = mid.normalized()
            perp = Vector((-inward.y, inward.x, 0)).normalized()
            for si in range(2):
                sp = mid + perp*(r*0.85)*(1 if si==0 else -1)
                bpy.ops.mesh.primitive_cylinder_add(
                    radius=r*0.42, depth=r*0.25, vertices=7, location=sp)
                suck = bpy.context.active_object; suck.name = f"{prefix}_Suck{i}_{si}"
                smooth(suck); vcol(suck, C_SUCKER); parts.append(suck)
                # Saugnapf-Zentrum
                bpy.ops.mesh.primitive_uv_sphere_add(radius=r*0.18, segments=6, ring_count=4, location=sp)
                sc = bpy.context.active_object; sc.name = f"{prefix}_SuckCore{i}_{si}"
                smooth(sc); vcol(sc, C_BIO if i%4==0 else C_TENT); parts.append(sc)

        # Bio-Streifen: glühende Punkte entlang Tentakel
        if i % 3 == 1:
            bpy.ops.mesh.primitive_uv_sphere_add(radius=r*0.25, segments=5, ring_count=4, location=pts[i])
            bio = bpy.context.active_object; bio.name = f"{prefix}_Bio{i}"
            smooth(bio); vcol(bio, C_BIO2 if i%6==1 else C_BIO); parts.append(bio)

    # Spitze: Fang-Klaue oder normales Ende
    tip = pts[-1]
    if is_fang:
        # Fang-Klaue: 3 Klauen-Kegel
        tip_dir = (pts[-1] - pts[-2]).normalized()
        for ci in range(3):
            ca = (ci/3)*math.tau
            claw_tip = tip + tip_dir*0.40 + Vector((math.cos(ca)*0.10, math.sin(ca)*0.10, -0.08))
            clw = cone_obj(f"{prefix}_Claw{ci}", tip, claw_tip, 0.055, 0.006, 5)
            vcol(clw, C_CLAW); parts.append(clw)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.065, segments=8, ring_count=5, location=tip)
        fball = bpy.context.active_object; fball.name = f"{prefix}_TipBall"; smooth(fball); vcol(fball, C_BIO); parts.append(fball)
    else:
        # Normale Spitze: Verjüngter Kegel
        tail_c = cone_obj(f"{prefix}_Tip", pts[-2], pts[-1], 0.030, 0.005, 6)
        vcol(tail_c, C_TENT); parts.append(tail_c)
    return parts


def create_all_tentacles():
    parts = []
    # 8 normale Tentakel gleichmäßig um Äquator
    for i in range(8):
        phi = (i/8)*math.tau
        coil = 1.0 if i%2==0 else -1.0
        parts += create_tentacle(f"Tent_{i}", phi, coil)
    # 2 Fangtentakel (unten, größer)
    parts += create_tentacle("Fang_L", math.pi*0.25, 0.5, n=16, is_fang=True)
    parts += create_tentacle("Fang_R", math.pi*1.25, -0.5, n=16, is_fang=True)
    return parts


# ═══════════════════════════════════════════════════════════════
# TINTENWOLKEN & DEKORATION
# ═══════════════════════════════════════════════════════════════
def create_ink_and_details():
    parts = []
    # 10 Tintenwolken-Kugeln unterhalb der Hauptkugel
    ink_pos = [
        (1.20, 0.60, -1.50), (-1.40, 0.20, -1.35), (0.40, -1.50, -1.60),
        (-0.60, 1.30, -1.45), (1.80, -0.80, -0.90), (-1.70, -0.90, -1.10),
        (0.80, 1.80, -0.80), (-0.30, -1.80, -1.20), (2.10, 0.30, -0.60),
        (-2.00, 0.40, -0.75),
    ]
    for i, pos in enumerate(ink_pos):
        r = 0.12 + (i%3)*0.06
        bpy.ops.mesh.primitive_ico_sphere_add(radius=r, subdivisions=1, location=pos)
        ink = bpy.context.active_object; ink.name = f"Ink_Cloud_{i:02d}"
        smooth(ink); vcol(ink, C_INK if i%2==0 else (0.08,0.06,0.18,1.0)); parts.append(ink)
        # Bio-Glühen in manchen Wolken
        if i % 3 == 0:
            bpy.ops.mesh.primitive_uv_sphere_add(radius=r*0.55, segments=7, ring_count=4, location=pos)
            ig = bpy.context.active_object; ig.name = f"Ink_Glow_{i}"; smooth(ig); vcol(ig, C_BIO); parts.append(ig)

    # Biolumineszenz-Ring um Äquator
    bpy.ops.mesh.primitive_torus_add(major_radius=1.08, minor_radius=0.028, major_segments=64, minor_segments=9, location=(0,0,-0.05))
    bio_ring = bpy.context.active_object; bio_ring.name = "Bio_EquatorRing"; vcol(bio_ring, C_BIO); parts.append(bio_ring)
    # 12 Bio-Leuchtpunkte auf Kugel-Oberfläche
    for i in range(12):
        a = (i/12)*math.tau
        z = math.sin(a*0.5)*0.40
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.032, segments=6, ring_count=4,
            location=(math.cos(a)*1.02, math.sin(a)*1.02, z))
        bp = bpy.context.active_object; bp.name = f"Surface_Bio_{i}"; smooth(bp); vcol(bp, C_BIO2 if i%3==0 else C_BIO); parts.append(bp)
    return parts


clear_scene()
col = bpy.data.collections.new("Aion_AbyssalKraken")
bpy.context.scene.collection.children.link(col)

all_parts = (create_orb_and_mantle()
           + create_all_tentacles()
           + create_ink_and_details())

for obj in all_parts:
    for c in list(obj.users_collection): c.objects.unlink(obj)
    col.objects.link(obj)
print(f"✅ Aion Abyssal Kraken — {len(all_parts)} Teile")
