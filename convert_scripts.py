import os
import re

def replace_vector2_constructor(match):
    # Vector2(x, y) -> Vector3(x, 0, y)
    content = match.group(1)
    return f"Vector3({content}, 0)" # Wait, Vector2(x, y). Vector3(x, y, z).
    # If I just replace Vector2 with Vector3, I get Vector3(x, y). That is (x, y, 0).
    # But usually 2D x,y maps to 3D x,z.
    # So Vector3(x, 0, y) is better.

    # We need to parse args.
    # This is hard with regex if args contain commas (functions).
    # Let's try a simpler approach:
    # If we see Vector2(a, b), we replace with Vector3(a, 0, b).
    return f"Vector3({match.group(1)}, 0, {match.group(2)})"

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # 1. Class Extensions
    replacements = {
        'extends Node2D': 'extends Node3D',
        'extends CharacterBody2D': 'extends CharacterBody3D',
        'extends Area2D': 'extends Area3D',
        'extends NavigationAgent2D': 'extends NavigationAgent3D',
        'extends Sprite2D': 'extends Sprite3D',
        'extends RayCast2D': 'extends RayCast3D',
        'extends VisibleOnScreenNotifier2D': 'extends VisibleOnScreenNotifier3D',
        'extends Camera2D': 'extends Camera3D',
        'extends Path2D': 'extends Path3D',
        'extends PathFollow2D': 'extends PathFollow3D',
        'extends Marker2D': 'extends Marker3D',

        # 2. Vector Constants
        'Vector2.UP': 'Vector3.FORWARD',
        'Vector2.DOWN': 'Vector3.BACK',
        'Vector2.LEFT': 'Vector3.LEFT',
        'Vector2.RIGHT': 'Vector3.RIGHT',
        'Vector2.ZERO': 'Vector3.ZERO',
        'Vector2.ONE': 'Vector3.ONE',
        'Vector2.INF': 'Vector3(INF, INF, INF)',

        # 3. Type hints
        ': Vector2': ': Vector3',
        '-> Vector2': '-> Vector3',
        'var Vector2': 'var Vector3', # unlikely but possible

        # 4. Common 2D methods/properties on nodes
        # 'rotation': 'rotation.y', # Too risky to replace globally. Context matters.
        # 'rotation_degrees': 'rotation_degrees.y',

        # 5. Physics Query
        'PhysicsShapeQueryParameters2D': 'PhysicsShapeQueryParameters3D',
        'intersect_shape': 'intersect_shape', # same name
        'get_world_2d()': 'get_world_3d()',
        'direct_space_state': 'direct_space_state', # same
    }

    for old, new in replacements.items():
        content = content.replace(old, new)

    # 6. Vector2 Constructor Logic
    # Replace "Vector2(a, b)" with "Vector3(a, 0, b)"
    # Pattern: Vector2\s*\(([^,]+),([^)]+)\)
    # This assumes no nested parens in args.
    # content = re.sub(r'Vector2\s*\(([^,]+),\s*([^)]+)\)', r'Vector3(\1, 0, \2)', content)
    # Actually, simpler: just rename Vector2 to Vector3 and let user fix the 3rd arg?
    # No, automated is better.
    # Let's try to capture balanced parens? No, too hard.
    # Let's stick to simple args (numbers, variables).

    # 7. Angle
    # .angle() -> .signed_angle_to(Vector3.FORWARD, Vector3.UP) ??
    # Or just replace usage.

    # 8. Mouse
    content = content.replace('get_global_mouse_position()', 'GamePhysics.get_global_mouse_position_3d(get_viewport().get_camera_3d(), get_viewport().get_mouse_position())')

    # 9. Global generic replacements
    content = content.replace('Vector2', 'Vector3') # Final sweep for any remaining

    # 10. Fix "Vector3(x, 0, y)" if we did the regex?
    # Let's try the regex for simple cases
    # We find "Vector3(x, y)" (because we replaced Vector2 with Vector3) and want "Vector3(x, 0, y)"?
    # No, let's do the specific regex BEFORE the generic replacement.

    # Reload content to restart cleanly
    with open(filepath, 'r') as f:
        content = f.read()

    for old, new in replacements.items():
        content = content.replace(old, new)

    # Specific Vector2(x, y) -> Vector3(x, 0, y)
    # We only match if args don't have nested parens to avoid breaking functions
    content = re.sub(r'Vector2\s*\(\s*([a-zA-Z0-9_.]+)\s*,\s*([a-zA-Z0-9_.]+)\s*\)', r'Vector3(\1, 0, \2)', content)

    # Now replace remaining Vector2
    content = content.replace('Vector2', 'Vector3')

    # Replace "rotation" with "rotation.y" if it looks like an assignment or access on a Node?
    # "rotation =" -> "rotation.y ="
    # "rotation +=" -> "rotation.y +="
    content = re.sub(r'(?<!\.)rotation\s*=', 'rotation.y =', content)
    content = re.sub(r'(?<!\.)rotation\s*\+=', 'rotation.y +=', content)
    content = re.sub(r'(?<!\.)rotation\s*-=', 'rotation.y -=', content)

    # "rotation_degrees"
    content = re.sub(r'(?<!\.)rotation_degrees\s*=', 'rotation_degrees.y =', content)

    with open(filepath, 'w') as f:
        f.write(content)
    print(f"Converted {filepath}")

for root, dirs, files in os.walk("."):
    for file in files:
        if file.endswith(".gd"):
            process_file(os.path.join(root, file))
