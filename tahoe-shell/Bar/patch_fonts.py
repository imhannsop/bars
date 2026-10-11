import glob, os, re, shutil, sys

folder = sys.argv[1] if len(sys.argv) > 1 else "."
icon_fonts = ("awesome", "mono", "brands", "symbols")
light = r"Font\.(?:Thin|ExtraLight|Light|Normal|Regular|Medium|DemiBold)"


def fix_family(m):
    name = m.group(2)
    if any(k in name.lower() for k in icon_fonts):
        return m.group(0)
    return m.group(1) + "Theme.fontFamily"


changed = 0
for path in sorted(glob.glob(os.path.join(folder, "*.qml"))):
    src = open(path).read()
    out = re.sub(r'(font\.family:\s*)"([^"]*)"', fix_family, src)
    out = re.sub(r"(font\.weight:\s*)" + light, r"\1Font.Bold", out)
    out = re.sub(r"(ToolTip\.toolTip\.font\.weight:\s*)" + light, r"\1Font.Bold", out)
    if path.endswith("Theme.qml"):
        out = re.sub(r"(weight:\s*)" + light, r"\1Font.Bold", out)
    if out != src:
        shutil.copy(path, path + ".bak7")
        open(path, "w").write(out)
        n = sum(1 for a, b in zip(src.splitlines(), out.splitlines()) if a != b)
        print("%-28s %d lines" % (os.path.basename(path), n))
        changed += 1

print("done" if changed else "nothing to change")
