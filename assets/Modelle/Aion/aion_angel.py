import bpy, bmesh, math
from mathutils import Vector

# ============================================================
# AION  —  DIVINE ANGEL  |  Roblox-safe FBX
# Körper: dekorierte Gold/Elfenbein-Kugel
# Flügel: Engelflügel mit echten Feder-Lagen (animierbar)
# Vertex Colors / domain='CORNER'
# ============================================================

# ── Palette ──────────────────────────────────────────────────
C_IVORY  = (0.90, 0.88, 0.80, 1.0)   # Elfenbein (Kugel)
C_BODY2  = (0.72, 0.68, 0.56, 1.0)   # dunkleres Elfenbein
C_GOLD   = (0.90, 0.72, 0.08, 1.0)   # Gold
C_DGOLD  = (0.52, 0.38, 0.04, 1.0)   # dunkles Gold
C_GEM    = (0.10, 0.82, 0.95, 1.0)   # Aquamarin-Edelstein
C_DIVINE = (1.00, 0.96, 0.62, 1.0)   # göttliches Licht
C_FWHITE = (0.95, 0.93, 0.88, 1.0)   # Feder-Weiß
C_FSHADOW= (0.75, 0.72, 0.64, 1.0)   # Feder-Schatten
C_FGOLD  = (0.88, 0.76, 0.30, 1.0)   # goldene Feder-Spitze

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

def membrane(name, verts, thick=0.022):
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

def make_feather(name, arm_pos, arm_dir_xz, spread_angle, length, width, color):
    """
    Erstellt eine einzelne Feder als flaches Membran-Polygon.
    arm_pos:     (x,0,z) Wurzel der Feder auf dem Arm-Knochen
    arm_dir_xz:  (dx,dz) normalisierte Arm-Richtung in der XZ-Ebene
    spread_angle: Winkel von der Arm-Senkrechten (0=senkrecht, +=vorwärts)
    length, width: Federgröße
    """
    adx, adz = arm_dir_xz
    # Senkrechte zur Arm-Richtung (zeigt "weg vom Arm" = nach außen/oben)
    px, pz = -adz, adx
    ca, sa = math.cos(spread_angle), math.sin(spread_angle)
    # Feder-Richtungs-Vektor
    fdx = px*ca + adx*sa
    fdz = pz*ca + adz*sa
    # Breiten-Senkrechte der Feder
    bx, bz = fdz, -fdx
    hw = width / 2
    rx, ry, rz = arm_pos
    # 7 Punkte: Basis-breit, Mitte-breit, Spitze-schmal, Spitze, …
    verts = [
        (rx + bx*hw,        ry, rz + bz*hw),
        (rx + bx*hw*1.05 + fdx*length*0.38, ry, rz + bz*hw*1.05 + fdz*length*0.38),
        (rx + bx*hw*0.18 + fdx*length*0.80, ry, rz + bz*hw*0.18 + fdz*length*0.80),
        (rx             + fdx*length,        ry, rz              + fdz*length),   # Spitze
        (rx - bx*hw*0.18 + fdx*length*0.80, ry, rz - bz*hw*0.18 + fdz*length*0.80),
        (rx - bx*hw*1.05 + fdx*length*0.38, ry, rz - bz*hw*1.05 + fdz*length*0.38),
        (rx - bx*hw,        ry, rz - bz*hw),
    ]
    mem = membrane(name, verts, 0.016)
    vcol(mem, color)
    return mem


# ═══════════════════════════════════════════════════════════════
# KUGEL-KÖRPER  (Gold/Elfenbein-Thema)
# ═══════════════════════════════════════════════════════════════
def create_orb():
    parts = []

    # ── Hauptkugel ──────────────────────────────────────────
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=1.0, segments=64, ring_count=32, location=(0,0,0))
    orb = bpy.context.active_object; orb.name = "Aion_Orb"
    smooth(orb); vcol(orb, C_IVORY); parts.append(orb)

    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.62, segments=32, ring_count=16, location=(0,0,0))
    core = bpy.context.active_object; core.name = "Aion_Orb_Core"
    smooth(core); vcol(core, C_BODY2); parts.append(core)

    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.36, segments=20, ring_count=10, location=(0,0,0))
    c2 = bpy.context.active_object; c2.name = "Aion_Orb_Core_Inner"
    smooth(c2); vcol(c2, C_DIVINE); parts.append(c2)

    # ── 5 Breitengrad-Ringe (Gold) ───────────────────────────
    for i, (z, maj, mn) in enumerate([
        (0.75, 0.66, 0.016),
        (0.38, 0.92, 0.022),
        (0.00, 1.015,0.032),  # Äquator
        (-0.38,0.92, 0.022),
        (-0.75,0.66, 0.016),
    ]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=maj, minor_radius=mn,
            major_segments=64, minor_segments=12, location=(0,0,z))
        ring = bpy.context.active_object; ring.name = f"Aion_Ring_{i}"
        vcol(ring, C_GOLD if i==2 else C_DGOLD); parts.append(ring)

    # ── 8 Längengrad-Rillen ──────────────────────────────────
    for i in range(8):
        a = (i/8)*math.tau
        bpy.ops.mesh.primitive_cube_add(
            size=1, scale=(0.020,0.020,1.88),
            location=(math.cos(a)*1.02, math.sin(a)*1.02, 0),
            rotation=(0,0,a))
        g = bpy.context.active_object; g.name = f"Aion_Groove_{i}"
        vcol(g, C_GOLD); parts.append(g)

    # ── 8 Äquator-Prunkplatten + Edelsteine ──────────────────
    for i in range(8):
        a = (i/8)*math.tau
        x, y = math.cos(a)*1.02, math.sin(a)*1.02
        bpy.ops.mesh.primitive_cube_add(
            size=1, scale=(0.07,0.34,0.34),
            location=(x,y,0), rotation=(0,math.pi/4,a))
        plate = bpy.context.active_object; plate.name = f"Aion_Panel_{i}"
        vcol(plate, C_GOLD); parts.append(plate)
        bpy.ops.mesh.primitive_cone_add(
            vertices=4, radius1=0.10, depth=0.24,
            location=(x*1.04,y*1.04,0), rotation=(0,math.pi/2,a))
        gem = bpy.context.active_object; gem.name = f"Aion_Gem_{i}"
        smooth(gem); vcol(gem, C_GEM); parts.append(gem)

    # ── Götterkrone (Nordpol) ────────────────────────────────
    for z_c, maj_c, mn_c in [(0.88,0.34,0.038),(0.96,0.28,0.022)]:
        bpy.ops.mesh.primitive_torus_add(
            major_radius=maj_c, minor_radius=mn_c,
            major_segments=32, minor_segments=8, location=(0,0,z_c))
        cr = bpy.context.active_object; cr.name = f"Aion_Crown_Ring_{z_c:.2f}"
        vcol(cr, C_GOLD); parts.append(cr)

    # 8 Zacken: alternierend groß/klein
    for i in range(8):
        a = (i/8)*math.tau
        sx, sy = math.sin(a)*0.28, math.cos(a)*0.28
        tall = (i%2 == 0)
        h = 0.50 if tall else 0.24
        sp = cone(f"Aion_Crown_{i}",
                  (sx, sy, 1.00), (sx*1.06, sy*1.06, 1.00+h),
                  0.058 if tall else 0.034, 0.0, 8)
        vcol(sp, C_GOLD if tall else C_DGOLD); parts.append(sp)
        if tall:
            # Edelstein auf langer Zacke
            bpy.ops.mesh.primitive_uv_sphere_add(
                radius=0.040, segments=8, ring_count=6,
                location=(sx*1.07, sy*1.07, 1.00+h+0.04))
            jewel = bpy.context.active_object; jewel.name = f"Aion_Crown_Jewel_{i}"
            smooth(jewel); vcol(jewel, C_GEM); parts.append(jewel)

    # Gold-Pol-Kappe
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.16, depth=0.07, vertices=16, location=(0,0,0.98))
    cap = bpy.context.active_object; cap.name = "Aion_North_Cap"
    smooth(cap); vcol(cap, C_DGOLD); parts.append(cap)

    bpy.ops.mesh.primitive_ico_sphere_add(
        radius=0.10, subdivisions=2, location=(0,0,1.07))
    cg = bpy.context.active_object; cg.name = "Aion_North_Gem"
    smooth(cg); vcol(cg, C_DIVINE); parts.append(cg)

    # ── Südpol-Anhänger ──────────────────────────────────────
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.24, minor_radius=0.028,
        major_segments=24, minor_segments=8, location=(0,0,-0.88))
    sr = bpy.context.active_object; sr.name = "Aion_South_Ring"
    vcol(sr, C_GOLD); parts.append(sr)

    bpy.ops.mesh.primitive_cone_add(
        vertices=4, radius1=0.14, depth=0.44,
        location=(0,0,-1.22), rotation=(math.pi,0,0))
    pend = bpy.context.active_object; pend.name = "Aion_Pendant"
    smooth(pend); vcol(pend, C_GOLD); parts.append(pend)

    # ── Großer Schwebering ───────────────────────────────────
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.38, minor_radius=0.038,
        major_segments=80, minor_segments=16, location=(0,0,0))
    halo = bpy.context.active_object; halo.name = "Aion_Halo"
    vcol(halo, C_GOLD); parts.append(halo)

    for i in range(12):
        a = (i/12)*math.tau
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.050, segments=8, ring_count=6,
            location=(math.cos(a)*1.38, math.sin(a)*1.38, 0))
        bead = bpy.context.active_object; bead.name = f"Aion_Bead_{i}"
        smooth(bead); vcol(bead, C_DIVINE if i%2==0 else C_GOLD); parts.append(bead)

    # 4 Meridian-Ringe
    for i in range(4):
        rz = (i/4)*math.pi
        bpy.ops.mesh.primitive_torus_add(
            major_radius=1.28, minor_radius=0.020,
            major_segments=80, minor_segments=8,
            location=(0,0,0), rotation=(math.pi/2, 0, rz))
        arc = bpy.context.active_object; arc.name = f"Aion_Arc_{i}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(arc, C_DGOLD); parts.append(arc)

    return parts


# ═══════════════════════════════════════════════════════════════
# ENGELFLÜGEL  (3 Feder-Lagen — jede Feder ein eigenes Objekt)
# ═══════════════════════════════════════════════════════════════
def create_angel_wing(side="L"):
    m = 1 if side == "L" else -1
    parts = []

    # Arm-Knochen (weiß/golden, sehr schlank)
    attach   = (1.04*m, 0.0,  0.00)
    shoulder = (1.42*m, 0.0,  0.05)
    elbow    = (2.70*m, 0.0,  0.38)
    wrist    = (3.85*m, 0.0,  0.18)

    sh = cyl(f"Aion_Wing_{side}_Shoulder", attach, shoulder, 0.072, 10)
    vcol(sh, C_DGOLD); parts.append(sh)
    ua = cyl(f"Aion_Wing_{side}_UpperArm",  shoulder, elbow,   0.058, 10)
    vcol(ua, C_IVORY); parts.append(ua)
    fa = cyl(f"Aion_Wing_{side}_Forearm",   elbow,    wrist,   0.046, 10)
    vcol(fa, C_IVORY); parts.append(fa)

    # Gelenk-Kugeln (kleine dekorative Kugeln an den Gelenken)
    for jname, jpos, jr in [
        (f"Aion_Wing_{side}_ShoulderJoint", shoulder, 0.068),
        (f"Aion_Wing_{side}_ElbowJoint",    elbow,    0.058),
        (f"Aion_Wing_{side}_WristJoint",    wrist,    0.048),
    ]:
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=jr, segments=10, ring_count=5, location=jpos)
        jobj = bpy.context.active_object; jobj.name = jname
        smooth(jobj); vcol(jobj, C_GOLD); parts.append(jobj)

    # ── Arm-Richtungsvektor für Feder-Berechnung ────────────
    adx = wrist[0] - shoulder[0]
    adz = wrist[2] - shoulder[2]
    arm_len = math.sqrt(adx**2 + adz**2)
    adx_n, adz_n = adx/arm_len, adz/arm_len  # normalisiert

    def arm_point(t):
        """Position auf dem Arm bei Parameter t (0=Schulter, 1=Handgelenk)."""
        return (
            shoulder[0] + t*(wrist[0]-shoulder[0]),
            0.0,
            shoulder[2] + t*(wrist[2]-shoulder[2]),
        )

    # ── LAGE 1: Deckfedern (Coverts) — klein, nahe am Körper ─
    # Position: t=0.0..0.55, fächern leicht nach vorne (+spread)
    covert_cfg = [
        # (t, spread_angle, length, width)
        (0.04,  0.22, 0.52, 0.17),
        (0.12,  0.18, 0.57, 0.18),
        (0.21,  0.14, 0.60, 0.18),
        (0.30,  0.10, 0.62, 0.19),
        (0.40,  0.06, 0.60, 0.18),
        (0.50,  0.02, 0.56, 0.17),
    ]
    for fi, (t, spread, flen, fwid) in enumerate(covert_cfg):
        ap = arm_point(t)
        feat = make_feather(
            f"Aion_Wing_{side}_Covert_{fi}",
            ap, (adx_n, adz_n), spread, flen, fwid,
            C_FSHADOW if fi%2==0 else C_FWHITE
        )
        parts.append(feat)

    # ── LAGE 2: Sekundär-Federn — mittelgroß, füllen das Mittelflügel ─
    secondary_cfg = [
        (0.12, -0.08, 0.85, 0.22),
        (0.22, -0.07, 0.92, 0.23),
        (0.32, -0.06, 0.98, 0.24),
        (0.42, -0.04, 1.02, 0.24),
        (0.52, -0.02, 1.00, 0.23),
        (0.60,  0.00, 0.94, 0.22),
        (0.68,  0.02, 0.86, 0.21),
    ]
    for fi, (t, spread, flen, fwid) in enumerate(secondary_cfg):
        ap = arm_point(t)
        feat = make_feather(
            f"Aion_Wing_{side}_Secondary_{fi}",
            ap, (adx_n, adz_n), spread, flen, fwid,
            C_FWHITE
        )
        parts.append(feat)
        # Kleine Feder-Spitze (golden) am Ende jeder Sekundär-Feder
        tip_x = ap[0] + (-adz_n*math.cos(spread) + adx_n*math.sin(spread))*flen
        tip_z = ap[2] + ( adx_n*math.cos(spread) + adz_n*math.sin(spread))*flen
        ft = cone(f"Aion_Wing_{side}_Secondary_{fi}_Tip",
                  (tip_x, 0, tip_z),
                  (tip_x + (-adz_n)*0.08, 0, tip_z + adx_n*0.08),
                  0.022, 0.0, 6)
        vcol(ft, C_FGOLD); parts.append(ft)

    # ── LAGE 3: Primär-Federn — groß, bilden Flügel-Silhouette ─
    # Fächern von aufwärts (t≈0.55) bis zur Spitze (t=1.0)
    # spread_angle nimmt zu → letzte Federn zeigen nach außen (Flügelspitze)
    primary_cfg = [
        (0.58, -0.28, 1.12, 0.22),
        (0.65, -0.20, 1.28, 0.25),
        (0.72, -0.12, 1.42, 0.27),
        (0.79, -0.04, 1.52, 0.28),  # längste Feder
        (0.86,  0.06, 1.46, 0.27),
        (0.91,  0.16, 1.32, 0.25),
        (0.96,  0.26, 1.16, 0.22),
        (1.00,  0.38, 0.98, 0.20),  # Flügelspitze
    ]
    for fi, (t, spread, flen, fwid) in enumerate(primary_cfg):
        # Für die Spitzenfedern: Wurzel leicht über Handgelenk hinaus
        if t > 1.0:
            overshoot = (t - 1.0) * arm_len
            ap = (
                wrist[0] + adx_n*overshoot,
                0.0,
                wrist[2] + adz_n*overshoot,
            )
        else:
            ap = arm_point(t)
        feat = make_feather(
            f"Aion_Wing_{side}_Primary_{fi}",
            ap, (adx_n, adz_n), spread, flen, fwid,
            C_FWHITE if fi < 5 else C_FGOLD  # Außenfedern golden
        )
        parts.append(feat)

    # ── Kleine Alula-Federn (Daumen-Federn) ──────────────────
    alula_pos = arm_point(0.78)
    for ai, (sp, fl, fw) in enumerate([(-0.50, 0.45, 0.12), (-0.38, 0.52, 0.14)]):
        af = make_feather(
            f"Aion_Wing_{side}_Alula_{ai}",
            alula_pos, (adx_n, adz_n), sp, fl, fw, C_FGOLD
        )
        parts.append(af)

    return parts


# ═══════════════════════════════════════════════════════════════
# HAUPT
# ═══════════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════════
# AURA — Göttliches Lichtfeld
# ═══════════════════════════════════════════════════════════════
def create_aura():
    parts = []
    # Elfenbein-Gold Aura-Hülle (facettiertes Heiligenschein-Schild)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=1.58, subdivisions=1, location=(0,0,0))
    shell = bpy.context.active_object; shell.name = "Aura_Shell"
    vcol(shell, (0.75, 0.65, 0.30, 1.0)); parts.append(shell)
    # Innerer Gold-Glühring
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.52, minor_radius=0.022,
        major_segments=60, minor_segments=8, location=(0,0,0))
    igr = bpy.context.active_object; igr.name = "Aura_InnerRing"
    vcol(igr, C_GOLD); parts.append(igr)
    # 3 Orbit-Ringe: göttliche Heiligenscheine
    for i, (rx, rz, mr, col) in enumerate([
        (0.0,       0.0,        1.80, C_GOLD),
        (math.pi/2, 0.0,        1.76, C_DIVINE),
        (math.pi/2, math.pi/3,  1.72, C_FWHITE),
    ]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=mr, minor_radius=0.018,
            major_segments=64, minor_segments=8,
            location=(0,0,0), rotation=(rx, 0, rz))
        r = bpy.context.active_object; r.name = f"Aura_Ring_{i}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(r, col); parts.append(r)
    # Göttliche Licht-Partikel (14 leuchtende Orbs)
    for i in range(14):
        a = (i / 14) * math.tau
        h = math.sin(i * 1.0) * 0.42
        rd = 1.85 + (i % 3) * 0.07
        pos = (math.cos(a)*rd*math.cos(h), math.sin(a)*rd*math.cos(h), rd*math.sin(h))
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.030 + (i%3)*0.008, segments=6, ring_count=3, location=pos)
        p = bpy.context.active_object; p.name = f"Aura_Light_{i}"
        smooth(p); vcol(p, C_FWHITE if i%2==0 else C_DIVINE); parts.append(p)
    # 8 Göttliche Lichtstrahlen (radiale Kegel nach außen)
    for i in range(8):
        a = (i / 8) * math.tau
        elev = math.pi / 4 * (1 if i%2==0 else -1)
        r1, r2 = 1.62, 2.08
        cx, cy = math.cos(a), math.sin(a)
        ce, se = math.cos(elev), math.sin(elev)
        ray = cone(f"Aura_Ray_{i}",
                   (cx*r1*ce, cy*r1*ce, r1*se),
                   (cx*r2*ce, cy*r2*ce, r2*se),
                   0.024, 0.001, 4)
        vcol(ray, C_DIVINE if i%2==0 else C_GOLD); parts.append(ray)
    return parts


clear_scene()
col = bpy.data.collections.new("Aion_DivinAngel")
bpy.context.scene.collection.children.link(col)

all_parts = []
all_parts += create_orb()
all_parts += create_angel_wing("L")
all_parts += create_angel_wing("R")
all_parts += create_aura()

for obj in all_parts:
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)

print(f"✅ Aion Divine Angel — {len(all_parts)} Teile in 'Aion_DivinAngel'")
print("EXPORT: File > Export > FBX  |  Apply Scalings: FBX Units Scale")
print("        Forward: -Z  |  Up: Y  |  Vertex Colors: ✓")
