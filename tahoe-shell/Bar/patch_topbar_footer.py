import re, shutil, sys

path = sys.argv[1] if len(sys.argv) > 1 else "TopBar.qml"
s = open(path).read()
shutil.copy(path, path + ".bak2")


def sub(pattern, repl, count=0, flags=0):
    global s
    s, n = re.subn(pattern, repl, s, count=count, flags=flags)
    if n == 0:
        sys.exit("no match for: " + pattern)


# footer strip under the cards
sub(r"( +)property real expandedOuterPadding: (\d+)\n", r"\1property real expandedOuterPadding: \2\n\1property real expandedFooterHeight: 34\n")
sub(r"property real expandedHeight: expandedHeaderHeight \+ controlCenter\.implicitHeight \+ expandedOuterPadding",
    "property real expandedHeight: expandedHeaderHeight + controlCenter.implicitHeight + expandedFooterHeight + expandedOuterPadding")

# the cluster's right edge is what gets animated; its width changes while it moves, so
# targeting a width-dependent x would snapshot the wrong end value
sub(r"( +)x: clockDisplay\.x - 12 - width\n",
    r"\1property real rightEdge: window.collapsedWidth + window.collapsedNotchRadius - 20 - window.collapsedClockWidth - 12\n\1x: rightEdge - width\n")

edges = iter([
    "window.collapsedWidth + window.collapsedNotchRadius - 20 - window.collapsedClockWidth - 12",
    "window.peekWidth + window.collapsedNotchRadius - 20 - window.collapsedClockWidth - 12",
    "window.expandedNotchRadius + window.expandedWidth - window.expandedOuterPadding",
])
footerY = "window.expandedHeaderHeight + controlCenter.implicitHeight + window.expandedFooterHeight / 2"


def cluster_state(m):
    edge = next(edges)
    if "expandedWidth" in edge:
        return "PropertyChanges { target: statusCluster; rightEdge: %s; y: %s - statusCluster.height / 2 }" % (edge, footerY)
    return "PropertyChanges { target: statusCluster; rightEdge: %s; y: (window.collapsedHeight - statusCluster.height) / 2 }" % edge


s, n = re.subn(r"PropertyChanges \{ target: statusCluster; y: \(window\.collapsedHeight - statusCluster\.height\) / 2 \}", cluster_state, s)
if n != 3:
    sys.exit("expected 3 statusCluster states, found %d" % n)

sub(r"PropertyChanges \{ target: wsIndicator; x: window\.expandedNotchRadius \+ 20; y: \(window\.collapsedHeight - wsIndicator\.implicitHeight\) / 2 \}",
    "PropertyChanges { target: wsIndicator; x: window.expandedNotchRadius + window.expandedOuterPadding; y: %s - wsIndicator.implicitHeight / 2 }" % footerY)

# animate the new property wherever x/y already animate
sub(r'(properties: "barWidth,barHeight,notchRadius,bottomRadius,clockFontSize,clockXScale,clockYScale,x,y)"', r'\1,rightEdge"')
sub(r'(targets: \[wsIndicator, clockDisplay, statusCluster\]; properties: "x,y)"', r'\1,rightEdge"')

open(path, "w").write(s)
print("patched, backup at", path + ".bak2")
