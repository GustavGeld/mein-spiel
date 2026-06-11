import bpy, bmesh, math
from mathutils import Vector

# ============================================================
# AION  —  OCEAN SPIRIT  |  Roblox-safe FBX
# Kugelförmiger Begleiter: Tiefseekugel mit Korallen-
# formationen, Seeanemone am Nordpol, Muschel-Spirale,
# Blasenringen und biolumineszenten Orbs.
# ============================================================

C_DEEP    = (0.01, 0.06, 0.22, 1.0)  # Tiefsee Blau
C_OCEAN   = (0.04, 0.22, 0.52, 1.0)  # Ozean Blau
C_TEAL    = (0.06, 0.48, 0.58, 1.0)  # Türkis
C_FOAM    = (0.80, 0.90, 0.92, 1.0)  # Meeresschaum
C_CORAL   = (0.80, 0.32, 0.16, 1.0)  # Korallen Orange
C_CORAL2  = (0.90, 0.55, 0.28, 1.0)  # heller Korall
C_PEARL   = (0.94, 0.92, 0.88, 1.0)  # Perlmutt
C_BIO     = (0.10, 0.88, 0.72, 1.0)  # Biolumineszenz Cyan
C_ANEM    = (0.72, 0.18, 0.48, 1.0)  # Anemone Lila
C_KELP    = (0.10, 0.38, 0.18, 1.0)  # Seetang Grün

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

def cone(name, s, e, r1=0.05, r2=0.0, v=8):
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
    smooth(orb); vcol(orb, C_DEEP); parts.append(orb)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.62, segments=32, ring_count=16, location=(0,0,0))
    c1 = bpy.context.active_object; c1.name = "Aion_Core1"
    smooth(c1); vcol(c1, C_OCEAN); parts.append(c1)

    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.32, subdivisions=2, location=(0,0,0))
    c2 = bpy.context.active_object; c2.name = "Aion_Core2"
    smooth(c2); vcol(c2, C_TEAL); parts.append(c2)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.14, segments=10, ring_count=6, location=(0,0,0))
    c3 = bpy.context.active_object; c3.name = "Aion_Nucleus"
    smooth(c3); vcol(c3, C_BIO); parts.append(c3)

    # Wellen-Ringe (5 Breitengrad-Ringe)
    ring_cfg = [
        (0.72, 0.73, 0.018, C_TEAL),
        (0.38, 0.92, 0.025, C_OCEAN),
        (0.00, 1.015, 0.032, C_FOAM),  # Äquator-Schaumring
        (-0.38, 0.92, 0.025, C_OCEAN),
        (-0.72, 0.73, 0.018, C_TEAL),
    ]
    for i, (z, maj, mn, col) in enumerate(ring_cfg):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=maj, minor_radius=mn,
            major_segments=60, minor_segments=10, location=(0,0,z))
        ring = bpy.context.active_object; ring.name = f"Aion_Ring_{i}"
        vcol(ring, col); parts.append(ring)

    # 8 Muschel-Perlen auf Äquator-Ring
    for i in range(8):
        a = (i/8)*math.tau
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.036, segments=7, ring_count=4,
            location=(math.cos(a)*1.02, math.sin(a)*1.02, 0))
        p = bpy.context.active_object; p.name = f"Aion_EqPearl_{i}"
        smooth(p); vcol(p, C_PEARL if i%2==0 else C_FOAM); parts.append(p)

    # 4 Meridian-Bögen (gedrehte Torii als Wellenbögen)
    for i, rz in enumerate([0, math.pi/4, math.pi/2, 3*math.pi/4]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=1.12, minor_radius=0.012,
            major_segments=60, minor_segments=8,
            location=(0,0,0), rotation=(math.pi/2, 0, rz))
        arc = bpy.context.active_object; arc.name = f"Aion_Arc_{i}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(arc, C_TEAL); parts.append(arc)

    # Großer Schwebering (Korallen-orange)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.44, minor_radius=0.022,
        major_segments=80, minor_segments=10, location=(0,0,0))
    halo = bpy.context.active_object; halo.name = "Aion_Halo"
    vcol(halo, C_CORAL); parts.append(halo)

    # 12 Blasen auf großem Ring
    for i in range(12):
        a = (i/12)*math.tau
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.030 + (i%3)*0.008, segments=7, ring_count=4,
            location=(math.cos(a)*1.44, math.sin(a)*1.44, 0))
        b = bpy.context.active_object; b.name = f"Aion_Bubble_{i}"
        smooth(b); vcol(b, C_BIO if i%3==0 else C_FOAM); parts.append(b)

    return parts


# ═══════════════════════════════════════════════════════════════
# KORALLEN-FORMATIONEN
# ═══════════════════════════════════════════════════════════════
def coral_formation(prefix, theta, phi):
    """Verzweigte Koralle aus der Kugeloberfläche."""
    parts = []
    root = sph_pt(theta, phi, 0.98)
    stem_tip = sph_pt(theta, phi, 0.98 + 0.32)

    stem = cyl(f"{prefix}_stem", root, stem_tip, 0.038, 8)
    vcol(stem, C_CORAL); parts.append(stem)

    # 4 Äste am Stamm
    for i in range(4):
        a = (i/4)*math.tau
        dt = 0.22 * math.sin(a)
        dp = 0.22 * math.cos(a)
        branch_r = sph_pt(theta + dt*0.5, phi + dp*0.5, 1.14)
        branch_t = sph_pt(theta + dt, phi + dp, 1.22)
        br = cyl(f"{prefix}_br{i}", branch_r, branch_t, 0.022, 6)
        vcol(br, C_CORAL2 if i%2==0 else C_CORAL); parts.append(br)

        # Ast-Spitze
        tip = sph_pt(theta + dt*1.1, phi + dp*1.1, 1.26)
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.024, segments=6, ring_count=4, location=branch_t)
        t = bpy.context.active_object; t.name = f"{prefix}_tip{i}"
        smooth(t); vcol(t, C_BIO); parts.append(t)

        # Sub-Äste (2 pro Ast)
        for j in range(2):
            sdt = dt + math.sin(j*math.pi + a)*0.10
            sdp = dp + math.cos(j*math.pi + a)*0.10
            sub_s = sph_pt(theta+dt*0.8, phi+dp*0.8, 1.18)
            sub_e = sph_pt(theta+sdt, phi+sdp, 1.28)
            sb = cyl(f"{prefix}_sb{i}_{j}", sub_s, sub_e, 0.012, 5)
            vcol(sb, C_FOAM); parts.append(sb)

    return parts


# ═══════════════════════════════════════════════════════════════
# SEEANEMONE (Nordpol)
# ═══════════════════════════════════════════════════════════════
def create_anemone():
    parts = []

    # Körper-Zylinder am Nordpol
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.18, depth=0.10, vertices=12, location=(0, 0, 0.98))
    body = bpy.context.active_object; body.name = "Aion_AnemBody"
    smooth(body); vcol(body, C_ANEM); parts.append(body)

    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.12, depth=0.06, vertices=12, location=(0, 0, 1.04))
    base = bpy.context.active_object; base.name = "Aion_AnemBase"
    smooth(base); vcol(base, C_DEEP); parts.append(base)

    # Tentakeln (16 Kegel, radial angeordnet)
    for i in range(16):
        a = (i/16)*math.tau
        spread = 0.14 + (i%3)*0.02
        x, y = math.cos(a)*spread, math.sin(a)*spread
        height = 0.22 + (i%4)*0.05
        s = (x*0.5, y*0.5, 1.02)
        e = (x, y, 1.02+height)
        tent = cone(f"Aion_Tent_{i}", s, e, 0.016, 0.004, 6)
        vcol(tent, C_ANEM if i%3!=0 else C_BIO); parts.append(tent)
        # Tentakel-Spitze
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.013, segments=5, ring_count=3, location=e)
        tt = bpy.context.active_object; tt.name = f"Aion_TentTip_{i}"
        smooth(tt); vcol(tt, C_BIO); parts.append(tt)

    # Zentral-Orb der Anemone
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.055, segments=10, ring_count=6, location=(0,0,1.03))
    co = bpy.context.active_object; co.name = "Aion_AnemCenter"
    smooth(co); vcol(co, C_BIO); parts.append(co)

    return parts


# ═══════════════════════════════════════════════════════════════
# MUSCHEL-SPIRALE (Südpol)
# ═══════════════════════════════════════════════════════════════
def create_shell():
    parts = []

    # Muschel-Basis (flache Kegel-Spirale)
    for i in range(12):
        t = i / 11.0
        a = t * math.tau * 1.5   # 1.5 Umdrehungen
        r_shell = 0.10 + t*0.08  # wachsender Radius
        z_shell = -1.05 - t*0.14
        x, y = math.cos(a)*r_shell, math.sin(a)*r_shell
        h = 0.035 + t*0.02
        bpy.ops.mesh.primitive_cone_add(
            vertices=5, radius1=h*1.6, radius2=h*0.4,
            depth=h*2, location=(x, y, z_shell),
            rotation=(a+math.pi/2, 0, a))
        seg = bpy.context.active_object; seg.name = f"Aion_Shell_{i}"
        smooth(seg)
        vcol(seg, C_PEARL if i%3==0 else (C_FOAM if i%3==1 else C_CORAL2))
        parts.append(seg)

    # Perle im Zentrum der Muschel
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.072, segments=10, ring_count=6, location=(0,0,-1.05))
    pearl = bpy.context.active_object; pearl.name = "Aion_Pearl"
    smooth(pearl); vcol(pearl, C_PEARL); parts.append(pearl)

    # Muschel-Stiel
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.14, minor_radius=0.018,
        major_segments=16, minor_segments=6, location=(0,0,-0.92))
    sr = bpy.context.active_object; sr.name = "Aion_ShellRing"
    vcol(sr, C_TEAL); parts.append(sr)

    return parts


# ═══════════════════════════════════════════════════════════════
# SEETANG-RANKEN + BIOLUMINESZENZ
# ═══════════════════════════════════════════════════════════════
def create_kelp_and_bio():
    parts = []

    # 4 Seetang-Ranken (gebogene Zylinderserien)
    kelp_roots = [
        (math.pi*0.55, math.pi*0.10),
        (math.pi*0.60, math.pi*0.60),
        (math.pi*0.50, math.pi*1.20),
        (math.pi*0.58, math.pi*1.80),
    ]
    for ki, (th0, ph0) in enumerate(kelp_roots):
        prev = sph_pt(th0, ph0, 1.01)
        for j in range(6):
            t = (j+1)/6.0
            th = th0 - t*0.30
            ph = ph0 + t*0.25
            r = 1.01 + t*0.28
            curr = sph_pt(th, ph, r)
            seg = cyl(f"Aion_Kelp_{ki}_{j}", prev, curr, 0.018, 5)
            vcol(seg, C_KELP); parts.append(seg)
            prev = curr
            # Kleines Blatt-Oval alle 2 Segmente
            if j % 2 == 1:
                bpy.ops.mesh.primitive_cylinder_add(
                    radius=0.04, depth=0.002, vertices=8, location=curr)
                lf = bpy.context.active_object; lf.name = f"Aion_Leaf_{ki}_{j}"
                lf.rotation_euler = (0, math.pi/2, (j/6)*math.tau)
                vcol(lf, C_KELP); parts.append(lf)

    # 8 Biolumineszenz-Orbs (schweben um die Kugel)
    bio_pos = [
        ( 1.38, 0.10, 0.45), (-1.35,-0.08, 0.40),
        ( 0.62,-0.12,-0.80), (-0.68, 0.10, 0.78),
        ( 1.15,-0.06,-0.32), (-1.08, 0.08, 0.28),
        ( 0.48,-0.14, 1.08), (-0.55, 0.16,-0.72),
    ]
    for i, pos in enumerate(bio_pos):
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.048 + (i%3)*0.012, segments=8, ring_count=5, location=pos)
        orb = bpy.context.active_object; orb.name = f"Aion_Bio_{i}"
        smooth(orb); vcol(orb, C_BIO); parts.append(orb)
        # Inneres Glühen
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.022, segments=6, ring_count=4, location=pos)
        inner = bpy.context.active_object; inner.name = f"Aion_BioCore_{i}"
        smooth(inner); vcol(inner, C_FOAM); parts.append(inner)

    # 6 schwebende Blasen (größer)
    bubble_pos = [
        ( 1.60,-0.10, 0.18), (-1.55, 0.06, 0.22),
        ( 0.40,-0.08,-1.00), ( 0.55, 0.08, 0.98),
        (-0.92,-0.06,-0.62), ( 0.88, 0.12, 0.60),
    ]
    for i, pos in enumerate(bubble_pos):
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.065, segments=10, ring_count=6, location=pos)
        bl = bpy.context.active_object; bl.name = f"Aion_BigBubble_{i}"
        smooth(bl); vcol(bl, C_FOAM); parts.append(bl)
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.030, segments=6, ring_count=4, location=pos)
        bi = bpy.context.active_object; bi.name = f"Aion_BubbleInner_{i}"
        smooth(bi); vcol(bi, C_BIO); parts.append(bi)

    return parts


# ═══════════════════════════════════════════════════════════════
# AURA — Meereswellen-Energiefeld
# ═══════════════════════════════════════════════════════════════
def create_aura():
    parts = []
    # Wasser-Aura-Hülle (glänzend-blaue Schale)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=1.58, subdivisions=1, location=(0,0,0))
    shell = bpy.context.active_object; shell.name = "Aura_Shell"
    vcol(shell, (0.02, 0.12, 0.30, 1.0)); parts.append(shell)
    # Innerer Biolumineszenz-Ring
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.52, minor_radius=0.022,
        major_segments=60, minor_segments=8, location=(0,0,0))
    igr = bpy.context.active_object; igr.name = "Aura_InnerRing"
    vcol(igr, C_BIO); parts.append(igr)
    # 3 Orbit-Ringe: Wellenmuster
    for i, (rx, rz, mr, col) in enumerate([
        (0.0,       0.0,        1.80, C_TEAL),
        (math.pi/2, 0.0,        1.76, C_OCEAN),
        (math.pi/2, math.pi/3,  1.72, C_BIO),
    ]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=mr, minor_radius=0.016,
            major_segments=64, minor_segments=8,
            location=(0,0,0), rotation=(rx, 0, rz))
        r = bpy.context.active_object; r.name = f"Aura_Ring_{i}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(r, col); parts.append(r)
    # Blasen-Partikelwolke (14 schwebende Blasen)
    for i in range(14):
        a = (i / 14) * math.tau
        h = math.sin(i * 1.1) * 0.46
        rd = 1.84 + (i % 3) * 0.07
        pos = (math.cos(a)*rd*math.cos(h), math.sin(a)*rd*math.cos(h), rd*math.sin(h))
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.030 + (i%3)*0.010, segments=6, ring_count=3, location=pos)
        p = bpy.context.active_object; p.name = f"Aura_Bubble_{i}"
        smooth(p); vcol(p, C_FOAM if i%2==0 else C_BIO); parts.append(p)
    # 6 Wasser-Tropfen (Teardrop: Kugel + spitzer Kegel)
    for i in range(6):
        a = (i / 6) * math.tau
        elev = math.pi / 5 * (1 if i%2==0 else -1)
        r1, r2 = 1.66, 2.04
        cx, cy = math.cos(a), math.sin(a)
        ce, se = math.cos(elev), math.sin(elev)
        drop_base = (cx*r1*ce, cy*r1*ce, r1*se)
        drop_tip  = (cx*r2*ce, cy*r2*ce, r2*se)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.055, segments=7, ring_count=5, location=drop_base)
        db = bpy.context.active_object; db.name = f"Aura_DropBase_{i}"
        smooth(db); vcol(db, C_TEAL); parts.append(db)
        td = cone(f"Aura_DropTip_{i}", drop_base, drop_tip, 0.040, 0.002, 5)
        vcol(td, C_BIO); parts.append(td)
    return parts


clear_scene()
col = bpy.data.collections.new("Aion_OceanSpirit")
bpy.context.scene.collection.children.link(col)

all_parts = (create_orb()
    + coral_formation("Coral_N", math.pi/2, 0.0)
    + coral_formation("Coral_E", math.pi/2, math.pi/2)
    + coral_formation("Coral_S_eq", math.pi/2, math.pi)
    + coral_formation("Coral_W", math.pi/2, 3*math.pi/2)
    + create_anemone()
    + create_shell()
    + create_kelp_and_bio()
    + create_aura())

for obj in all_parts:
    for c in list(obj.users_collection): c.objects.unlink(obj)
    col.objects.link(obj)
print(f"✅ Aion Ocean Spirit — {len(all_parts)} Teile")
