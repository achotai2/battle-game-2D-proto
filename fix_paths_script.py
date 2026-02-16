import re

with open("Scenes/main.tscn", "r") as f:
    content = f.read()

# 1. Global replace NavigationRegion2D -> NavigationRegion3D
# This fixes parent references and NodePaths.
content = content.replace("NavigationRegion2D", "NavigationRegion3D")

# 2. Remove PointLight2D nodes
# They are at the end of the file.
# We can find them and cut them out.
# [node name="PointLight2D" ...
# until next node or end of file.

# A simple way is to use regex to remove the node block.
# [node name="PointLight2D".*?((?=\[node)|$)
# DOTALL mode.
content = re.sub(r'\[node name="PointLight2D".*?((?=\[node)|$)', '', content, flags=re.DOTALL)

with open("Scenes/main.tscn", "w") as f:
    f.write(content)

print("Fixed paths and removed PointLight2D in Scenes/main.tscn")
