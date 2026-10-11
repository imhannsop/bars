import re, shutil, sys

path = sys.argv[1] if len(sys.argv) > 1 else "TopBar.qml"
s = open(path).read()
shutil.copy(path, path + ".bak")


def sub(pattern, repl, flags=0):
    global s
    s, n = re.subn(pattern, repl, s, flags=flags)
    if n == 0:
        sys.exit("no match for: " + pattern)


# status cluster follows the clock's right edge instead of a hardcoded offset, so its
# changing width no longer fights the x animation
sub(r"PropertyChanges \{ target: statusCluster; x: [^;]*; y:", "PropertyChanges { target: statusCluster; y:")
sub(r"( +)id: statusCluster\n", r"\1id: statusCluster\n\1x: clockDisplay.x - 12 - width\n")

# gaps live inside each item so widths change continuously instead of popping 10px
# when an item's visible flips
sub(r"spacing: 10\n\n( +)readonly property bool charging", r"spacing: 0\n\n\1readonly property bool charging")
sub(r'(text: "\\uf1eb"\n)( +)width: implicitWidth \* \(1\.0 - window\.expandedContentOpacity\)\n( +)opacity: 1\.0 - window\.expandedContentOpacity\n +visible: width > 0\.5\n',
    r"\1\2rightPadding: 10\n\2width: implicitWidth * (1.0 - window.expandedContentOpacity)\n\3opacity: 1.0 - window.expandedContentOpacity\n")
sub(r'(text: "\\uf0e7"\n)', r"\1                        rightPadding: 10\n")
sub(r"( +)width: implicitWidth \* \(statusRow\.charging \? window\.expandedContentOpacity : 1\.0\)\n( +opacity: statusRow\.charging \? window\.expandedContentOpacity : 1\.0\n) +visible: width > 0\.5\n",
    r"\1rightPadding: 10\n\1width: implicitWidth * (statusRow.charging ? window.expandedContentOpacity : 1.0)\n\2")
sub(r"( +)opacity: window\.expandedContentOpacity\n +visible: opacity > 0\.01\n( +\}\n\n +Rectangle \{)",
    r"\1width: implicitWidth * window.expandedContentOpacity\n\1opacity: window.expandedContentOpacity\n\1clip: true\n\2")
sub(r"width: 1\n( +height: 12\n +color: \"#ffffff\"\n +opacity: \(1\.0 - window\.expandedContentOpacity\) \* 0\.4\n) +visible: opacity > 0\.01\n",
    r"width: 1.0 - window.expandedContentOpacity\n\1")

# more breathing room around the panel
sub(r"property real expandedOuterPadding: \d+", "property real expandedOuterPadding: 24")
sub(r"property real expandedHeaderHeight: collapsedHeight \+ \d+", "property real expandedHeaderHeight: collapsedHeight + 16")

open(path, "w").write(s)
print("patched, backup at", path + ".bak")
