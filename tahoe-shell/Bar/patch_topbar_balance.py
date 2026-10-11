import re, shutil, sys

path = sys.argv[1] if len(sys.argv) > 1 else "TopBar.qml"
s = open(path).read()
shutil.copy(path, path + ".bak4")


def sub(pattern, repl):
    global s
    s, n = re.subn(pattern, repl, s)
    if n == 0:
        sys.exit("no match for: " + pattern)


# the row is centred in the footer strip, so with no extra bottom padding the space
# above and below it is the same
sub(r"property real expandedFooterHeight: \d+", "property real expandedFooterHeight: 50")
sub(r"(expandedHeaderHeight \+ controlCenter\.implicitHeight \+ expandedFooterHeight) \+ expandedOuterPadding", r"\1")

open(path, "w").write(s)
print("patched, backup at", path + ".bak4")
