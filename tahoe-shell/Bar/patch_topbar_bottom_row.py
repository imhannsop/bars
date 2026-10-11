import re, shutil, sys

path = sys.argv[1] if len(sys.argv) > 1 else "TopBar.qml"
s = open(path).read()
shutil.copy(path, path + ".bak3")


def sub(pattern, repl):
    global s
    s, n = re.subn(pattern, repl, s)
    if n == 0:
        sys.exit("no match for: " + pattern)


footerY = "window.expandedHeaderHeight + controlCenter.implicitHeight + window.expandedFooterHeight / 2"

# nothing sits above the cards any more, so they start right under the top padding
sub(r"property real expandedHeaderHeight: collapsedHeight \+ \d+", "property real expandedHeaderHeight: expandedOuterPadding")
sub(r"property real expandedGap: \d+", "property real expandedGap: 16")
sub(r"property real expandedFooterHeight: \d+", "property real expandedFooterHeight: 38")

# the clock joins the bottom row, right-aligned to the cards
sub(r"PropertyChanges \{ target: clockDisplay; x: window\.expandedWidth \+ window\.expandedNotchRadius - 20 - window\.collapsedClockWidth; y: [^}]*\}",
    "PropertyChanges { target: clockDisplay; x: window.expandedNotchRadius + window.expandedWidth - window.expandedOuterPadding - window.collapsedClockWidth; y: %s - window.collapsedClockHeight / 2 }" % footerY)

# the battery sits right before the clock, like it does in the collapsed bar
sub(r"rightEdge: window\.expandedNotchRadius \+ window\.expandedWidth - window\.expandedOuterPadding;",
    "rightEdge: window.expandedNotchRadius + window.expandedWidth - window.expandedOuterPadding - window.collapsedClockWidth - 12;")

# tapping the bottom row collapses the panel, same as tapping the old top row did
sub(r"if \(!window\.expanded \|\| mouse\.y < window\.expandedHeaderHeight\)",
    "if (!window.expanded || mouse.y < window.expandedHeaderHeight || mouse.y > window.expandedHeaderHeight + controlCenter.implicitHeight)")

open(path, "w").write(s)
print("patched, backup at", path + ".bak3")
