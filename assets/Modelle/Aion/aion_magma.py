import bpy, bmesh, math
from mathutils import Vector

# ============================================================
# AION  —  MAGMA CORE  |  Roblox-safe FBX
# Kugelförmiger Begleiter: Vulkanische Lavakugel —
# aufgebrochene Kruste mit glühenden Riss-Netzen,
# Vulkanspitzen, Lava-Pools und Asche-Fragmenten.
# ============================================================

C_CRUST  = (0.07, 0.04, 0.01, 1.0)  # Kruste schwarz-braun
C_ROCK   = (0.14, 0.08, 0.02, 1.0)  # dunkles Gestein
C_LAVA   = (0.95, 0.42, 0.04, 1.0)  # Lava Orange
C_HOT    = (1.00, 0.75, 0.12, 1.0)  # heiße Mitte Gelb
C_EMBER  = (0.70, 0.18, 0.02, 1.0)  # glühende Kohle Rot
C_ASH    = (0.35, 0.30, 0.26, 1.0)  # Asche Grau
C_CORE_M = (1.00, 0.55, 0.05, 1.0)  # Magma-Kern

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

def sph(theta, phi, r=1.0):
    return (r*math.sin(theta)*math.cos(phi),
            r*math.sin(theta)*math.sin(phi),
            r*math.cos(theta))

def lava_crack(prefix, path_tp, r=0.015, color=None):
    """Verbindet eine Liste von (theta,phi)-Punkten auf der Kugel mit Zylindern."""
    col = color or C_LAVA
    pts = [sph(th, ph, 1.02) for th, ph in path_tp]
    parts = []
    for i in range(len(pts)-1):
        seg = cyl(f"{prefix}_{i}", pts[i], pts[i+1], r, 6)
        vcol(seg, col); parts.append(seg)
        # Gelegentlich ein kleiner Lava-Pool am Knotenpunkt
        if i % 2 == 1:
            bpy.ops.mesh.primitive_cylinder_add(
                radius=r*2.2, depth=r*0.8, vertices=8, location=pts[i])
            pool = bpy.context.active_object; pool.name = f"{prefix}_pool_{i}"
            smooth(pool); vcol(pool, C_HOT); parts.append(pool)
    return parts


# ═══════════════════════════════════════════════════════════════
# HAUPTKUGEL
# ═══════════════════════════════════════════════════════════════
def create_orb():
    parts = []
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=64, ring_count=32, location=(0,0,0))
    orb = bpy.context.active_object; orb.name = "Aion_Orb"
    smooth(orb); vcol(orb, C_CRUST); parts.append(orb)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.66, segments=32, ring_count=16, location=(0,0,0))
    c1 = bpy.context.active_object; c1.name = "Aion_Orb_Core"
    smooth(c1); vcol(c1, C_ROCK); parts.append(c1)

    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.38, subdivisions=2, location=(0,0,0))
    c2 = bpy.context.active_object; c2.name = "Aion_Magma_Core"
    smooth(c2); vcol(c2, C_LAVA); parts.append(c2)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.18, segments=12, ring_count=6, location=(0,0,0))
    c3 = bpy.context.active_object; c3.name = "Aion_Nucleus"
    smooth(c3); vcol(c3, C_HOT); parts.append(c3)

    # Lava-Haupt-Äquator-Ring
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.015, minor_radius=0.032,
        major_segments=64, minor_segments=12, location=(0,0,0))
    eq = bpy.context.active_object; eq.name = "Aion_LavaRing"
    vcol(eq, C_LAVA); parts.append(eq)

    # 2 Lava-Seiten-Ringe
    for z, col in [(0.55, C_EMBER), (-0.55, C_EMBER)]:
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.83, minor_radius=0.018,
            major_segments=48, minor_segments=8, location=(0,0,z))
        r = bpy.context.active_object; r.name = f"Aion_Ring_{z:.2f}"
        vcol(r, col); parts.append(r)

    # 8 Lava-Fontänen auf dem Äquator-Ring
    for i in range(8):
        a = (i/8)*math.tau
        x, y = math.cos(a)*1.02, math.sin(a)*1.02
        bpy.ops.mesh.primitive_cone_add(
            vertices=6, radius1=0.042, depth=0.12,
            location=(x, y, 0.06), rotation=(0, 0, a))
        fnt = bpy.context.active_object; fnt.name = f"Aion_Fountain_{i}"
        smooth(fnt); vcol(fnt, C_HOT if i%2==0 else C_LAVA); parts.append(fnt)

    # Großer Schwebering (Asche-grau)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.42, minor_radius=0.024,
        major_segments=80, minor_segments=10, location=(0,0,0))
    halo = bpy.context.active_object; halo.name = "Aion_Halo"
    vcol(halo, C_ASH); parts.append(halo)

    # 10 Lava-Tropfen auf Ring
    for i in range(10):
        a = (i/10)*math.tau
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.038, segments=7, ring_count=4,
            location=(math.cos(a)*1.42, math.sin(a)*1.42, 0))
        b = bpy.context.active_object; b.name = f"Aion_Drop_{i}"
        smooth(b); vcol(b, C_LAVA if i%2==0 else C_HOT); parts.append(b)

    # 4 Diagonal-Bögen (rot-orange)
    for i, rz in enumerate([0, math.pi/4, math.pi/2, 3*math.pi/4]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=1.18, minor_radius=0.013,
            major_segments=64, minor_segments=6,
            location=(0,0,0), rotation=(math.pi/2, 0, rz))
        arc = bpy.context.active_object; arc.name = f"Aion_Arc_{i}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(arc, C_EMBER); parts.append(arc)

    return parts


# ═══════════════════════════════════════════════════════════════
# LAVA-RISS-NETZWERK
# ═══════════════════════════════════════════════════════════════
def create_cracks():
    parts = []
    tau = math.tau

    # 6 Haupt-Risse mit Verzweigungen
    crack_paths = [
        [(0.45,0.10),(0.72,0.28),(1.00,0.42),(1.28,0.55),(1.55,0.62)],
        [(0.55,2.20),(0.85,2.55),(1.15,2.70),(1.45,2.90)],
        [(0.80,4.00),(1.10,4.20),(1.40,4.35),(1.68,4.50)],
        [(1.20,1.00),(1.45,1.30),(1.70,1.55),(2.00,1.70)],
        [(0.60,5.50),(0.95,5.70),(1.30,5.85),(1.65,6.00)],
        [(0.90,3.00),(1.20,3.18),(1.50,3.30),(1.80,3.42)],
    ]
    for ci, path in enumerate(crack_paths):
        parts += lava_crack(f"Crack_{ci}", path, 0.016, C_LAVA)
        # Verzweigung ab Mitte
        mid = path[len(path)//2]
        branch = [mid, (mid[0]+0.15, mid[1]+0.4), (mid[0]+0.30, mid[1]+0.7)]
        parts += lava_crack(f"CrackBranch_{ci}", branch, 0.010, C_HOT)

    # Sekundäre dünne Risse (dunkler)
    secondary = [
        [(0.30,1.50),(0.55,1.65),(0.80,1.72)],
        [(1.60,2.80),(1.85,2.95),(2.10,3.05)],
        [(1.10,5.20),(1.35,5.40),(1.60,5.55)],
        [(0.65,3.80),(0.90,3.95),(1.12,4.08)],
    ]
    for si, path in enumerate(secondary):
        parts += lava_crack(f"Crack2_{si}", path, 0.009, C_EMBER)

    return parts


# ═══════════════════════════════════════════════════════════════
# VULKAN-SPITZEN + KRATER
# ═══════════════════════════════════════════════════════════════
def create_volcanoes():
    parts = []

    # Haupt-Spitzen (verschiedene Größen, auf Kugel verteilt)
    spike_cfg = [
        (0.55, 0.80, 0.50, 0.075, C_ROCK),   # groß
        (0.88, 2.10, 0.40, 0.060, C_ROCK),
        (1.20, 4.60, 0.45, 0.068, C_ROCK),
        (1.65, 1.40, 0.35, 0.052, C_ASH),
        (0.40, 3.50, 0.30, 0.048, C_ROCK),
        (1.85, 5.00, 0.28, 0.042, C_ASH),
        (1.40, 3.10, 0.32, 0.050, C_ROCK),
        (0.72, 5.80, 0.26, 0.040, C_ASH),
    ]
    for i, (th, ph, length, rb, col) in enumerate(spike_cfg):
        s = sph(th, ph, 0.98)
        e = sph(th, ph, 0.98+length)
        sp = cone(f"Aion_Spike_{i}", s, e, rb, rb*0.05, 8)
        vcol(sp, col); parts.append(sp)
        # Glühende Spitze
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=rb*0.55, segments=7, ring_count=4, location=e)
        tip = bpy.context.active_object; tip.name = f"Aion_SpikeTip_{i}"
        smooth(tip); vcol(tip, C_HOT if i%2==0 else C_LAVA); parts.append(tip)

    # Nordpol: Vulkan-Krater
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.24, depth=0.08, vertices=14, location=(0,0,0.96))
    crater = bpy.context.active_object; crater.name = "Aion_Crater"
    smooth(crater); vcol(crater, C_ROCK); parts.append(crater)

    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.22, minor_radius=0.028,
        major_segments=20, minor_segments=8, location=(0,0,0.99))
    cr = bpy.context.active_object; cr.name = "Aion_CraterRim"
    vcol(cr, C_LAVA); parts.append(cr)

    # Inneres Krater-Leuchten
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.14, depth=0.04, vertices=12, location=(0,0,0.97))
    cg = bpy.context.active_object; cg.name = "Aion_CraterGlow"
    smooth(cg); vcol(cg, C_HOT); parts.append(cg)

    # Lava-Fontäne aus dem Krater (3 divergierende Kegel)
    for i in range(3):
        a = (i/3)*math.tau
        fx, fy = math.sin(a)*0.08, math.cos(a)*0.08
        fc = cone(f"Aion_FountainJet_{i}",
                  (fx, fy, 1.00), (fx*1.8, fy*1.8, 1.28),
                  0.032, 0.0, 6)
        vcol(fc, C_LAVA); parts.append(fc)

    # Südpol: Lava-Tropfen Anhänger
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.18, minor_radius=0.022,
        major_segments=18, minor_segments=7, location=(0,0,-0.92))
    sr = bpy.context.active_object; sr.name = "Aion_SouthRing"
    vcol(sr, C_ROCK); parts.append(sr)

    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.10, segments=10, ring_count=6, location=(0,0,-1.10))
    sd = bpy.context.active_object; sd.name = "Aion_LavaDrop"
    smooth(sd); vcol(sd, C_LAVA); parts.append(sd)

    cone("Aion_LavaDrip", (0,0,-1.18), (0,0,-1.38), 0.042, 0.0, 6)
    drip = bpy.context.active_object; drip.name = "Aion_LavaDrip"
    vcol(drip, C_EMBER); parts.append(drip)

    return parts


# ═══════════════════════════════════════════════════════════════
# ASCHE-PARTIKEL
# ═══════════════════════════════════════════════════════════════
def create_ash():
    parts = []
    ash_cfg = [
        (( 1.40,-0.12, 0.62),(0.6,1.5,0.12),(0.4,0,0.5)),
        ((-1.35,-0.10, 0.58),(0.5,1.8,0.10),(-0.3,0,-0.4)),
        (( 0.72,-0.08,-0.85),(0.7,1.2,0.09),(0.5,0.2,0.3)),
        ((-0.78, 0.10, 0.80),(0.6,1.4,0.10),(-0.4,0,-0.5)),
        (( 1.10,-0.06,-0.42),(0.5,1.6,0.08),(0.2,0,0.6)),
        ((-1.00, 0.08, 0.38),(0.6,1.3,0.09),(-0.3,0,-0.4)),
        (( 0.52,-0.10, 1.15),(0.4,1.1,0.08),(0.6,0.1,0.5)),
        ((-0.58, 0.14,-0.78),(0.5,1.2,0.08),(-0.2,0.1,-0.3)),
    ]
    for i, (pos, sc, rot) in enumerate(ash_cfg):
        bpy.ops.mesh.primitive_cube_add(
            size=0.10, scale=sc, location=pos, rotation=rot)
        ash = bpy.context.active_object; ash.name = f"Aion_Ash_{i}"
        vcol(ash, C_ASH if i%3!=1 else C_ROCK); parts.append(ash)
    return parts


# ═══════════════════════════════════════════════════════════════
# AURA — Feuer- und Lava-Energiefeld
# ═══════════════════════════════════════════════════════════════
def create_aura():
    parts = []
    # Facettierte Aura-Hülle (Neon → glühendes Feuerschild)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=1.58, subdivisions=1, location=(0,0,0))
    shell = bpy.context.active_object; shell.name = "Aura_Shell"
    vcol(shell, (0.55, 0.10, 0.01, 1.0)); parts.append(shell)
    # Innerer Lavaglanz-Ring
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.52, minor_radius=0.022,
        major_segments=60, minor_segments=8, location=(0,0,0))
    igr = bpy.context.active_object; igr.name = "Aura_InnerRing"
    vcol(igr, C_LAVA); parts.append(igr)
    # 3 Orbit-Ringe: horizontal + 2 vertikale Ebenen (je 60° versetzt)
    for i, (rx, rz, mr, col) in enumerate([
        (0.0,       0.0,        1.80, C_LAVA),
        (math.pi/2, 0.0,        1.76, C_HOT),
        (math.pi/2, math.pi/3,  1.72, C_EMBER),
    ]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=mr, minor_radius=0.016,
            major_segments=64, minor_segments=8,
            location=(0,0,0), rotation=(rx, 0, rz))
        r = bpy.context.active_object; r.name = f"Aura_Ring_{i}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(r, col); parts.append(r)
    # Glut-Partikelwolke (14 Ember-Orbs auf verschiedenen Höhen)
    for i in range(14):
        a = (i / 14) * math.tau
        h = math.sin(i * 1.1) * 0.46
        rd = 1.84 + (i % 3) * 0.07
        pos = (math.cos(a)*rd*math.cos(h), math.sin(a)*rd*math.cos(h), rd*math.sin(h))
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.028 + (i%3)*0.009, segments=6, ring_count=3, location=pos)
        p = bpy.context.active_object; p.name = f"Aura_Ember_{i}"
        smooth(p); vcol(p, C_HOT if i%2==0 else C_LAVA); parts.append(p)
    # 6 Feuerzungen (Kegel-Flammen nach außen)
    for i in range(6):
        a = (i / 6) * math.tau
        elev = math.pi / 5 * (1 if i%2==0 else -1)
        r1, r2 = 1.64, 2.06
        cx, cy = math.cos(a), math.sin(a)
        ce, se = math.cos(elev), math.sin(elev)
        flame = cone(f"Aura_Flame_{i}",
                     (cx*r1*ce, cy*r1*ce, r1*se),
                     (cx*r2*ce, cy*r2*ce, r2*se),
                     0.026, 0.001, 5)
        vcol(flame, C_LAVA if i%2==0 else C_HOT); parts.append(flame)
    # 6 schwebende Asche-Fragmente
    for i in range(6):
        a = (i / 6) * math.tau + math.pi/6
        rd = 2.00 + (i%2)*0.10
        pos = (math.cos(a)*rd*0.88, math.sin(a)*rd*0.88, math.sin(i*1.3)*0.42)
        bpy.ops.mesh.primitive_cube_add(
            size=0.07, scale=(0.5, 1.6, 0.4), location=pos, rotation=(i*0.5, 0, a))
        cf = bpy.context.active_object; cf.name = f"Aura_AshFrag_{i}"
        vcol(cf, C_ASH); parts.append(cf)
    return parts


clear_scene()
col = bpy.data.collections.new("Aion_MagmaCore")
bpy.context.scene.collection.children.link(col)
all_parts = create_orb() + create_cracks() + create_volcanoes() + create_ash() + create_aura()
for obj in all_parts:
    for c in list(obj.users_collection): c.objects.unlink(obj)
    col.objects.link(obj)
print(f"✅ Aion Magma Core — {len(all_parts)} Teile")
