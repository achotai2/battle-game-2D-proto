import os
import re

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # 1. Fix Scale: Vector3(x, 0, z) -> Vector3(x, 1, z)
    # This applies to 3D nodes scale.
    # We regex for "scale = Vector3(..., 0, ...)"
    # Pattern: scale = Vector3\(([^,]+),\s*0,\s*([^)]+)\)
    content = re.sub(r'scale = Vector3\(([^,]+),\s*0,\s*([^)]+)\)', r'scale = Vector3(\1, 1, \2)', content)

    # 2. Fix Sprite3D/AnimatedSprite3D offset
    # offset is Vector2. My script made it Vector3(x, 0, y).
    # We need to change it back to Vector2(x, y).
    # Pattern: offset = Vector3(x, 0, y) -> offset = Vector2(x, y)
    content = re.sub(r'offset = Vector3\(([^,]+),\s*0,\s*([^)]+)\)', r'offset = Vector2(\1, \2)', content)

    # 3. Fix UI Nodes (Control, Label, etc)
    # If the file is in Scenes/UI, we should probably revert ALL Vector3 to Vector2?
    # Or if the node type is Control/Label/etc.
    # Identifying node types and their properties specifically is hard with simple regex.
    # But files in Scenes/UI/ are definitely 2D.
    is_ui_folder = "Scenes/UI/" in filepath

    if is_ui_folder:
        # Revert Vector3(x, 0, y) -> Vector2(x, y) globally in these files.
        content = re.sub(r'Vector3\(([^,]+),\s*0,\s*([^)]+)\)', r'Vector2(\1, \2)', content)
        # Also Vector3(x, 1, y) (if I just fixed scale above) -> Vector2(x, y) (scale 1 is fine for 2D too, but z=1 is extra)
        # Actually scale in 2D is Vector2.
        # So Vector3(x, 1, y) -> Vector2(x, y).
        content = re.sub(r'Vector3\(([^,]+),\s*1,\s*([^)]+)\)', r'Vector2(\1, \2)', content)
        # Revert Camera3D to Camera2D if in UI? Unlikely to have camera in UI.

    # 4. AgentNodes UI scenes (InteractPrompt, GoldHolder, HungerHolder)
    # These might be Control nodes or Node2D nodes attached to units?
    # If they are Control nodes, they need Vector2.
    # Let's check specific files.
    # interact_prompt.tscn, GoldHolder.tscn, HungerHolder.tscn.

    if filepath.endswith("interact_prompt.tscn") or filepath.endswith("GoldHolder.tscn") or filepath.endswith("HungerHolder.tscn"):
        # Check root node type.
        # If root is Control, revert Vector3.
        # Reading line by line to find node types is better.
        pass # Hard to do safely.
        # But if they are overlays, they might be Sprite3D (billboard).
        # If they are Sprite3D, offset is Vector2 (fixed in step 2).
        # Position is Vector3 (Node3D).
        # If they were Control nodes, they should probably stay Control nodes (2D UI).
        # My convert_scenes.py didn't convert "Control" -> "Control3D".
        # So they are still "Control" nodes but with "Vector3" properties.
        # Godot will error loading a Control node with Vector3 position/scale.

        # We need to revert Vector3 to Vector2 for Control nodes.
        # Heuristic: If we see `[node ... type="Control"` (or Label/TextureRect/etc), the subsequent properties until next node should be Vector2.
        pass

    with open(filepath, 'w') as f:
        f.write(content)
    print(f"Fixed critical errors in {filepath}")

# We need a more robust pass for UI nodes in mixed files or specific files.
# Let's define a list of UI node types.
UI_TYPES = {"Control", "Label", "Button", "TextureRect", "ColorRect", "VBoxContainer", "HBoxContainer", "CenterContainer", "Panel", "RichTextLabel", "MarginContainer"}

def fix_ui_nodes(filepath):
    with open(filepath, 'r') as f:
        lines = f.readlines()

    new_lines = []
    current_node_is_ui = False

    for line in lines:
        if line.strip().startswith("[node "):
            # Check type
            current_node_is_ui = False
            for t in UI_TYPES:
                if f'type="{t}"' in line:
                    current_node_is_ui = True
                    break
            new_lines.append(line)
        elif current_node_is_ui:
            # Fix properties
            # position = Vector3(x, 0, y) -> position = Vector2(x, y)
            # scale = Vector3(x, 1, y) -> scale = Vector2(x, y)
            # size = Vector3(...) -> size = Vector2(...)
            # anchors_preset ...

            # Regex replacement on the line
            line = re.sub(r'Vector3\(([^,]+),\s*[01],\s*([^)]+)\)', r'Vector2(\1, \2)', line)
            new_lines.append(line)
        else:
            new_lines.append(line)

    with open(filepath, 'w') as f:
        f.writelines(new_lines)

# Run general fix first
for root, dirs, files in os.walk("."):
    for file in files:
        if file.endswith(".tscn"):
            process_file(os.path.join(root, file))

# Run UI fix
for root, dirs, files in os.walk("."):
    for file in files:
        if file.endswith(".tscn"):
            fix_ui_nodes(os.path.join(root, file))
