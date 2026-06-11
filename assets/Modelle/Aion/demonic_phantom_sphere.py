
import bpy, bmesh, math
from mathutils import Vector

# ============================================================
# DEMONIC PHANTOM SPHERE (ROBLOX SAFE)
# Vertex Colors only / FBX friendly
# ============================================================

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

def smooth(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth()

def apply_vcol(obj, color):
    if obj.type != 'MESH':
        return
    mesh = obj.data
    if "Color" not in mesh.color_attributes:
        mesh.color_attributes.new(
            name="Color",
            type='FLOAT_COLOR',
            domain='CORNER'
        )
    attr = mesh.color_attributes["Color"]
    for d in attr.data:
        d.color = color

def bone(name, start, end, radius=0.05):
    s = Vector(start)
    e = Vector(end)
    vec = e - s
    length = vec.length
    mid = (s + e) / 2

    bpy.ops.mesh.primitive_cylinder_add(
        radius=radius,
        depth=length,
        vertices=12,
        location=mid
    )
    obj = bpy.context.active_object
    obj.name = name

    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = vec.to_track_quat('Z', 'Y')
    smooth(obj)
    return obj

def claw(name, start, end, r=0.03):
    s = Vector(start)
    e = Vector(end)
    vec = e - s
    length = vec.length

    bpy.ops.mesh.primitive_cone_add(
        radius1=r,
        radius2=0,
        depth=length,
        vertices=8,
        location=(s + e) / 2
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = vec.to_track_quat('Z', 'Y')
    smooth(obj)
    return obj

def create_membrane(name, verts, thickness=0.035):
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)

    bm = bmesh.new()

    top = [bm.verts.new((v[0], v[1]+thickness, v[2])) for v in verts]
    bottom = [bm.verts.new((v[0], v[1]-thickness, v[2])) for v in verts]

    bm.faces.new(top)
    bm.faces.new(reversed(bottom))

    for i in range(len(top)):
        j = (i + 1) % len(top)
        bm.faces.new([top[i], top[j], bottom[j], bottom[i]])

    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    smooth(obj)
    return obj

def create_wing(side="L"):
    m = 1 if side == "L" else -1
    parts = []

    def p(x,y,z):
        return (x*m, y, z)

    shoulder = p(1.2,0,0.2)
    elbow = p(2.8,-0.2,0.5)
    wrist = p(4.4,-0.4,0.1)

    fingers = [
        p(6.6,-0.4,1.8),
        p(7.0,-0.35,0.7),
        p(6.5,-0.3,-0.4),
        p(5.7,-0.2,-1.8)
    ]

    arm = bone(f"{side}_arm", shoulder, elbow, 0.08)
    forearm = bone(f"{side}_forearm", elbow, wrist, 0.06)
    apply_vcol(arm, (0.72,0.69,0.62,1))
    apply_vcol(forearm, (0.72,0.69,0.62,1))
    parts.extend([arm, forearm])

    membrane_points = [shoulder]

    for i, finger in enumerate(fingers):
        b = bone(f"{side}_finger_{i}", wrist, finger, 0.035)
        c = claw(
            f"{side}_claw_{i}",
            finger,
            (finger[0], finger[1], finger[2] + (0.4 if i < 2 else -0.4))
        )
        apply_vcol(b, (0.72,0.69,0.62,1))
        apply_vcol(c, (0.92,0.88,0.78,1))
        parts.extend([b,c])
        membrane_points.append(finger)

    membrane_points.extend([
        p(4.8,-0.25,-2.2),
        p(3.2,-0.1,-1.5),
        p(1.6,0,-0.6)
    ])

    mem = create_membrane(f"{side}_membrane", membrane_points)
    apply_vcol(mem, (0.08,0.01,0.12,1))
    parts.append(mem)

    return parts

def create_cracked_sphere():
    parts = []

    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=1.25,
        segments=48,
        ring_count=24,
        location=(0,0,0)
    )
    sphere = bpy.context.active_object
    sphere.name = "DemonicSphere"
    smooth(sphere)
    apply_vcol(sphere, (0.03,0.02,0.05,1))
    parts.append(sphere)

    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.65,
        segments=24,
        ring_count=12,
        location=(0,0,0)
    )
    core = bpy.context.active_object
    core.name = "EnergyCore"
    smooth(core)
    apply_vcol(core, (0.65,0.05,0.08,1))
    parts.append(core)

    # cracked shards
    shard_positions = [
        (1.0,0.3,0.5),
        (-1.1,-0.2,-0.3),
        (0.2,1.2,-0.5),
        (-0.5,-1.1,0.4),
        (0.7,-0.8,1.0)
    ]

    for i,pos in enumerate(shard_positions):
        bpy.ops.mesh.primitive_cube_add(
            size=0.35,
            scale=(0.12,0.4,0.05),
            location=pos,
            rotation=(i, i*0.4, i*0.7)
        )
        shard = bpy.context.active_object
        shard.name = f"Shard_{i}"
        smooth(shard)
        apply_vcol(shard, (0.18,0.08,0.22,1))
        parts.append(shard)

    return parts

clear_scene()

collection = bpy.data.collections.new("Demonic_Phantom_Sphere")
bpy.context.scene.collection.children.link(collection)

objects = []
objects.extend(create_cracked_sphere())
objects.extend(create_wing("L"))
objects.extend(create_wing("R"))

for obj in objects:
    for c in obj.users_collection:
        c.objects.unlink(obj)
    collection.objects.link(obj)

print("Done: Demonic Phantom Sphere generated.")
