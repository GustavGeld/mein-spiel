import bpy, bmesh, math
from mathutils import Vector

# ============================================================
# AION  —  NECROMANCER ORB  |  Roblox-safe FBX
# Kugelförmiger Begleiter: Dunkel-Knochenorb umhüllt von
# Knochensegmenten, Schädel-Krone am Nordpol, Todesenergie-
# Ranken, Kettendekorationen und Seelen-Orbs.
# ============================================================

C_DARK    = (0.06, 0.06, 0.05, 1.0)  # Tiefschwarz
C_BONE    = (0.72, 0.68, 0.56, 1.0)  # Knochen Elfenbein
C_SKULL   = (0.80, 0.76, 0.62, 1.0)  # Schädel Weiß
C_DECAY   = (0.15, 0.20, 0.08, 1.0)  # Verfall Grün
C_SOUL    = (0.22, 0.72, 0.28, 1.0)  # Seelen Grün
C_SOUL2   = (0.50, 0.90, 0.50, 1.0)  # Helles Seelen-Grün
C_CHAIN   = (0.28, 0.24, 0.20, 1.0)  # Eisenkette
C_SHADOW  = (0.10, 0.08, 0.12, 1.0)  # Schatten Lila
C_BLOOD   = (0.45, 0.05, 0.05, 1.0)  # Dunkelrot Akzent

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
    smooth(orb); vcol(orb, C_DARK); parts.append(orb)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.63, segments=32, ring_count=16, location=(0,0,0))
    c1 = bpy.context.active_object; c1.name = "Aion_Core1"
    smooth(c1); vcol(c1, C_SHADOW); parts.append(c1)

    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.34, subdivisions=2, location=(0,0,0))
    c2 = bpy.context.active_object; c2.name = "Aion_Core2"
    smooth(c2); vcol(c2, C_DECAY); parts.append(c2)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.16, segments=10, ring_count=6, location=(0,0,0))
    c3 = bpy.context.active_object; c3.name = "Aion_Nucleus"
    smooth(c3); vcol(c3, C_SOUL); parts.append(c3)

    # 3 Knochen-Breiten-Ringe
    for i, (z, maj, mn, col) in enumerate([
        (0.62, 0.78, 0.022, C_BONE),
        (0.00, 1.01, 0.030, C_CHAIN),
        (-0.62, 0.78, 0.022, C_BONE),
    ]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=maj, minor_radius=mn,
            major_segments=56, minor_segments=10, location=(0,0,z))
        ring = bpy.context.active_object; ring.name = f"Aion_Ring_{i}"
        vcol(ring, col); parts.append(ring)

    # 8 Totenkopf-Nieten auf Äquator-Ring
    for i in range(8):
        a = (i/8)*math.tau
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.040, segments=7, ring_count=4,
            location=(math.cos(a)*1.02, math.sin(a)*1.02, 0))
        s = bpy.context.active_object; s.name = f"Aion_Rivet_{i}"
        smooth(s); vcol(s, C_SKULL if i%2==0 else C_BONE); parts.append(s)

    # 4 Knochen-Bögen (Meridiane)
    for i, rz in enumerate([0, math.pi/4, math.pi/2, 3*math.pi/4]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=1.12, minor_radius=0.015,
            major_segments=64, minor_segments=8,
            location=(0,0,0), rotation=(math.pi/2, 0, rz))
        arc = bpy.context.active_object; arc.name = f"Aion_Arc_{i}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(arc, C_SHADOW); parts.append(arc)

    # Großer Schwebering (Knochen-Ring)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.44, minor_radius=0.028,
        major_segments=80, minor_segments=12, location=(0,0,0))
    halo = bpy.context.active_object; halo.name = "Aion_Halo"
    vcol(halo, C_BONE); parts.append(halo)

    # 12 Totenkopf-Fragmente auf Ring (kleine Ico-Spheren)
    for i in range(12):
        a = (i/12)*math.tau
        bpy.ops.mesh.primitive_ico_sphere_add(
            radius=0.035, subdivisions=1,
            location=(math.cos(a)*1.44, math.sin(a)*1.44, 0))
        b = bpy.context.active_object; b.name = f"Aion_SkullFrag_{i}"
        vcol(b, C_SKULL if i%3==0 else (C_BONE if i%3==1 else C_SOUL)); parts.append(b)

    return parts


# ═══════════════════════════════════════════════════════════════
# KNOCHENSEGMENTE (Wirbel um die Kugel)
# ═══════════════════════════════════════════════════════════════
def bone_segment(prefix, theta, phi):
    """Knochen-Segment: Schaft + 2 Gelenk-Verdickungen."""
    parts = []
    s = sph_pt(theta, phi, 1.01)
    mid = sph_pt(theta, phi, 1.14)
    e = sph_pt(theta, phi, 1.27)

    shaft = cyl(f"{prefix}_shaft", s, e, 0.028, 8)
    vcol(shaft, C_BONE); parts.append(shaft)

    for jname, jpos, jr in [(f"{prefix}_j0", s, 0.042), (f"{prefix}_j1", mid, 0.035), (f"{prefix}_j2", e, 0.042)]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=jr, segments=8, ring_count=5, location=jpos)
        j = bpy.context.active_object; j.name = jname
        smooth(j); vcol(j, C_SKULL); parts.append(j)

    return parts

def create_bones():
    parts = []
    # 16 Knochen-Segmente auf zwei Breitengraden
    for ring_z, ring_theta in [(0.42, math.pi*0.42), (0.72, math.pi*0.72)]:
        n = 8
        for i in range(n):
            ph = (i/n)*math.tau
            parts += bone_segment(f"Bone_{int(ring_z*100)}_{i}", ring_theta, ph)

    # 4 Längs-Knochen (Meridian-Paare)
    for ph in [0, math.pi/2, math.pi, 3*math.pi/2]:
        s = sph_pt(math.pi*0.22, ph, 1.01)
        e = sph_pt(math.pi*0.78, ph, 1.01)
        rib = cyl(f"Rib_{int(ph*10)}", s, e, 0.022, 7)
        vcol(rib, C_BONE); parts.append(rib)

        # Gelenk-Knoten am Rib
        for t in [0.25, 0.5, 0.75]:
            jx = s[0]*(1-t) + e[0]*t
            jy = s[1]*(1-t) + e[1]*t
            jz = s[2]*(1-t) + e[2]*t
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.030, segments=6, ring_count=4, location=(jx,jy,jz))
            jt = bpy.context.active_object; jt.name = f"Rib_Joint_{int(ph*10)}_{int(t*10)}"
            smooth(jt); vcol(jt, C_SKULL); parts.append(jt)

    return parts


# ═══════════════════════════════════════════════════════════════
# SCHÄDEL-KRONE (Nordpol)
# ═══════════════════════════════════════════════════════════════
def create_skull_crown():
    parts = []

    # Kronen-Sockel
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.26, depth=0.07, vertices=14, location=(0,0,0.91))
    base = bpy.context.active_object; base.name = "Aion_SkullBase"
    smooth(base); vcol(base, C_SHADOW); parts.append(base)

    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.24, minor_radius=0.022,
        major_segments=20, minor_segments=8, location=(0,0,0.94))
    br = bpy.context.active_object; br.name = "Aion_SkullBaseRing"
    vcol(br, C_BONE); parts.append(br)

    # Haupt-Schädel (Cranium)
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.18, segments=14, ring_count=8, location=(0,0,1.14))
    cranium = bpy.context.active_object; cranium.name = "Aion_Cranium"
    smooth(cranium); vcol(cranium, C_SKULL); parts.append(cranium)

    # Augenhöhlen (2 dunkle Kugeln eingebettet)
    for sx in [-0.07, 0.07]:
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.055, segments=8, ring_count=5,
            location=(sx, -0.14, 1.12))
        eye = bpy.context.active_object; eye.name = f"Aion_EyeSocket_{'L' if sx<0 else 'R'}"
        smooth(eye); vcol(eye, C_DARK); parts.append(eye)
        # Glühende Augen
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.030, segments=6, ring_count=4,
            location=(sx, -0.15, 1.12))
        eg = bpy.context.active_object; eg.name = f"Aion_EyeGlow_{'L' if sx<0 else 'R'}"
        smooth(eg); vcol(eg, C_SOUL2); parts.append(eg)

    # Kieferknochen
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.13, depth=0.04, vertices=10, location=(0,0,0.97))
    jaw = bpy.context.active_object; jaw.name = "Aion_Jaw"
    smooth(jaw); vcol(jaw, C_SKULL); parts.append(jaw)

    # 6 Zähne am Kiefer
    for i in range(6):
        a = (i/6)*math.tau - math.pi/12
        tx, ty = math.cos(a)*0.12, math.sin(a)*0.12
        bpy.ops.mesh.primitive_cone_add(
            vertices=4, radius1=0.016, depth=0.042,
            location=(tx, ty, 0.94), rotation=(0, 0, a))
        tooth = bpy.context.active_object; tooth.name = f"Aion_Tooth_{i}"
        smooth(tooth); vcol(tooth, C_BONE); parts.append(tooth)

    # 3 Knochen-Spitzen auf der Krone (Schädelkrone)
    for i in range(3):
        a = (i/3)*math.tau
        cx, cy = math.cos(a)*0.16, math.sin(a)*0.16
        s = (cx, cy, 1.24)
        e = (cx*0.7, cy*0.7, 1.44)
        sp = cone(f"Aion_CrownBone_{i}", s, e, 0.020, 0.002, 5)
        vcol(sp, C_BONE); parts.append(sp)
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.018, segments=5, ring_count=3, location=e)
        ct = bpy.context.active_object; ct.name = f"Aion_CrownBoneTip_{i}"
        smooth(ct); vcol(ct, C_SOUL); parts.append(ct)

    # Südpol: Seelen-Kristall-Anhänger
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.17, minor_radius=0.020,
        major_segments=16, minor_segments=6, location=(0,0,-0.90))
    southr = bpy.context.active_object; southr.name = "Aion_SouthRing"
    vcol(southr, C_CHAIN); parts.append(southr)

    cone("Aion_SoulCrystal", (0,0,-0.98), (0,0,-1.25), 0.055, 0.002, 6)
    sc = bpy.context.active_object
    vcol(sc, C_SHADOW); parts.append(sc)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.040, segments=8, ring_count=5, location=(0,0,-1.26))
    sct = bpy.context.active_object; sct.name = "Aion_SoulTip"
    smooth(sct); vcol(sct, C_SOUL2); parts.append(sct)

    return parts


# ═══════════════════════════════════════════════════════════════
# KETTEN-DEKORATION
# ═══════════════════════════════════════════════════════════════
def create_chains():
    parts = []
    # 2 Ketten-Stränge: Reihen von Torus-Kettengliedern
    chain_paths = [
        [(0.60,0.30),(0.90,0.55),(1.20,0.72),(1.50,0.85),(1.75,0.92)],
        [(0.55,3.50),(0.88,3.70),(1.18,3.88),(1.48,4.00),(1.72,4.10)],
    ]
    for ci, path in enumerate(chain_paths):
        pts = [sph_pt(th, ph, 1.08) for th, ph in path]
        for i in range(len(pts)-1):
            mid_pt = ((pts[i][0]+pts[i+1][0])/2,
                      (pts[i][1]+pts[i+1][1])/2,
                      (pts[i][2]+pts[i+1][2])/2)
            # Kettenglied als kleiner Torus
            link_vec = Vector(pts[i+1]) - Vector(pts[i])
            bpy.ops.mesh.primitive_torus_add(
                major_radius=0.028, minor_radius=0.007,
                major_segments=10, minor_segments=5,
                location=mid_pt)
            link = bpy.context.active_object; link.name = f"Chain_{ci}_{i}"
            link.rotation_mode = 'QUATERNION'
            link.rotation_quaternion = link_vec.normalized().to_track_quat('Z','Y')
            bpy.ops.object.transform_apply(rotation=True)
            vcol(link, C_CHAIN); parts.append(link)

    # Schwebende Knochen-Fragmente
    frag_cfg = [
        (( 1.36,-0.08, 0.62),(0.4,2.0,0.14),(0.3, 0, 0.6)),
        ((-1.30, 0.06, 0.58),(0.4,1.8,0.12),(-0.2,0,-0.5)),
        (( 0.68,-0.10,-0.82),(0.3,1.6,0.12),(0.5,0.1,0.4)),
        ((-0.75, 0.12, 0.88),(0.4,1.5,0.13),(-0.4,0,-0.4)),
        (( 1.10,-0.06,-0.40),(0.3,1.4,0.11),(0.2,0, 0.5)),
        ((-1.02, 0.08, 0.36),(0.3,1.6,0.11),(-0.3,0,-0.4)),
    ]
    for i, (pos, sc, rot) in enumerate(frag_cfg):
        bpy.ops.mesh.primitive_cube_add(
            size=0.10, scale=sc, location=pos, rotation=rot)
        fr = bpy.context.active_object; fr.name = f"Aion_BoneFrag_{i}"
        vcol(fr, C_BONE if i%2==0 else C_SKULL); parts.append(fr)

    return parts


# ═══════════════════════════════════════════════════════════════
# SEELEN-ORBS
# ═══════════════════════════════════════════════════════════════
def create_souls():
    parts = []
    soul_pos = [
        ( 1.50,-0.10, 0.30), (-1.45, 0.08, 0.28),
        ( 0.55,-0.12,-0.95), (-0.62, 0.14, 0.92),
        ( 1.18,-0.06,-0.45), (-1.10, 0.08, 0.40),
        ( 0.42,-0.10, 1.18), (-0.50, 0.12,-0.82),
    ]
    for i, pos in enumerate(soul_pos):
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.045 + (i%3)*0.010, segments=8, ring_count=5, location=pos)
        orb = bpy.context.active_object; orb.name = f"Aion_Soul_{i}"
        smooth(orb); vcol(orb, C_SOUL); parts.append(orb)
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.020, segments=6, ring_count=4, location=pos)
        inner = bpy.context.active_object; inner.name = f"Aion_SoulCore_{i}"
        smooth(inner); vcol(inner, C_SOUL2); parts.append(inner)

    # Todesenergie-Ranken (dünne Tentakel)
    tendrils = [
        [(0.65,0.60),(0.82,0.88),(0.98,1.10),(1.12,1.28)],
        [(0.70,2.80),(0.88,3.05),(1.05,3.22),(1.20,3.38)],
        [(1.20,5.20),(1.38,5.40),(1.55,5.55),(1.68,5.65)],
    ]
    for ti, path in enumerate(tendrils):
        pts = [sph_pt(th, ph, 1.02 + j*0.06) for j, (th, ph) in enumerate(path)]
        for j in range(len(pts)-1):
            seg = cyl(f"Tendril_{ti}_{j}", pts[j], pts[j+1], 0.012, 5)
            vcol(seg, C_DECAY if j%2==0 else C_SOUL); parts.append(seg)

    return parts


# ═══════════════════════════════════════════════════════════════
# AURA — Todesenergie-Feld
# ═══════════════════════════════════════════════════════════════
def create_aura():
    parts = []
    # Nekro-Aura-Hülle (dunkle Schattenform)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=1.58, subdivisions=1, location=(0,0,0))
    shell = bpy.context.active_object; shell.name = "Aura_Shell"
    vcol(shell, C_SHADOW); parts.append(shell)
    # Innerer Seelen-Ring
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.52, minor_radius=0.022,
        major_segments=60, minor_segments=8, location=(0,0,0))
    igr = bpy.context.active_object; igr.name = "Aura_InnerRing"
    vcol(igr, C_SOUL); parts.append(igr)
    # 3 Orbit-Ringe: Knochen/Seelen-Zirkel
    for i, (rx, rz, mr, col) in enumerate([
        (0.0,       0.0,        1.80, C_BONE),
        (math.pi/2, 0.0,        1.76, C_SOUL),
        (math.pi/2, math.pi/3,  1.72, C_CHAIN),
    ]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=mr, minor_radius=0.016,
            major_segments=64, minor_segments=8,
            location=(0,0,0), rotation=(rx, 0, rz))
        r = bpy.context.active_object; r.name = f"Aura_Ring_{i}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(r, col); parts.append(r)
    # Seelen-Partikelwolke (14 schwebende Seelenlichter)
    for i in range(14):
        a = (i / 14) * math.tau
        h = math.sin(i * 1.1) * 0.46
        rd = 1.84 + (i % 3) * 0.07
        pos = (math.cos(a)*rd*math.cos(h), math.sin(a)*rd*math.cos(h), rd*math.sin(h))
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.026 + (i%3)*0.009, segments=6, ring_count=3, location=pos)
        p = bpy.context.active_object; p.name = f"Aura_Soul_{i}"
        smooth(p); vcol(p, C_SOUL if i%2==0 else C_SOUL2); parts.append(p)
    # 6 Todesenergie-Ranken (Schattentendrile nach außen)
    for i in range(6):
        a = (i / 6) * math.tau
        elev = math.pi / 5 * (1 if i%2==0 else -1)
        r1, r2 = 1.64, 2.05
        cx, cy = math.cos(a), math.sin(a)
        ce, se = math.cos(elev), math.sin(elev)
        t = cone(f"Aura_Tendril_{i}",
                 (cx*r1*ce, cy*r1*ce, r1*se),
                 (cx*r2*ce, cy*r2*ce, r2*se),
                 0.022, 0.002, 5)
        vcol(t, C_DECAY if i%2==0 else C_SOUL); parts.append(t)
    # 6 schwebende Knochen-Splitter
    for i in range(6):
        a = (i / 6) * math.tau + math.pi/6
        rd = 2.02 + (i%2)*0.08
        pos = (math.cos(a)*rd*0.86, math.sin(a)*rd*0.86, math.sin(i*1.2)*0.40)
        bpy.ops.mesh.primitive_cube_add(
            size=0.07, scale=(0.4, 1.8, 0.3), location=pos, rotation=(i*0.6, 0, a))
        fr = bpy.context.active_object; fr.name = f"Aura_BoneFrag_{i}"
        vcol(fr, C_BONE if i%2==0 else C_SKULL); parts.append(fr)
    return parts


clear_scene()
col = bpy.data.collections.new("Aion_NecroOrb")
bpy.context.scene.collection.children.link(col)

all_parts = (create_orb()
    + create_bones()
    + create_skull_crown()
    + create_chains()
    + create_souls()
    + create_aura())

for obj in all_parts:
    for c in list(obj.users_collection): c.objects.unlink(obj)
    col.objects.link(obj)
print(f"✅ Aion Necromancer Orb — {len(all_parts)} Teile")
