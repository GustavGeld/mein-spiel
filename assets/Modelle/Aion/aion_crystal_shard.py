import bpy, bmesh, math
from mathutils import Vector

# ============================================================
# AION  —  CRYSTAL SHARD  |  Roblox-safe FBX
# Kugelförmiger Begleiter: Amethyst-Kugel mit
# aufbrechenden Kristall-Clustern in verschiedenen Farben,
# kristallinem Käfig-Ring und schwebenden Shard-Fragmenten.
# ============================================================

C_AMETHYST = (0.18, 0.04, 0.28, 1.0)  # Amethyst Basis
C_DEEP     = (0.08, 0.01, 0.14, 1.0)  # innere Tiefe
C_MAGENTA  = (0.70, 0.05, 0.55, 1.0)  # Magenta-Cluster
C_CYAN_C   = (0.05, 0.75, 0.88, 1.0)  # Cyan-Cluster
C_PINK     = (0.88, 0.40, 0.62, 1.0)  # Rosa-Spitzen
C_WHITE_C  = (0.85, 0.90, 0.95, 1.0)  # Weißsilber
C_GOLD_C   = (0.82, 0.68, 0.10, 1.0)  # Gold-Akzent
C_RING     = (0.38, 0.12, 0.52, 1.0)  # Ring-Lila

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

def cyl(name, s, e, r=0.04, v=10):
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

def sph_pt(theta, phi, r=1.0):
    """Kugelkoordinate → kartesisch."""
    return (r*math.sin(theta)*math.cos(phi),
            r*math.sin(theta)*math.sin(phi),
            r*math.cos(theta))

def crystal(name, theta, phi, r_start, length, r_base, color,
            dt=0.0, dp=0.0):
    """Einkristall, der von der Kugeloberfläche nach außen zeigt."""
    s = sph_pt(theta+dt, phi+dp, r_start)
    e = sph_pt(theta+dt, phi+dp, r_start + length)
    c = cone(name, s, e, r_base, r_base*0.06, 6)
    vcol(c, color)
    return c

# ── Kristall-Cluster ─────────────────────────────────────────
def crystal_cluster(prefix, theta, phi, n, base_len, base_r, color, color2):
    parts = []
    for i in range(n):
        a_off = (i/n)*math.tau
        dt = math.sin(a_off)*0.18
        dp = math.cos(a_off)*0.22
        var = 1.0 + (i%3)*0.22
        col = color if i%2==0 else color2
        c = crystal(f"{prefix}_{i}", theta, phi,
                    0.97, base_len*var, base_r*(1.1 - i*0.04), col, dt, dp)
        parts.append(c)
        # Kleine Neben-Kristalle um den Haupt-Kristall
        for j in range(2):
            sdt = dt + math.sin(j*math.pi)*0.08
            sdp = dp + math.cos(j*math.pi)*0.08
            sc = crystal(f"{prefix}_{i}_s{j}", theta, phi,
                         0.98, base_len*var*0.55, base_r*0.45, C_WHITE_C, sdt, sdp)
            parts.append(sc)
    return parts

# ═══════════════════════════════════════════════════════════════
# HAUPTKUGEL + DEKORATION
# ═══════════════════════════════════════════════════════════════
def create_orb():
    parts = []

    # Haupt-Kugel
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=1.0, segments=64, ring_count=32, location=(0,0,0))
    orb = bpy.context.active_object; orb.name = "Aion_Orb"
    smooth(orb); vcol(orb, C_AMETHYST); parts.append(orb)

    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.64, segments=32, ring_count=16, location=(0,0,0))
    c1 = bpy.context.active_object; c1.name = "Aion_Orb_Core"
    smooth(c1); vcol(c1, C_DEEP); parts.append(c1)

    bpy.ops.mesh.primitive_ico_sphere_add(
        radius=0.34, subdivisions=3, location=(0,0,0))
    c2 = bpy.context.active_object; c2.name = "Aion_Orb_IcoCore"
    smooth(c2); vcol(c2, C_MAGENTA); parts.append(c2)

    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.16, segments=12, ring_count=6, location=(0,0,0))
    c3 = bpy.context.active_object; c3.name = "Aion_Orb_Nucleus"
    smooth(c3); vcol(c3, C_WHITE_C); parts.append(c3)

    # Breitengrad-Ringe (kristallin, unregelmäßig)
    for i, (z, maj, mn, col) in enumerate([
        (0.70,  0.72, 0.016, C_RING),
        (0.35,  0.93, 0.022, C_CYAN_C),
        (0.00,  1.02, 0.030, C_MAGENTA),   # Äquator
        (-0.35, 0.93, 0.022, C_CYAN_C),
        (-0.70, 0.72, 0.016, C_RING),
    ]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=maj, minor_radius=mn,
            major_segments=60, minor_segments=10, location=(0,0,z))
        ring = bpy.context.active_object; ring.name = f"Aion_Ring_{i}"
        vcol(ring, col); parts.append(ring)

    # Äquator-Kristalle (8 kleine Spitzen am Ring)
    for i in range(8):
        a = (i/8)*math.tau
        x, y = math.cos(a)*1.03, math.sin(a)*1.03
        bpy.ops.mesh.primitive_cone_add(
            vertices=4, radius1=0.09, depth=0.20,
            location=(x, y, 0), rotation=(0, math.pi/2, a))
        eq_c = bpy.context.active_object; eq_c.name = f"Aion_EqCrystal_{i}"
        smooth(eq_c)
        vcol(eq_c, C_CYAN_C if i%2==0 else C_PINK); parts.append(eq_c)

    # Kristall-Käfig: 4 vertikale Bögen (Torii geneigt)
    for i in range(4):
        rz = (i/4)*math.pi
        bpy.ops.mesh.primitive_torus_add(
            major_radius=1.15, minor_radius=0.014,
            major_segments=60, minor_segments=8,
            location=(0,0,0), rotation=(math.pi/2, 0, rz))
        arc = bpy.context.active_object; arc.name = f"Aion_CrystalArc_{i}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(arc, C_WHITE_C); parts.append(arc)

    # Großer schwebender Ring
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.42, minor_radius=0.025,
        major_segments=80, minor_segments=12, location=(0,0,0))
    halo = bpy.context.active_object; halo.name = "Aion_Halo"
    vcol(halo, C_RING); parts.append(halo)

    # 16 Kristall-Perlen auf dem Ring
    for i in range(16):
        a = (i/16)*math.tau
        bpy.ops.mesh.primitive_cone_add(
            vertices=4, radius1=0.042, depth=0.095,
            location=(math.cos(a)*1.42, math.sin(a)*1.42, 0),
            rotation=(0, math.pi/2, a+math.pi/4))
        bead = bpy.context.active_object; bead.name = f"Aion_RingCrystal_{i}"
        smooth(bead)
        vcol(bead, C_WHITE_C if i%4==0 else C_RING)
        parts.append(bead)

    return parts


# ═══════════════════════════════════════════════════════════════
# KRISTALL-CLUSTER (die Haupt-Besonderheit)
# ═══════════════════════════════════════════════════════════════
def create_crystals():
    parts = []
    tau = math.tau

    # Cluster 1: Nordpol — Magenta/Rosa (der dramatischste)
    parts += crystal_cluster("Cl_North", 0.30, 0.0,  6, 0.55, 0.072, C_MAGENTA, C_PINK)

    # Cluster 2: Äquator Ost — Cyan
    parts += crystal_cluster("Cl_E",  math.pi/2, 0.0,       5, 0.45, 0.062, C_CYAN_C,  C_WHITE_C)
    # Cluster 3: Äquator Nord-Ost — Weiß/Silber
    parts += crystal_cluster("Cl_NE", math.pi/2, tau/4,     4, 0.40, 0.055, C_WHITE_C, C_CYAN_C)
    # Cluster 4: Äquator West — Lila
    parts += crystal_cluster("Cl_W",  math.pi/2, tau/2,     5, 0.45, 0.060, C_RING,    C_MAGENTA)
    # Cluster 5: Äquator Süd-West
    parts += crystal_cluster("Cl_SW", math.pi/2, 3*tau/4,   4, 0.38, 0.052, C_PINK,    C_WHITE_C)

    # Cluster 6: Südpol — Gold/Cyan Anhänger
    parts += crystal_cluster("Cl_South", math.pi - 0.30, 0.0, 5, 0.50, 0.065, C_GOLD_C, C_CYAN_C)

    # Extra: Verstreute Einzel-Kristalle (mittlere Größe über die Kugel)
    scattered = [
        (0.65,  0.80, 0.32, 0.048, C_WHITE_C),
        (0.85,  2.10, 0.28, 0.042, C_CYAN_C),
        (1.10,  1.20, 0.35, 0.050, C_PINK),
        (1.35,  3.50, 0.30, 0.044, C_RING),
        (1.80,  0.60, 0.28, 0.040, C_WHITE_C),
        (2.10,  2.80, 0.32, 0.048, C_MAGENTA),
        (1.60,  4.80, 0.25, 0.038, C_CYAN_C),
        (0.50,  5.20, 0.30, 0.045, C_PINK),
    ]
    for i, (th, ph, ln, rb, col) in enumerate(scattered):
        c = crystal(f"Cl_Single_{i}", th, ph, 0.97, ln, rb, col)
        parts.append(c)

    # Schwebende Shard-Fragmente (kubische Kristall-Splitter)
    shards = [
        (( 1.30, -0.18, 0.60), (0.6, 3.0, 0.12), (0.3, 0, 0.5)),
        ((-1.25, -0.14, 0.55), (0.6, 2.8, 0.10), (-0.2, 0, -0.4)),
        (( 0.65, -0.10,-0.68), (0.5, 2.5, 0.10), (0.4, 0.1, 0.6)),
        ((-0.72,  0.08, 0.90), (0.5, 2.2, 0.10), (-0.3, 0, -0.5)),
        (( 0.90, -0.08,-0.40), (0.6, 2.0, 0.09), (0.1, 0, 0.3)),
        ((-0.80,  0.12, 0.30), (0.5, 1.8, 0.09), (-0.2, 0, -0.3)),
    ]
    for i, (pos, sc, rot) in enumerate(shards):
        bpy.ops.mesh.primitive_cube_add(
            size=0.11, scale=sc, location=pos, rotation=rot)
        sh = bpy.context.active_object; sh.name = f"Aion_Shard_{i}"
        vcol(sh, C_WHITE_C if i%3==0 else C_CYAN_C if i%3==1 else C_MAGENTA)
        parts.append(sh)

    return parts


# ═══════════════════════════════════════════════════════════════
# HAUPT
# ═══════════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════════
# AURA — Prismatisches Kristallfeld
# ═══════════════════════════════════════════════════════════════
def create_aura():
    parts = []
    # Amethyst-Aura-Hülle (violettes Kristalllicht)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=1.58, subdivisions=1, location=(0,0,0))
    shell = bpy.context.active_object; shell.name = "Aura_Shell"
    vcol(shell, (0.12, 0.02, 0.20, 1.0)); parts.append(shell)
    # Innerer Cyan-Ring
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.52, minor_radius=0.022,
        major_segments=60, minor_segments=8, location=(0,0,0))
    igr = bpy.context.active_object; igr.name = "Aura_InnerRing"
    vcol(igr, C_CYAN_C); parts.append(igr)
    # 3 Orbit-Ringe: prismatische Zirkel
    for i, (rx, rz, mr, col) in enumerate([
        (0.0,       0.0,        1.80, C_MAGENTA),
        (math.pi/2, 0.0,        1.76, C_CYAN_C),
        (math.pi/2, math.pi/3,  1.72, C_RING),
    ]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=mr, minor_radius=0.016,
            major_segments=64, minor_segments=8,
            location=(0,0,0), rotation=(rx, 0, rz))
        r = bpy.context.active_object; r.name = f"Aura_Ring_{i}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(r, col); parts.append(r)
    # Kristall-Partikelwolke (14 schwebende Facetten)
    for i in range(14):
        a = (i / 14) * math.tau
        h = math.sin(i * 1.1) * 0.46
        rd = 1.84 + (i % 3) * 0.07
        pos = (math.cos(a)*rd*math.cos(h), math.sin(a)*rd*math.cos(h), rd*math.sin(h))
        bpy.ops.mesh.primitive_ico_sphere_add(
            radius=0.030 + (i%3)*0.010, subdivisions=1, location=pos)
        p = bpy.context.active_object; p.name = f"Aura_Crystal_{i}"
        vcol(p, C_WHITE_C if i%3==0 else (C_CYAN_C if i%3==1 else C_PINK))
        parts.append(p)
    # 6 prismatische Licht-Strahlen (schmale Kristall-Kegel nach außen)
    for i in range(6):
        a = (i / 6) * math.tau
        elev = math.pi / 5 * (1 if i%2==0 else -1)
        r1, r2 = 1.64, 2.10
        cx, cy = math.cos(a), math.sin(a)
        ce, se = math.cos(elev), math.sin(elev)
        beam = cone(f"Aura_Beam_{i}",
                    (cx*r1*ce, cy*r1*ce, r1*se),
                    (cx*r2*ce, cy*r2*ce, r2*se),
                    0.018, 0.001, 4)
        vcol(beam, C_CYAN_C if i%2==0 else C_MAGENTA); parts.append(beam)
    return parts


clear_scene()
col = bpy.data.collections.new("Aion_CrystalShard")
bpy.context.scene.collection.children.link(col)

all_parts = create_orb() + create_crystals() + create_aura()

for obj in all_parts:
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)

print(f"✅ Aion Crystal Shard — {len(all_parts)} Teile")
