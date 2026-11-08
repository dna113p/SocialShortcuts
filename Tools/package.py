#!/usr/bin/env python3
"""Build an installable ZIP containing the addon's runtime files and documentation."""
import argparse
from pathlib import Path
import re
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version", help="Version to put in the TOC, e.g. 1.1.0-dj.1")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+(?:[-+][A-Za-z0-9.-]+)?", args.version):
        parser.error("version must be a semantic version without a v prefix")

    root = Path(__file__).resolve().parent.parent
    toc = (root / "SocialShortcuts.toc").read_text(encoding="utf-8")
    runtime = [line.strip().replace("\\", "/") for line in toc.splitlines()
               if line.strip() and not line.lstrip().startswith("#")]
    paths = ["SocialShortcuts.toc", "Bindings.xml", "LICENSE", "README.md", "CHANGELOG.md"] + runtime
    output = args.output or root / "dist" / f"SocialShortcuts-{args.version}.zip"
    output.parent.mkdir(parents=True, exist_ok=True)
    # A fixed timestamp makes the same source/version rebuild to identical archive bytes.
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name in sorted(set(paths)):
            path = root / name
            if not path.is_file() or not path.resolve().is_relative_to(root):
                raise ValueError(f"Missing or invalid addon file: {name}")
            data = path.read_bytes()
            if name == "SocialShortcuts.toc":
                data = toc.replace("@project-version@", args.version).encode("utf-8")
            entry = zipfile.ZipInfo("SocialShortcuts/" + name, (1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, data)
    print(output)


if __name__ == "__main__":
    main()
