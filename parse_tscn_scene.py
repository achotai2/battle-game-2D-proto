import re

def main():
    with open("Scenes/Buildings/house.tscn") as f:
        content = f.read()

    print("ExtResource for House_Blue.png:")
    for match in re.findall(r'\[ext_resource type="(.*?)" uid="(.*?)" path="(.*?House_Blue\.png)".*?\]', content):
        print(match)

    print("\nExtResource for House_Construction.png:")
    for match in re.findall(r'\[ext_resource type="(.*?)" uid="(.*?)" path="(.*?House_Construction\.png)".*?\]', content):
        print(match)

if __name__ == "__main__":
    main()
