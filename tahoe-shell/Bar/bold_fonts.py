import os, re, shutil, sys

root = sys.argv[1] if len(sys.argv) > 1 else "."
backup = os.path.join(root, ".font-backup")
os.makedirs(backup, exist_ok=True)

WEIGHT = re.compile(r"\b((?:font\.)?weight): Font\.(Medium|Normal|DemiBold|Light|ExtraLight|Thin|Regular)\b")
FAMILY = re.compile(r'font\.family: "[^"]*"')


def indent(line):
    return len(line) - len(line.lstrip())


def is_icon_block(lines, i):
    # icon glyphs use Font Awesome at Font.Black, so leave any block that sets that font alone
    ind = indent(lines[i])
    start = i
    while start > 0 and (not lines[start].strip() or indent(lines[start]) >= ind):
        start -= 1
    end = i
    while end + 1 < len(lines) and (not lines[end + 1].strip() or indent(lines[end + 1]) >= ind):
        end += 1
    return "wesome" in "".join(lines[start:end + 2])


changed = []
for name in sorted(os.listdir(root)):
    if not name.endswith(".qml"):
        continue
    path = os.path.join(root, name)
    lines = open(path).read().split("\n")
    out = list(lines)
    touched = False
    for i, line in enumerate(lines):
        new = line
        if FAMILY.search(line) and "wesome" not in line:
            new = FAMILY.sub("font.family: Theme.fontFamily", new)
        m = WEIGHT.search(new)
        if m and (line.lstrip().startswith("ToolTip.toolTip.font") or not is_icon_block(lines, i)):
            new = WEIGHT.sub(r"\1: Font.Bold", new)
        if new != line:
            out[i] = new
            touched = True
    if not touched:
        continue
    text = "\n".join(out)
    if "Theme." in text and name != "Theme.qml" and 'import "."' not in text:
        text = re.sub(r"(import [^\n]+\n)(?!import)", r'\1import "."\n', text, count=1)
    shutil.copy(path, os.path.join(backup, name))
    open(path, "w").write(text)
    changed.append(name)

print("updated:", ", ".join(changed) if changed else "nothing to change")
print("originals saved in", backup)
