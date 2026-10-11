import re, shutil, sys

path = sys.argv[1] if len(sys.argv) > 1 else "TopBar.qml"
s = open(path).read()
shutil.copy(path, path + ".bak5")


def sub(pattern, repl):
    global s
    s, n = re.subn(pattern, repl, s)
    if n == 0:
        sys.exit("no match for: " + pattern)


# extra inset for the bottom row only, the cards keep their own edges
sub(r"( +)property real expandedFooterHeight: (\d+)\n",
    r"\1property real expandedFooterHeight: \2\n\1property real expandedRowInset: 8\n")

# dots on the left, clock right beside them
sub(r"(PropertyChanges \{ target: wsIndicator; x: window\.expandedNotchRadius \+ window\.expandedOuterPadding);",
    r"\1 + window.expandedRowInset;")
sub(r"(PropertyChanges \{ target: clockDisplay; x: )[^;]*(; y: window\.expandedHeaderHeight)",
    r"\1window.expandedNotchRadius + window.expandedOuterPadding + window.expandedRowInset + wsIndicator.implicitWidth + 14\2")

# battery alone at the bottom right
sub(r"rightEdge: window\.expandedNotchRadius \+ window\.expandedWidth - window\.expandedOuterPadding - window\.collapsedClockWidth - 12;",
    "rightEdge: window.expandedNotchRadius + window.expandedWidth - window.expandedOuterPadding - window.expandedRowInset;")

open(path, "w").write(s)
print("patched, backup at", path + ".bak5")
