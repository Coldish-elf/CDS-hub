import os

prompt = ">>> "

def draw_tree(base_path, colloquium_name, parts_files, main_file):
    print("\nPlanned structure:\n")
    print(f"{base_path.rstrip('/')}/")
    print(f"└─ {colloquium_name}/")
    print(f"   ├─ parts/")
    for i, f in enumerate(parts_files):
        connector = "└─" if i == len(parts_files) - 1 else "├─"
        print(f"   │  {connector} {f}")
    print(f"   └─ {main_file}")
    print()

print("Input relative path:")
base_path = input(prompt).strip()
while not base_path:
    base_path = input("Enter valid path!\n" + prompt).strip()

print("Input colloquium directory name:")
colloquium_name = input(prompt).strip()
while not colloquium_name:
    colloquium_name = input("Enter valid directory name!\n" + prompt).strip()

print("Input number of files in parts/:")
while True:
    try:
        n = int(input(prompt))
        if n > 0:
            break
    except ValueError:
        pass
    print("Enter a positive integer!")

print("Input filenames for parts/ (without .tex):")
parts_files = []
for i in range(n):
    name = input(f"{i+1}: ").strip()
    while not name:
        name = input("Filename cannot be empty!\n" + f"{i+1}: ").strip()
    parts_files.append(name + ".tex")

main_file = colloquium_name + ".tex"

draw_tree(base_path, colloquium_name, parts_files, main_file)

print("Is everything correct? [y/n]")
answer = input(prompt).strip().lower()

if answer not in ("y", "yes"):
    print("Aborted.")
    exit(0)

colloquium_path = os.path.join(base_path, colloquium_name)
parts_path = os.path.join(colloquium_path, "parts")

os.makedirs(parts_path, exist_ok=True)

for f in parts_files:
    with open(os.path.join(parts_path, f), "w", encoding="utf-8") as f: 
        f.write(f"% !TeX root = ../{colloquium_name}.tex")

with open(os.path.join(colloquium_path, main_file), "w", encoding="utf-8") as f:
    f.write(f"% !TeX root = {colloquium_name}.tex")

print("\nStructure successfully created!")
