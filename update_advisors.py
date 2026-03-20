import os
import re

advisor_dir = "Scripts/AgentNodes/Advisors"

for filename in os.listdir(advisor_dir):
    if filename.endswith(".gd"):
        filepath = os.path.join(advisor_dir, filename)
        with open(filepath, "r") as f:
            content = f.read()

        if "func get_intent(" in content:
            content = content.replace("func get_intent(", "func _calculate_intent(")

            with open(filepath, "w") as f:
                f.write(content)

            print(f"Updated {filename}")
