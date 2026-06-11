import bpy, bmesh, math
from mathutils import Vector

# ============================================================
# AION  —  DARK STAR  |  Roblox-safe FBX
# Kugelförmiger Begleiter: Absolut schwarze Kugel mit
# gleichmäßig verteilten Stacheln (Fibonacci-Kugel),
# schwebenden Asteroidensplittern und Void-Ringen.
# ============================================================

C_BLACK  = (0.01, 0.01, 0.02, 1.0)   # Void-Schwarz
C_VOID2  = (0.04, 0.02, 0.06, 1.0)   # sehr dunkel lila
C_VOID3  = (0.10, 0.04, 0.14, 1.0)   # inneres Lila
C_STAR   = (0.96, 0.96, 1.00, 1.0)   # Sternenlicht weiß
C_BLUE   = (0.30, 0.55, 1.00, 1.0)   # Sternblau
C_SILVER = (0.65, 0.70, 0.75, 1.0)   # Silber-Stacheln
C_PLASMA = (0.50, 0.20, 0.90, 1.0)   # Plasma-Lila
C_RING_S = (0.18, 0.10, 0.28, 1.0)   # Ring-Dunkelviolett

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

def fibonacci_sphere(n):
    """Gleichmäßig verteilte Punkte auf der Einheitskugel."""
    golden = math.pi * (3.0 - math.sqrt(5.0))
    pts = []
    for i in range(n):
        y = 1.0 - (i/(n-1))*2.0
        r = math.sqrt(max(0.0, 1.0 - y*y))
        phi = golden * i
        pts.append((r*math.cos(phi), r*math.sin(phi), y))
    return pts


# ═══════════════════════════════════════════════════════════════
# HAUPTKUGEL
# ═══════════════════════════════════════════════════════════════
def create_orb():
    parts = []

    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=1.0, segments=64, ring_count=32, location=(0,0,0))
    orb = bpy.context.active_object; orb.name = "Aion_Orb"
    smooth(orb); vcol(orb, C_BLACK); parts.append(orb)

    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.65, segments=32, ring_count=16, location=(0,0,0))
    c1 = bpy.context.active_object; c1.name = "Aion_Orb_Core"
    smooth(c1); vcol(c1, C_VOID2); parts.append(c1)

    bpy.ops.mesh.primitive_ico_sphere_add(
        radius=0.35, subdivisions=3, location=(0,0,0))
    c2 = bpy.context.active_object; c2.name = "Aion_Orb_IcoCore"
    smooth(c2); vcol(c2, C_VOID3); parts.append(c2)

    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.14, segments=10, ring_count=6, location=(0,0,0))
    c3 = bpy.context.active_object; c3.name = "Aion_Orb_Nucleus"
    smooth(c3); vcol(c3, C_STAR); parts.append(c3)

    # Subtile Breiten-Ringe
    for i, (z, maj, mn) in enumerate([
        (0.68,  0.73, 0.014),
        (0.00,  1.01, 0.020),
        (-0.68, 0.73, 0.014),
    ]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=maj, minor_radius=mn,
            major_segments=64, minor_segments=8, location=(0,0,z))
        ring = bpy.context.active_object; ring.name = f"Aion_Ring_{i}"
        vcol(ring, C_RING_S); parts.append(ring)

    # 3 Diagonal-Bögen (fast unsichtbar, subtile Struktur)
    for i, rz in enumerate([0.0, math.tau/3, 2*math.tau/3]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=1.10, minor_radius=0.010,
            major_segments=64, minor_segments=6,
            location=(0,0,0), rotation=(math.pi/2, 0, rz))
        arc = bpy.context.active_object; arc.name = f"Aion_Arc_{i}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(arc, C_RING_S); parts.append(arc)

    # Großer Schwebering
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.45, minor_radius=0.020,
        major_segments=80, minor_segments=10, location=(0,0,0))
    halo = bpy.context.active_object; halo.name = "Aion_Halo"
    vcol(halo, C_PLASMA); parts.append(halo)

    # 8 Plasma-Perlen auf Ring
    for i in range(8):
        a = (i/8)*math.tau
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.042, segments=8, ring_count=5,
            location=(math.cos(a)*1.45, math.sin(a)*1.45, 0))
        bead = bpy.context.active_object; bead.name = f"Aion_Bead_{i}"
        smooth(bead); vcol(bead, C_STAR if i%2==0 else C_BLUE)
        parts.append(bead)

    return parts


# ═══════════════════════════════════════════════════════════════
# STACHELN (Fibonacci-verteilt, 3 Längen-Klassen)
# ═══════════════════════════════════════════════════════════════
def create_spikes():
    parts = []
    pts = fibonacci_sphere(36)

    for i, (nx, ny, nz) in enumerate(pts):
        # Länge abhängig von der Nähe zum "Äquator" und Index
        lat = abs(nz)  # 0 am Äquator, 1 an Polen
        if lat > 0.80:
            length = 0.62 + (i % 3)*0.12   # pol-nah: lang
            r_base = 0.042
            col    = C_STAR
        elif lat > 0.40:
            length = 0.45 + (i % 4)*0.08   # mittel
            r_base = 0.034
            col    = C_SILVER
        else:
            length = 0.28 + (i % 3)*0.08   # äquatornah: kürzer
            r_base = 0.026
            col    = C_RING_S

        start = (nx*0.98, ny*0.98, nz*0.98)
        end   = (nx*(0.98+length), ny*(0.98+length), nz*(0.98+length))

        sp = cone(f"Aion_Spike_{i}", start, end, r_base, r_base*0.05, 6)
        vcol(sp, col); parts.append(sp)

        # Leuchtende Stachel-Spitze (kleine helle Kugel)
        if lat > 0.55 or i % 4 == 0:
            tip_r = r_base * 0.55
            bpy.ops.mesh.primitive_uv_sphere_add(
                radius=tip_r, segments=6, ring_count=4, location=end)
            tip_orb = bpy.context.active_object
            tip_orb.name = f"Aion_SpikeTip_{i}"
            smooth(tip_orb)
            vcol(tip_orb, C_STAR if lat>0.55 else C_BLUE)
            parts.append(tip_orb)

        # Basis-Ring an sehr langen Stacheln
        if length > 0.55:
            base_r = (nx*1.06, ny*1.06, nz*1.06)
            bpy.ops.mesh.primitive_torus_add(
                major_radius=r_base*1.6, minor_radius=r_base*0.25,
                major_segments=10, minor_segments=5,
                location=base_r)
            base_ring = bpy.context.active_object
            base_ring.name = f"Aion_SpikeBase_{i}"
            vcol(base_ring, C_VOID3); parts.append(base_ring)

    return parts


# ═══════════════════════════════════════════════════════════════
# SCHWEBENDE ASTEROIDENSPLITTER
# ═══════════════════════════════════════════════════════════════
def create_asteroids():
    parts = []

    asteroid_cfg = [
        # (pos, scale, rot, color)
        (( 1.55,-0.20, 0.70), (0.7, 1.0, 0.55), (0.4, 0.2, 0.8),  C_VOID2),
        ((-1.50,-0.15, 0.65), (0.8, 1.1, 0.50), (-0.3, 0.1,-0.7), C_VOID3),
        (( 0.80,-0.12,-0.90), (0.6, 0.9, 0.60), (0.6, 0.3, 0.5),  C_RING_S),
        ((-0.85, 0.14, 0.88), (0.7, 0.8, 0.55), (-0.4, 0.2,-0.6), C_VOID2),
        (( 1.20,-0.08,-0.50), (0.9, 0.7, 0.45), (0.3, 0.5, 0.4),  C_VOID3),
        ((-1.10, 0.10, 0.45), (0.6, 1.0, 0.50), (-0.5, 0.1,-0.5), C_RING_S),
        (( 0.55,-0.14, 1.20), (0.5, 0.8, 0.48), (0.7, 0.2, 0.6),  C_VOID2),
        ((-0.60, 0.18,-0.85), (0.6, 0.9, 0.50), (-0.2, 0.4,-0.4), C_VOID3),
    ]
    for i, (pos, sc, rot, col) in enumerate(asteroid_cfg):
        bpy.ops.mesh.primitive_ico_sphere_add(
            radius=0.075, subdivisions=1, location=pos)
        ast = bpy.context.active_object; ast.name = f"Aion_Asteroid_{i}"
        ast.scale = sc
        bpy.ops.object.transform_apply(scale=True)
        ast.rotation_euler = rot
        bpy.ops.object.transform_apply(rotation=True)
        vcol(ast, col); parts.append(ast)

        # Kleiner Glühpunkt auf jedem Asteroiden
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.022, segments=6, ring_count=4, location=pos)
        glow = bpy.context.active_object; glow.name = f"Aion_AstGlow_{i}"
        smooth(glow); vcol(glow, C_STAR if i%3==0 else C_BLUE)
        parts.append(glow)

    # Sternstaub-Splitter (kleine flache Rechtecke)
    dust = [
        (( 1.82,-0.10, 0.22), (0.4, 1.8, 0.06), (0.3, 0, 0.5)),
        ((-1.78, 0.08, 0.18), (0.4, 1.6, 0.06), (-0.2, 0,-0.4)),
        (( 0.70,-0.08,-1.30), (0.3, 1.4, 0.05), (0.5, 0.1, 0.3)),
        ((-0.75, 0.12, 1.18), (0.3, 1.5, 0.05), (-0.4, 0,-0.3)),
    ]
    for i, (pos, sc, rot) in enumerate(dust):
        bpy.ops.mesh.primitive_cube_add(
            size=0.10, scale=sc, location=pos, rotation=rot)
        d = bpy.context.active_object; d.name = f"Aion_Dust_{i}"
        vcol(d, C_SILVER); parts.append(d)

    return parts


# ═══════════════════════════════════════════════════════════════
# HAUPT
# ═══════════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════════
# AURA — Void-Schwarz / kosmisches Sternfeld
# ═══════════════════════════════════════════════════════════════
def create_aura():
    parts = []
    # Absolut schwarze Aura-Hülle (mit feinen Silber-Facetten)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=1.58, subdivisions=1, location=(0,0,0))
    shell = bpy.context.active_object; shell.name = "Aura_Shell"
    vcol(shell, C_BLACK); parts.append(shell)
    # Innerer Plasma-Ring
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.52, minor_radius=0.020,
        major_segments=60, minor_segments=8, location=(0,0,0))
    igr = bpy.context.active_object; igr.name = "Aura_InnerRing"
    vcol(igr, C_PLASMA); parts.append(igr)
    # 3 Orbit-Ringe: Void-Ringe
    for i, (rx, rz, mr, col) in enumerate([
        (0.0,       0.0,        1.80, C_RING_S),
        (math.pi/2, 0.0,        1.76, C_SILVER),
        (math.pi/2, math.pi/3,  1.72, C_PLASMA),
    ]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=mr, minor_radius=0.015,
            major_segments=64, minor_segments=8,
            location=(0,0,0), rotation=(rx, 0, rz))
        r = bpy.context.active_object; r.name = f"Aura_Ring_{i}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(r, col); parts.append(r)
    # Sternstaub-Partikelwolke (14 leuchtende Sternenlichter)
    for i in range(14):
        a = (i / 14) * math.tau
        h = math.sin(i * 1.1) * 0.46
        rd = 1.84 + (i % 3) * 0.07
        pos = (math.cos(a)*rd*math.cos(h), math.sin(a)*rd*math.cos(h), rd*math.sin(h))
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.024 + (i%3)*0.008, segments=6, ring_count=3, location=pos)
        p = bpy.context.active_object; p.name = f"Aura_Star_{i}"
        smooth(p); vcol(p, C_STAR if i%2==0 else C_BLUE); parts.append(p)
    # 6 Void-Absaugstrahlen (dunkle Kegel nach innen)
    for i in range(6):
        a = (i / 6) * math.tau
        elev = math.pi / 5 * (1 if i%2==0 else -1)
        r1, r2 = 2.05, 1.64
        cx, cy = math.cos(a), math.sin(a)
        ce, se = math.cos(elev), math.sin(elev)
        v = cone(f"Aura_VoidStream_{i}",
                 (cx*r1*ce, cy*r1*ce, r1*se),
                 (cx*r2*ce, cy*r2*ce, r2*se),
                 0.001, 0.022, 5)
        vcol(v, C_VOID3); parts.append(v)
    # 4 kosmische Splitter (flache Rechtecke im Aura-Bereich)
    for i in range(4):
        a = (i / 4) * math.tau + math.pi/8
        rd = 2.00
        pos = (math.cos(a)*rd*0.9, math.sin(a)*rd*0.9, math.sin(i)*0.35)
        bpy.ops.mesh.primitive_cube_add(
            size=0.08, scale=(0.4, 2.0, 0.3), location=pos, rotation=(i*0.7, 0, a))
        cs = bpy.context.active_object; cs.name = f"Aura_CosmicFrag_{i}"
        vcol(cs, C_SILVER); parts.append(cs)
    return parts


clear_scene()
col = bpy.data.collections.new("Aion_DarkStar")
bpy.context.scene.collection.children.link(col)

all_parts = create_orb() + create_spikes() + create_asteroids() + create_aura()

for obj in all_parts:
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)

print(f"✅ Aion Dark Star — {len(all_parts)} Teile")
