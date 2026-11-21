#!/usr/bin/env python3
"""Pin dependencies that need Swift 6.3 to versions that build with Swift 6.2 (Xcode 26).

openyard-cloud fork: upstream builds with Xcode 27. swift-log 1.17 uses an attribute that only Swift 6.3
knows, and 1.16.2 satisfies every constraint in this repository. Run after `swift package resolve`.
"""
import pathlib
import subprocess
import sys

PINS = {"swift-log": ("1.16.2", "https://github.com/apple/swift-log.git")}
ROOT = pathlib.Path(__file__).resolve().parent.parent
SUBMODULES = {"AXorcist", "Commander", "Swiftdansi", "Tachikoma", "TauTUI"}


def tag_revision(url, tag):
    out = subprocess.run(["git", "ls-remote", url, f"refs/tags/{tag}^{{}}", f"refs/tags/{tag}"],
                         check=True, capture_output=True, text=True).stdout.split()
    return out[0] if out else None


def pin_text(text, identity, version, revision):
    """Rewrite one pin in place, keeping the file's own formatting."""
    import re
    block = re.compile(r'("identity"\s*:\s*"' + re.escape(identity) + r'".*?"state"\s*:\s*\{)(.*?)(\})', re.S)
    match = block.search(text)
    if not match or f'"{version}"' in match.group(2):
        return text
    state = match.group(2)
    state = re.sub(r'("revision"\s*:\s*")[0-9a-f]+(")', r'\g<1>' + revision + r'\2', state)
    state = re.sub(r'("version"\s*:\s*")[^"]+(")', r'\g<1>' + version + r'\2', state)
    return text[:match.start(2)] + state + text[match.end(2):]


def main():
    changed = 0
    revisions = {}
    for resolved in sorted(ROOT.glob("**/Package.resolved")):
        parts = resolved.relative_to(ROOT).parts
        if ".build" in parts or "node_modules" in parts or parts[0] in SUBMODULES:
            continue
        text = resolved.read_text()
        new = text
        for identity, (version, url) in PINS.items():
            if f'"{identity}"' not in new:
                continue
            if identity not in revisions:
                revisions[identity] = tag_revision(url, version)
                if not revisions[identity]:
                    sys.exit(f"tag {version} not found for {identity}")
            new = pin_text(new, identity, version, revisions[identity])
        if new != text:
            resolved.write_text(new)
            print(f"pinned in {resolved.relative_to(ROOT)}")
            changed += 1
    print(f"{changed} file(s) changed")


if __name__ == "__main__":
    main()
