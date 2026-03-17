with open("Scripts/BuildingNodes/BuildingVisuals.gd") as f:
    text = f.read()

import re
print("Matches:", re.findall(r'elif frames is Texture2D.*', text))
