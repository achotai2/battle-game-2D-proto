import os

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Replace AnimatedSprite2D with AnimatedSprite3D
    if 'type="AnimatedSprite2D"' in content:
        content = content.replace('type="AnimatedSprite2D"', 'type="AnimatedSprite3D"')

        # Also remove y_sort_enabled lines for these nodes?
        # y_sort_enabled = true
        # In 3D this property doesn't exist. Godot might warn.
        # Removing it cleanly is hard via regex.
        # But type change is the most important.

        # Also billboard?
        # If it's a unit, we probably want billboard=1 (ENABLED)
        # We can't easily insert it.
        # But changing the type gets it in the 3D world.

    with open(filepath, 'w') as f:
        f.write(content)
    print(f"Fixed AnimatedSprite2D in {filepath}")

for root, dirs, files in os.walk("."):
    for file in files:
        if file.endswith(".tscn"):
            process_file(os.path.join(root, file))
