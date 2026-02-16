import os
import re

def convert_vector2_to_vector3(match):
    # vector2 string is like "Vector2(100, 200)"
    content = match.group(1) # "100, 200"
    parts = content.split(',')
    if len(parts) == 2:
        x = parts[0].strip()
        y = parts[1].strip()
        # Map 2D (x, y) to 3D (x, 0, y)
        return f"Vector3({x}, 0, {y})"
    return match.group(0)

def convert_rotation(match):
    # rotation = 1.57
    val = match.group(1).strip()
    # Map rotation around Z (2D) to rotation around Y (3D) ??
    # Or maybe just clear it or default it.
    # But usually 2D rotation means facing direction. In 3D top down, that is Y axis.
    return f"rotation = Vector3(0, -{val}, 0)" # Negative because 2D Y-down vs 3D Y-up?
    # Actually, 2D rotation 0 is Right. 90 is Down.
    # 3D Y rotation 0 is ...? usually Forward (-Z) or Right (+X)?
    # Let's just do Vector3(0, val, 0) and fix orientation manually later if needed.
    return f"rotation = Vector3(0, {val}, 0)"

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # 1. Node Type Replacements
    replacements = {
        'type="Node2D"': 'type="Node3D"',
        'type="Sprite2D"': 'type="Sprite3D"',
        'type="CollisionShape2D"': 'type="CollisionShape3D"',
        'type="Area2D"': 'type="Area3D"',
        'type="NavigationAgent2D"': 'type="NavigationAgent3D"',
        'type="CharacterBody2D"': 'type="CharacterBody3D"',
        'type="VisibleOnScreenNotifier2D"': 'type="VisibleOnScreenNotifier3D"',
        'type="RayCast2D"': 'type="RayCast3D"',
        'type="Camera2D"': 'type="Camera3D"',
        'type="Marker2D"': 'type="Marker3D"',
        'type="Path2D"': 'type="Path3D"',
        'type="PathFollow2D"': 'type="PathFollow3D"',
        'type="CircleShape2D"': 'type="CylinderShape3D"', # Mapping Circle to Cylinder
        'type="RectangleShape2D"': 'type="BoxShape3D"',     # Mapping Rect to Box
        'type="NavigationPolygon"': 'type="NavigationMesh"',
    }

    for old, new in replacements.items():
        content = content.replace(old, new)

    # 2. Resource Type Replacements (in sub_resources)
    # [sub_resource type="CircleShape2D" id="..."]
    content = content.replace('type="CircleShape2D"', 'type="CylinderShape3D"')
    content = content.replace('type="RectangleShape2D"', 'type="BoxShape3D"')

    # 3. Property Replacements
    # Vector2(x, y) -> Vector3(x, 0, y)
    content = re.sub(r'Vector2\(([^)]+)\)', convert_vector2_to_vector3, content)

    # rotation = float -> rotation = Vector3(0, float, 0)
    # Regex for "rotation = 1.234" (end of line or space)
    # But be careful not to match other things.
    # In .tscn, properties are lines like "position = Vector2(...)"
    # "rotation = 0.0"
    content = re.sub(r'^rotation = ([-0-9.e]+)$', convert_rotation, content, flags=re.MULTILINE)

    # Fix Shapes
    # CylinderShape3D uses 'height' and 'radius'. CircleShape2D uses 'radius'.
    # We keep 'radius'. Add default 'height = 2.0'.
    # BoxShape3D uses 'size' (Vector3). RectangleShape2D uses 'size' (Vector2).
    # We already converted Vector2->Vector3 in step 3.
    # So "size = Vector2(x, y)" became "size = Vector3(x, 0, y)".
    # Ideally size should be (x, 1, y) or (x, y, 1).
    # Let's correct Vector3(x, 0, y) to Vector3(x, 2, y) for shapes specifically?
    # Hard to target contextually with simple regex.
    # Let's fix the "size = Vector3(x, 0, y)" pattern to "size = Vector3(x, 1, y)" assuming it came from conversion
    content = re.sub(r'size = Vector3\(([0-9.]+), 0, ([0-9.]+)\)', r'size = Vector3(\1, 1, \2)', content)

    # 4. Sprite3D Billboard
    # If we find [node ... type="Sprite3D" ...], we want to ensure it has billboard enabled if it's a unit.
    # But simpler: just add "billboard = 1" to all Sprite3D nodes?
    # In .tscn, properties follow the node declaration.
    # We can try to insert it. But parsing indentation is annoying.
    # Let's leave billboard for manual tuning or set it on base scenes.
    # Actually, replacing 'type="Sprite2D"' with 'type="Sprite3D"\nbillboard = 1' might work if formatting allows.
    # But usually properties are separate lines.

    with open(filepath, 'w') as f:
        f.write(content)
    print(f"Converted {filepath}")

for root, dirs, files in os.walk("."):
    for file in files:
        if file.endswith(".tscn"):
            process_file(os.path.join(root, file))
