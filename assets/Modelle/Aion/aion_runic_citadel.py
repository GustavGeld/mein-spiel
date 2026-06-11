import bpy, bmesh, math
from mathutils import Vector

# ============================================================
# AION  —  RUNIC CITADEL  |  Roblox-safe FBX
# Die Kugel ist eingeschlossen in eine schwebende Ruinen-Festung:
# 5 Gotik-Türme mit Zinnen und Strebepfeilern, verbunden durch
# Runen-Bögen, 10 schwebende Runenstein-Tafeln, alte Flaggen-
# Banner, und ein lebendiges Runen-Energienetz.
# ============================================================

C_STONE   = (0.28, 0.26, 0.22, 1.0)  # Stein-Grau
C_STONE2  = (0.18, 0.16, 0.13, 1.0)  # dunkler Stein
C_MOSS    = (0.14, 0.22, 0.08, 1.0)  # Moos-Grün
C_RUNE    = (0.08, 0.55, 0.92, 1.0)  # Runen-Blau leuchtend
C_RUNE2   = (0.48, 0.12, 0.88, 1.0)  # Runen-Lila
C_GOLD_C  = (0.82, 0.68, 0.10, 1.0)  # Gold-Beschläge
C_FLAG    = (0.52, 0.06, 0.06, 1.0)  # Dunkelrot Banner
C_ORB     = (0.06, 0.05, 0.18, 1.0)  # Kugel Dunkelindigo
C_OCORE   = (0.32, 0.12, 0.82, 1.0)  # Kern Lila
C_ENERGY  = (0.12, 0.82, 0.95, 1.0)  # Energie-Cyan
C_WINDOW  = (0.10, 0.40, 0.72, 1.0)  # Fenster-Blau

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

def cyl(name, s, e, r=0.05, v=8):
    sv, ev = Vector(s), Vector(e)
    vec = ev - sv
    bpy.ops.mesh.primitive_cylinder_add(
        radius=r, depth=vec.length, vertices=v, location=(sv+ev)*0.5)
    obj = bpy.context.active_object; obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = vec.to_track_quat('Z','Y')
    smooth(obj); return obj

def cone(name, s, e, r1=0.05, r2=0.0, v=6):
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
# KUGEL (Altes Festungsherz)
# ═══════════════════════════════════════════════════════════════
def create_orb():
    parts = []
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=64, ring_count=32, location=(0,0,0))
    orb = bpy.context.active_object; orb.name = "Aion_Orb"; smooth(orb); vcol(orb, C_ORB); parts.append(orb)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.64, segments=32, ring_count=16, location=(0,0,0))
    c1 = bpy.context.active_object; c1.name = "Citadel_Core1"; smooth(c1); vcol(c1, (0.10,0.08,0.30,1.0)); parts.append(c1)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.34, subdivisions=2, location=(0,0,0))
    c2 = bpy.context.active_object; c2.name = "Citadel_Core2"; smooth(c2); vcol(c2, C_OCORE); parts.append(c2)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.14, segments=10, ring_count=6, location=(0,0,0))
    c3 = bpy.context.active_object; c3.name = "Citadel_Nucleus"; smooth(c3); vcol(c3, C_ENERGY); parts.append(c3)
    # Runen-Basis-Ringe auf der Kugel
    for i, (z, maj, col) in enumerate([
        (0.60, 0.80, C_RUNE), (0.0, 1.01, C_RUNE2), (-0.60, 0.80, C_RUNE)]):
        bpy.ops.mesh.primitive_torus_add(major_radius=maj, minor_radius=0.018, major_segments=52, minor_segments=8, location=(0,0,z))
        r = bpy.context.active_object; r.name = f"Orb_Ring_{i}"; vcol(r, col); parts.append(r)
    # Orbital-Stein-Ring (Festungsmauer-Basis)
    bpy.ops.mesh.primitive_torus_add(major_radius=1.80, minor_radius=0.045, major_segments=80, minor_segments=14, location=(0,0,0))
    base_ring = bpy.context.active_object; base_ring.name = "Citadel_BaseRing"; vcol(base_ring, C_STONE); parts.append(base_ring)
    # 16 Zinnen-Noppen auf dem Basis-Ring
    for i in range(16):
        a = (i/16)*math.tau
        bpy.ops.mesh.primitive_cube_add(
            size=0.09, scale=(0.7,0.7,1.5),
            location=(math.cos(a)*1.80, math.sin(a)*1.80, 0.06))
        zn = bpy.context.active_object; zn.name = f"Citadel_BaseZinne_{i}"
        vcol(zn, C_STONE2 if i%2==0 else C_STONE); parts.append(zn)
    return parts


# ═══════════════════════════════════════════════════════════════
# GOTIK-TURM
# ═══════════════════════════════════════════════════════════════
def create_tower(prefix, orbit_r, phi_offset, height=1.60, tower_r=0.22):
    parts = []
    cx = math.cos(phi_offset)*orbit_r
    cy = math.sin(phi_offset)*orbit_r
    cz = 0.0

    # Turmschaft: 3 Zylinder-Sektionen (unten breiter)
    sections = [(0.0, 0.55, tower_r*1.0), (0.55, 1.05, tower_r*0.88), (1.05, height, tower_r*0.75)]
    for si, (z0, z1, rr) in enumerate(sections):
        bpy.ops.mesh.primitive_cylinder_add(
            radius=rr, depth=z1-z0, vertices=12,
            location=(cx, cy, cz+(z0+z1)/2))
        sh = bpy.context.active_object; sh.name = f"{prefix}_Shaft_{si}"
        smooth(sh); vcol(sh, C_STONE if si%2==0 else C_STONE2); parts.append(sh)

    # Etagen-Trennringe
    for ez in [0.55, 1.05]:
        bpy.ops.mesh.primitive_torus_add(
            major_radius=tower_r*1.15, minor_radius=0.025,
            major_segments=16, minor_segments=6,
            location=(cx, cy, cz+ez))
        er = bpy.context.active_object; er.name = f"{prefix}_FloorRing_{int(ez*10)}"
        vcol(er, C_GOLD_C); parts.append(er)

    # Zinnen-Krone (8 Zinnen-Blöcke oben)
    top_z = cz + height
    for zi in range(8):
        za = (zi/8)*math.tau + phi_offset
        zx = cx + math.cos(za)*tower_r*0.85
        zy = cy + math.sin(za)*tower_r*0.85
        bpy.ops.mesh.primitive_cube_add(
            size=0.10, scale=(0.7, 0.7, 1.4 if zi%2==0 else 0.8),
            location=(zx, zy, top_z + 0.06))
        zb = bpy.context.active_object; zb.name = f"{prefix}_Zinne_{zi}"
        vcol(zb, C_STONE2); parts.append(zb)

    # Gotische Turmspitze (zwei verschachtelte Kegel)
    sp_base = (cx, cy, top_z + 0.10)
    sp_tip  = (cx, cy, top_z + 0.55)
    sp = cone(f"{prefix}_Spire", sp_base, sp_tip, tower_r*0.75, 0.012, 8)
    vcol(sp, C_STONE2); parts.append(sp)
    # Spitzen-Flagge
    flag_base = (cx, cy, top_z + 0.50)
    flag_tip  = (cx + 0.18, cy, top_z + 0.50)
    flag_pole = cyl(f"{prefix}_FlagPole", flag_base, flag_tip, 0.010, 4)
    vcol(flag_pole, C_GOLD_C); parts.append(flag_pole)
    bpy.ops.mesh.primitive_cube_add(
        size=0.09, scale=(1.6,0.06,1.0),
        location=(cx+0.27, cy, top_z+0.44))
    flag = bpy.context.active_object; flag.name = f"{prefix}_Flag"
    vcol(flag, C_FLAG); parts.append(flag)

    # 3 Strebepfeiler um den Turm
    for si in range(3):
        sa = phi_offset + (si/3)*math.tau
        bx = cx + math.cos(sa)*tower_r*0.95
        by = cy + math.sin(sa)*tower_r*0.95
        base_buttress = (bx + math.cos(sa)*0.22, by + math.sin(sa)*0.22, cz)
        top_buttress  = (bx, by, cz+0.60)
        bt = cyl(f"{prefix}_Buttress_{si}", base_buttress, top_buttress, 0.038, 6)
        vcol(bt, C_STONE); parts.append(bt)
        # Strebepfeiler-Basis
        bpy.ops.mesh.primitive_cylinder_add(
            radius=0.055, depth=0.10, vertices=6,
            location=(bx + math.cos(sa)*0.22, by + math.sin(sa)*0.22, cz+0.05))
        bb = bpy.context.active_object; bb.name = f"{prefix}_BBase_{si}"
        smooth(bb); vcol(bb, C_STONE2); parts.append(bb)

    # 4 Fenster (kleine leuchtende Rechtecke)
    for wi in range(4):
        wa = phi_offset + (wi/4)*math.tau
        wx = cx + math.cos(wa)*tower_r*0.98
        wy = cy + math.sin(wa)*tower_r*0.98
        bpy.ops.mesh.primitive_cube_add(
            size=0.06, scale=(0.08, 0.06, 1.8),
            location=(wx, wy, cz + 0.72))
        win = bpy.context.active_object; win.name = f"{prefix}_Window_{wi}"
        vcol(win, C_WINDOW); parts.append(win)

    # Runen-Zeichen: 3 leuchtende Würfel am Turm
    for ri in range(3):
        ra = phi_offset + (ri/3)*math.tau
        rx = cx + math.cos(ra)*tower_r*1.02
        ry = cy + math.sin(ra)*tower_r*1.02
        bpy.ops.mesh.primitive_cube_add(
            size=0.052, scale=(0.08,0.08,1.6),
            location=(rx, ry, cz+0.30+ri*0.28))
        rune = bpy.context.active_object; rune.name = f"{prefix}_Rune_{ri}"
        vcol(rune, C_RUNE if ri%2==0 else C_RUNE2); parts.append(rune)

    return parts


# ═══════════════════════════════════════════════════════════════
# BOGEN-BRÜCKEN ZWISCHEN TÜRMEN
# ═══════════════════════════════════════════════════════════════
def create_arch_bridge(phi_a, phi_b, orbit_r, bridge_z=0.65):
    parts = []
    ax, ay = math.cos(phi_a)*orbit_r, math.sin(phi_a)*orbit_r
    bx, by = math.cos(phi_b)*orbit_r, math.sin(phi_b)*orbit_r
    n_seg = 10
    for i in range(n_seg):
        t = i / (n_seg - 1)
        # Bogen-Kurve: quadratische Bézierkurve mit Mittelpunkt-Lift
        px = ax*(1-t)**2 + (ax+bx)/2*2*t*(1-t) + bx*t**2
        py = ay*(1-t)**2 + (ay+by)/2*2*t*(1-t) + by*t**2
        # Bogenhöhe: Mitte ist höher
        lift = 0.22 * math.sin(t*math.pi)
        pz = bridge_z + lift
        if i > 0:
            p0x = ax*(1-(t-1/n_seg))**2 + (ax+bx)/2*2*(t-1/n_seg)*(1-(t-1/n_seg)) + bx*(t-1/n_seg)**2
            p0y = ay*(1-(t-1/n_seg))**2 + (ay+by)/2*2*(t-1/n_seg)*(1-(t-1/n_seg)) + by*(t-1/n_seg)**2
            p0z = bridge_z + 0.22*math.sin((t-1/n_seg)*math.pi)
            seg = cyl(f"Bridge_{int(phi_a*10)}_{int(phi_b*10)}_S{i}", (p0x,p0y,p0z), (px,py,pz), 0.035, 6)
            vcol(seg, C_STONE); parts.append(seg)
        # Bogen-Stütze (vertikale Linie nach unten)
        if i % 3 == 1:
            bpy.ops.mesh.primitive_cylinder_add(
                radius=0.022, depth=lift*0.8, vertices=5,
                location=(px, py, pz - lift*0.4))
            support = bpy.context.active_object; support.name = f"Bridge_Supp_{int(phi_a*10)}_{i}"
            smooth(support); vcol(support, C_STONE2); parts.append(support)
    return parts


# ═══════════════════════════════════════════════════════════════
# SCHWEBENDE RUNENSTEIN-TAFELN
# ═══════════════════════════════════════════════════════════════
def create_rune_stones():
    parts = []
    rune_cfg = [
        # (orbitradius, phi, z, breite, höhe, dicke, neigung)
        (1.45, 0.40, 1.20, 0.28, 0.45, 0.04, 0.3),
        (1.45, 1.60, 1.15, 0.24, 0.40, 0.04, -0.2),
        (1.45, 2.80, 1.10, 0.30, 0.50, 0.04, 0.4),
        (1.45, 4.00, 1.18, 0.26, 0.42, 0.04, -0.3),
        (1.45, 5.20, 1.22, 0.25, 0.44, 0.04, 0.2),
        (1.45, 0.90, -1.00, 0.22, 0.38, 0.04, -0.4),
        (1.45, 2.10, -0.95, 0.28, 0.46, 0.04, 0.3),
        (1.45, 3.30, -1.05, 0.24, 0.40, 0.04, -0.2),
        (1.45, 4.50, -0.98, 0.26, 0.42, 0.04, 0.35),
        (1.45, 5.70, -1.02, 0.22, 0.38, 0.04, -0.25),
    ]
    for i, (r, phi, z, w, h, d, tilt) in enumerate(rune_cfg):
        px, py = math.cos(phi)*r, math.sin(phi)*r
        bpy.ops.mesh.primitive_cube_add(
            size=1.0, scale=(w, d, h),
            location=(px, py, z), rotation=(tilt, 0, phi+math.pi/2))
        stone = bpy.context.active_object; stone.name = f"RuneStone_{i:02d}"
        vcol(stone, C_STONE if i%2==0 else C_STONE2); parts.append(stone)
        # Runen-Inschrift (3 leuchtende Linien auf der Tafel)
        for li in range(3):
            bpy.ops.mesh.primitive_cube_add(
                size=1.0, scale=(w*0.70, d*1.2, h*0.06),
                location=(px + math.cos(phi+math.pi/2)*0.025,
                           py + math.sin(phi+math.pi/2)*0.025,
                           z - h*0.25 + li*h*0.20),
                rotation=(tilt, 0, phi+math.pi/2))
            rune_line = bpy.context.active_object; rune_line.name = f"RuneLine_{i}_{li}"
            vcol(rune_line, C_RUNE if i%2==0 else C_RUNE2); parts.append(rune_line)
        # Schwebender Energie-Kern über der Tafel
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.038, segments=7, ring_count=4,
            location=(px, py, z + h*0.60))
        eg = bpy.context.active_object; eg.name = f"RuneGlow_{i}"
        smooth(eg); vcol(eg, C_ENERGY); parts.append(eg)
    return parts


# ═══════════════════════════════════════════════════════════════
# RUNEN-ENERGIENETZ (verbindet Türme und Runensteine)
# ═══════════════════════════════════════════════════════════════
def create_energy_web():
    parts = []
    tower_phi = [i*(math.tau/5) for i in range(5)]
    orbit_r = 1.80
    # Verbindungs-Strahlen zwischen Türmen (äquatorial)
    for i in range(5):
        p_a = (math.cos(tower_phi[i])*orbit_r, math.sin(tower_phi[i])*orbit_r, 0.82)
        p_b = (math.cos(tower_phi[(i+2)%5])*orbit_r, math.sin(tower_phi[(i+2)%5])*orbit_r, 0.82)
        ray = cyl(f"Web_Ray_{i}", p_a, p_b, 0.012, 5)
        vcol(ray, C_RUNE if i%2==0 else C_RUNE2); parts.append(ray)
    # Energie-Kugeln an Kreuzungspunkten (Mitte zwischen jeweils 2 Türmen)
    for i in range(5):
        m_phi = (tower_phi[i] + tower_phi[(i+1)%5]) / 2
        mp = (math.cos(m_phi)*orbit_r*0.82, math.sin(m_phi)*orbit_r*0.82, 1.05)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.042, segments=7, ring_count=4, location=mp)
        en = bpy.context.active_object; en.name = f"Web_Node_{i}"
        smooth(en); vcol(en, C_ENERGY); parts.append(en)
    # Vertikale Energie-Strahlen von Türmen zur Kugel
    for i in range(5):
        tower_top = (math.cos(tower_phi[i])*orbit_r, math.sin(tower_phi[i])*orbit_r, 1.70)
        orb_pt = (math.cos(tower_phi[i])*1.05, math.sin(tower_phi[i])*1.05, 0.30)
        beam = cyl(f"Web_Beam_{i}", tower_top, orb_pt, 0.015, 5)
        vcol(beam, C_RUNE); parts.append(beam)
        # Energie-Knoten auf halbem Weg
        mid = ((tower_top[0]+orb_pt[0])/2, (tower_top[1]+orb_pt[1])/2, (tower_top[2]+orb_pt[2])/2)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.030, segments=6, ring_count=4, location=mid)
        mn = bpy.context.active_object; mn.name = f"Web_BeamNode_{i}"
        smooth(mn); vcol(mn, C_RUNE2); parts.append(mn)
    return parts


clear_scene()
col = bpy.data.collections.new("Aion_RunicCitadel")
bpy.context.scene.collection.children.link(col)

# 5 Türme gleichmäßig verteilt, orbital bei r=1.80
tower_phi = [i*(math.tau/5) for i in range(5)]
orbit_r = 1.80

all_parts = create_orb()
for i in range(5):
    all_parts += create_tower(f"Tower_{i}", orbit_r, tower_phi[i])
for i in range(5):
    all_parts += create_arch_bridge(tower_phi[i], tower_phi[(i+1)%5], orbit_r)
all_parts += create_rune_stones()
all_parts += create_energy_web()

for obj in all_parts:
    for c in list(obj.users_collection): c.objects.unlink(obj)
    col.objects.link(obj)
print(f"✅ Aion Runic Citadel — {len(all_parts)} Teile")
