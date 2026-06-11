import bpy, bmesh, math
from mathutils import Vector

# ============================================================
# AION  —  VOID PHANTOM  |  Roblox-safe FBX
# Körper: dekorierte Void-Kugel (wie Ra-Kern / God Orb)
# Flügel: detaillierte Phantom-Fledermausflügel (animierbar)
# Vertex Colors / domain='CORNER'
# ============================================================

# ── Palette ──────────────────────────────────────────────────
C_VOID   = (0.03, 0.01, 0.07, 1.0)   # tiefster Void
C_BODY   = (0.06, 0.02, 0.12, 1.0)   # Kugel-Hauptfarbe
C_MID    = (0.14, 0.05, 0.22, 1.0)   # mittleres Lila
C_CYAN   = (0.02, 0.82, 0.95, 1.0)   # Cyan-Glühen (Ringe, Runen)
C_BRIGHT = (0.20, 1.00, 1.00, 1.0)   # helles Cyan (Kern)
C_GOLD   = (0.60, 0.40, 0.05, 1.0)   # Gold-Akzent (Krone)
C_BONE   = (0.80, 0.78, 0.68, 1.0)   # Knochen (Flügel-Struktur)
C_CLAW   = (0.90, 0.88, 0.78, 1.0)   # Klauen
C_WMEM   = (0.04, 0.01, 0.09, 1.0)   # Flügelmembran dunkel
C_WMEM2  = (0.08, 0.02, 0.16, 1.0)   # Membran innen

# ── Helfer ────────────────────────────────────────────────────
def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for col in list(bpy.data.collections):
        bpy.data.collections.remove(col)

def vcol(obj, color):
    if obj.type != 'MESH':
        return
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

def membrane(name, verts, thick=0.025):
    mesh = bpy.data.meshes.new(name)
    obj  = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    top = [bm.verts.new((v[0], v[1]+thick, v[2])) for v in verts]
    bot = [bm.verts.new((v[0], v[1]-thick, v[2])) for v in verts]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    n = len(top)
    for i in range(n):
        j = (i+1)%n
        bm.faces.new([top[i], top[j], bot[j], bot[i]])
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    smooth(obj)
    return obj

# ═══════════════════════════════════════════════════════════════
# KUGEL-KÖRPER
# ═══════════════════════════════════════════════════════════════
def create_orb():
    parts = []

    # ── Hauptkugel ──────────────────────────────────────────
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=1.0, segments=64, ring_count=32, location=(0,0,0))
    orb = bpy.context.active_object
    orb.name = "Aion_Orb"
    smooth(orb)
    vcol(orb, C_BODY)
    parts.append(orb)

    # Innenkern (glühend cyan)
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.62, segments=32, ring_count=16, location=(0,0,0))
    core = bpy.context.active_object
    core.name = "Aion_Orb_Core"
    smooth(core)
    vcol(core, C_MID)
    parts.append(core)

    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.38, segments=20, ring_count=10, location=(0,0,0))
    core2 = bpy.context.active_object
    core2.name = "Aion_Orb_Core_Inner"
    smooth(core2)
    vcol(core2, C_CYAN)
    parts.append(core2)

    # ── 5 Breitengrad-Ringe ──────────────────────────────────
    ring_cfg = [
        (0.75, 0.66,  0.018),  # oben
        (0.38, 0.92,  0.022),
        (0.00, 1.015, 0.030),  # Äquator (dicker)
        (-0.38, 0.92, 0.022),
        (-0.75, 0.66, 0.018),  # unten
    ]
    for i, (z, maj_r, min_r) in enumerate(ring_cfg):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=maj_r, minor_radius=min_r,
            major_segments=64, minor_segments=12, location=(0,0,z))
        ring = bpy.context.active_object
        ring.name = f"Aion_Ring_{i}"
        vcol(ring, C_CYAN if i == 2 else C_MID)
        parts.append(ring)

    # ── 8 Längengrad-Rillen ──────────────────────────────────
    for i in range(8):
        a = (i/8) * math.tau
        bpy.ops.mesh.primitive_cube_add(
            size=1, scale=(0.022, 0.022, 1.88),
            location=(math.cos(a)*1.02, math.sin(a)*1.02, 0),
            rotation=(0, 0, a))
        groove = bpy.context.active_object
        groove.name = f"Aion_Groove_{i}"
        vcol(groove, C_CYAN)
        parts.append(groove)

    # ── 8 Äquator-Panels (Rauten + Kristalle) ────────────────
    for i in range(8):
        a = (i/8) * math.tau
        x, y = math.cos(a)*1.02, math.sin(a)*1.02
        # Dunkle Trägerplatte
        bpy.ops.mesh.primitive_cube_add(
            size=1, scale=(0.07, 0.32, 0.32),
            location=(x, y, 0), rotation=(0, math.pi/4, a))
        plate = bpy.context.active_object
        plate.name = f"Aion_Panel_{i}"
        vcol(plate, C_MID)
        parts.append(plate)
        # Cyan-Kristall
        bpy.ops.mesh.primitive_cone_add(
            vertices=4, radius1=0.10, depth=0.22,
            location=(x*1.04, y*1.04, 0), rotation=(0, math.pi/2, a))
        gem = bpy.context.active_object
        gem.name = f"Aion_Gem_{i}"
        smooth(gem)
        vcol(gem, C_BRIGHT)
        parts.append(gem)

    # ── Nordpol-Krone ────────────────────────────────────────
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.32, minor_radius=0.032,
        major_segments=32, minor_segments=8, location=(0,0,0.88))
    crown_base = bpy.context.active_object
    crown_base.name = "Aion_Crown_Ring"
    vcol(crown_base, C_MID)
    parts.append(crown_base)

    # 6 Kronenzacken (abwechselnd groß/klein, dunkel mit Cyan-Spitze)
    for i in range(6):
        a = (i/6) * math.tau
        sx, sy = math.sin(a)*0.30, math.cos(a)*0.30
        is_tall = (i % 2 == 0)
        h = 0.44 if is_tall else 0.22
        spike = cone(f"Aion_Crown_{i}",
                     (sx, sy, 0.95), (sx*1.08, sy*1.08, 0.95+h),
                     0.055 if is_tall else 0.035, 0.0, 8)
        vcol(spike, C_MID)
        parts.append(spike)
        # Leuchtende Spitze
        tip_glow = cone(f"Aion_Crown_{i}_Tip",
                        (sx*1.08, sy*1.08, 0.95+h*0.7),
                        (sx*1.09, sy*1.09, 0.95+h+0.06),
                        0.030 if is_tall else 0.018, 0.0, 6)
        vcol(tip_glow, C_CYAN)
        parts.append(tip_glow)

    # Pol-Kappe (Zylinder + Kristall oben)
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.18, depth=0.08, vertices=16, location=(0,0,0.96))
    cap = bpy.context.active_object
    cap.name = "Aion_North_Cap"
    smooth(cap)
    vcol(cap, C_MID)
    parts.append(cap)

    bpy.ops.mesh.primitive_ico_sphere_add(
        radius=0.10, subdivisions=2, location=(0,0,1.06))
    cap_gem = bpy.context.active_object
    cap_gem.name = "Aion_North_Gem"
    smooth(cap_gem)
    vcol(cap_gem, C_BRIGHT)
    parts.append(cap_gem)

    # ── Südpol-Anhänger ──────────────────────────────────────
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.22, minor_radius=0.025,
        major_segments=24, minor_segments=8, location=(0,0,-0.88))
    south_ring = bpy.context.active_object
    south_ring.name = "Aion_South_Ring"
    vcol(south_ring, C_MID)
    parts.append(south_ring)

    bpy.ops.mesh.primitive_cone_add(
        vertices=6, radius1=0.14, depth=0.46,
        location=(0,0,-1.22), rotation=(math.pi,0,0))
    pendant = bpy.context.active_object
    pendant.name = "Aion_Pendant"
    smooth(pendant)
    vcol(pendant, C_CYAN)
    parts.append(pendant)

    # ── Großer Schwebering (Äquator) ─────────────────────────
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.38, minor_radius=0.035,
        major_segments=80, minor_segments=16, location=(0,0,0))
    halo = bpy.context.active_object
    halo.name = "Aion_Halo"
    vcol(halo, C_CYAN)
    parts.append(halo)

    # 12 Energie-Perlen auf dem Ring
    for i in range(12):
        a = (i/12) * math.tau
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.048, segments=8, ring_count=6,
            location=(math.cos(a)*1.38, math.sin(a)*1.38, 0))
        bead = bpy.context.active_object
        bead.name = f"Aion_Bead_{i}"
        smooth(bead)
        vcol(bead, C_BRIGHT if i%2==0 else C_CYAN)
        parts.append(bead)

    # ── 3 Diagonale Energie-Bögen ────────────────────────────
    for i, rot_z in enumerate([0.0, math.tau/3, 2*math.tau/3]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=1.30, minor_radius=0.018,
            major_segments=80, minor_segments=8,
            location=(0,0,0), rotation=(math.pi/2, 0, rot_z))
        arc = bpy.context.active_object
        arc.name = f"Aion_Arc_{i}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(arc, C_MID)
        parts.append(arc)

    return parts


# ═══════════════════════════════════════════════════════════════
# PHANTOM-FLÜGEL  (animierbar — jedes Teil ein eigenes Objekt)
# ═══════════════════════════════════════════════════════════════
def create_phantom_wing(side="L"):
    m = 1 if side == "L" else -1
    parts = []
    def p(x,y,z): return (x*m, y, z)

    # Gelenk-Positionen (an Kugel befestigt, dann nach außen)
    attach   = p(1.04, 0.0,  0.00)
    shoulder = p(1.40, 0.0,  0.05)
    elbow    = p(2.80,-0.14, 0.40)
    wrist    = p(4.15,-0.28, 0.15)

    # Schulter-Verbinder
    sh = cyl(f"Aion_Wing_{side}_Shoulder", attach, shoulder, 0.095, 10)
    vcol(sh, C_MID); parts.append(sh)

    # Oberarm
    ua = cyl(f"Aion_Wing_{side}_UpperArm", shoulder, elbow, 0.082, 10)
    vcol(ua, C_MID); parts.append(ua)

    # Unterarm
    fa = cyl(f"Aion_Wing_{side}_Forearm", elbow, wrist, 0.065, 10)
    vcol(fa, C_BODY); parts.append(fa)

    # Ellbogen-Gelenk
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.075, segments=10, ring_count=5, location=elbow)
    ej = bpy.context.active_object; ej.name = f"Aion_Wing_{side}_ElbowJoint"
    smooth(ej); vcol(ej, C_MID); parts.append(ej)

    # Ellbogen-Stachel
    es = cone(f"Aion_Wing_{side}_ElbowSpike",
              elbow, p(elbow[0]*0.95, elbow[1]-0.26, elbow[2]+0.30),
              0.038, 0.0, 8)
    vcol(es, C_BONE); parts.append(es)

    # Handgelenk-Gelenk
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.065, segments=10, ring_count=5, location=wrist)
    wj = bpy.context.active_object; wj.name = f"Aion_Wing_{side}_WristJoint"
    smooth(wj); vcol(wj, C_BODY); parts.append(wj)

    # ── 5 Finger + Klauen ───────────────────────────────────
    finger_tips = [
        p(5.60,-0.34, 2.80),  # Finger 0 (oben)
        p(6.30,-0.32, 1.75),  # Finger 1
        p(6.10,-0.28, 0.62),  # Finger 2
        p(5.45,-0.22,-0.52),  # Finger 3
        p(4.50,-0.15,-1.38),  # Finger 4 (unten)
    ]
    claw_ends = [
        p(6.08,-0.38, 3.26),
        p(6.90,-0.36, 2.02),
        p(6.72,-0.32, 0.42),
        p(6.02,-0.26,-0.88),
        p(4.95,-0.18,-1.78),
    ]
    f_radii = [0.055, 0.052, 0.048, 0.044, 0.040]

    for fi, (ftip, ctip, fr) in enumerate(zip(finger_tips, claw_ends, f_radii)):
        fmid = (
            wrist[0]*0.42 + ftip[0]*0.58,
            wrist[1]*0.5  + ftip[1]*0.5,
            wrist[2]*0.44 + ftip[2]*0.56,
        )
        s1 = cyl(f"Aion_Wing_{side}_F{fi}_Prox", wrist, fmid, fr, 8)
        vcol(s1, C_BODY); parts.append(s1)

        s2 = cyl(f"Aion_Wing_{side}_F{fi}_Dist", fmid, ftip, fr*0.74, 8)
        vcol(s2, C_BODY); parts.append(s2)

        kn = cyl.__class__  # just use sphere
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=fr*0.86, segments=8, ring_count=4, location=fmid)
        kn = bpy.context.active_object; kn.name = f"Aion_Wing_{side}_F{fi}_Knuckle"
        smooth(kn); vcol(kn, C_MID); parts.append(kn)

        cl = cone(f"Aion_Wing_{side}_F{fi}_Claw", ftip, ctip, fr*0.60, 0.0, 8)
        vcol(cl, C_CLAW); parts.append(cl)

    # Daumen
    thumb_tip  = p(5.05,-0.12, 1.98)
    thumb_claw = p(5.50,-0.14, 2.26)
    ts = cyl(f"Aion_Wing_{side}_Thumb_Prox", wrist, thumb_tip, 0.042, 8)
    vcol(ts, C_BODY); parts.append(ts)
    tc = cone(f"Aion_Wing_{side}_Thumb_Claw", thumb_tip, thumb_claw, 0.035, 0.0, 8)
    vcol(tc, C_CLAW); parts.append(tc)

    # ── Membranen ────────────────────────────────────────────
    # Haupt-Membran: Schulter → alle Finger → Trailing Edge
    main_verts = (
        [shoulder]
        + finger_tips
        + [
            p(3.90,-0.12,-1.85),
            p(2.65,-0.05,-1.38),
            p(1.55, 0.00,-0.52),
        ]
    )
    mm = membrane(f"Aion_Wing_{side}_Mem_Main", main_verts, 0.022)
    vcol(mm, C_WMEM); parts.append(mm)

    # Innere Membran: Schulter → Daumen → Finger 0
    inner_verts = [
        shoulder,
        p(1.55, 0.00, 1.50),
        thumb_tip,
        p(4.70,-0.22, 2.48),
        finger_tips[0],
    ]
    mi = membrane(f"Aion_Wing_{side}_Mem_Inner", inner_verts, 0.018)
    vcol(mi, C_WMEM2); parts.append(mi)

    # Trailing-Membran: Untere Finger → Tail
    trail_verts = [
        p(1.35, 0.00, 0.55),
        finger_tips[3],
        finger_tips[4],
        p(3.90,-0.12,-1.85),
        p(2.40,-0.04,-1.05),
    ]
    mt = membrane(f"Aion_Wing_{side}_Mem_Trail", trail_verts, 0.016)
    vcol(mt, C_WMEM); parts.append(mt)

    # Membran-Adern (dünne Zylinder über Membranfläche)
    for vi, (vs, ve) in enumerate([
        (shoulder, finger_tips[1]),
        (shoulder, finger_tips[2]),
        (elbow,    finger_tips[3]),
        (wrist,    p(3.90,-0.12,-1.85)),
    ]):
        v = cyl(f"Aion_Wing_{side}_Vein{vi}", vs, ve, 0.012, 6)
        vcol(v, C_BODY); parts.append(v)

    return parts


# ═══════════════════════════════════════════════════════════════
# HAUPT
# ═══════════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════════
# AURA — Void-Schatten / Cyan-Energiefeld
# ═══════════════════════════════════════════════════════════════
def create_aura():
    parts = []
    # Dunkle Void-Aura-Hülle (facettiert, leuchtet Cyan)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=1.58, subdivisions=1, location=(0,0,0))
    shell = bpy.context.active_object; shell.name = "Aura_Shell"
    vcol(shell, C_VOID); parts.append(shell)
    # Innerer Cyan-Glühring
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.52, minor_radius=0.020,
        major_segments=60, minor_segments=8, location=(0,0,0))
    igr = bpy.context.active_object; igr.name = "Aura_InnerRing"
    vcol(igr, C_CYAN); parts.append(igr)
    # 3 Orbit-Ringe: Void-Zirkel
    for i, (rx, rz, mr, col) in enumerate([
        (0.0,       0.0,        1.80, C_MID),
        (math.pi/2, 0.0,        1.76, C_CYAN),
        (math.pi/2, math.pi/3,  1.72, C_VOID),
    ]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=mr, minor_radius=0.015,
            major_segments=64, minor_segments=8,
            location=(0,0,0), rotation=(rx, 0, rz))
        r = bpy.context.active_object; r.name = f"Aura_Ring_{i}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(r, col); parts.append(r)
    # Cyan-Partikelwolke (14 Void-Energie-Orbs)
    for i in range(14):
        a = (i / 14) * math.tau
        h = math.sin(i * 1.1) * 0.44
        rd = 1.84 + (i % 3) * 0.07
        pos = (math.cos(a)*rd*math.cos(h), math.sin(a)*rd*math.cos(h), rd*math.sin(h))
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.026 + (i%3)*0.008, segments=6, ring_count=3, location=pos)
        p = bpy.context.active_object; p.name = f"Aura_Ptcl_{i}"
        smooth(p); vcol(p, C_CYAN if i%2==0 else C_BRIGHT); parts.append(p)
    # 6 Schattenranken (radiale Kegel nach außen)
    for i in range(6):
        a = (i / 6) * math.tau
        elev = math.pi / 5 * (1 if i%2==0 else -1)
        r1, r2 = 1.64, 2.02
        cx, cy = math.cos(a), math.sin(a)
        ce, se = math.cos(elev), math.sin(elev)
        t = cone(f"Aura_Tendril_{i}",
                 (cx*r1*ce, cy*r1*ce, r1*se),
                 (cx*r2*ce, cy*r2*ce, r2*se),
                 0.022, 0.002, 5)
        vcol(t, C_MID); parts.append(t)
    return parts


clear_scene()
col = bpy.data.collections.new("Aion_VoidPhantom")
bpy.context.scene.collection.children.link(col)

all_parts = []
all_parts += create_orb()
all_parts += create_phantom_wing("L")
all_parts += create_phantom_wing("R")
all_parts += create_aura()

for obj in all_parts:
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)

print(f"✅ Aion Void Phantom — {len(all_parts)} Teile in 'Aion_VoidPhantom'")
print("EXPORT: File > Export > FBX  |  Apply Scalings: FBX Units Scale")
print("        Forward: -Z  |  Up: Y  |  Vertex Colors: ✓")
