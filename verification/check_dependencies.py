"""Compare compiled dependencies of the source build and the independent challenge."""

import argparse
import hashlib
import json
import subprocess
from collections import Counter
from pathlib import Path


IMPORT_SUFFIXES = (".olean", ".olean.private", ".olean.server", ".ir", ".ir.sig")


def compiled_modules(package, include_companions=False):
    directory = package / ".lake/build/lib/lean"
    paths = directory.rglob("*") if include_companions else directory.rglob("*.olean")
    return {path.relative_to(directory): path for path in paths if path.name.endswith(IMPORT_SUFFIXES)}


def compare(work, include_companions=False):
    reference = work / "reference"
    source = work / "lean"
    manifest = (reference / "lake-manifest.json").read_bytes()
    if (source / "lake-manifest.json").read_bytes() != manifest:
        raise SystemExit("The source and challenge dependency manifests differ")
    entries = json.loads(manifest)["packages"]
    total = 0
    counts = Counter()
    unit = "import files" if include_companions else "modules"
    for entry in entries:
        name, revision = entry["name"], entry["rev"]
        packages = [root / ".lake/packages" / name for root in (reference, source)]
        for package in packages:
            head = subprocess.check_output(["git", "-C", package, "rev-parse", "HEAD"], text=True)
            if head.strip() != revision:
                raise SystemExit(f"{package} has revision {head.strip()}, expected {revision}")

        expected, actual = (compiled_modules(package, include_companions) for package in packages)
        if expected.keys() != actual.keys():
            raise SystemExit(f"{name} has a different module set: {sorted(expected.keys() ^ actual.keys())}")
        manifest_hash = hashlib.sha256()
        for module in sorted(expected):
            with expected[module].open("rb") as left, actual[module].open("rb") as right:
                digest = hashlib.file_digest(left, "sha256").hexdigest()
                if digest != hashlib.file_digest(right, "sha256").hexdigest():
                    raise SystemExit(f"Compiled module differs: {name}/{module}")
            manifest_hash.update(f"{digest}  {module.as_posix()}\n".encode())
            if include_companions:
                counts[next(suffix for suffix in IMPORT_SUFFIXES if module.name.endswith(suffix))] += 1
        print(f"{name} {revision} {len(expected)} {unit}, manifest SHA-256 {manifest_hash.hexdigest()}", flush=True)
        total += len(expected)
    if not total:
        raise SystemExit("Neither dependency tree contains compiled modules")
    if include_companions:
        print("Matched file counts by suffix:", dict(sorted(counts.items())))
    print(f"Matched {total} compiled dependency {unit} across {len(entries)} pinned checkouts.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("work", type=Path)
    parser.add_argument("--include-companions", action="store_true",
                        help="also compare private and server olean data, IR and IR signatures")
    args = parser.parse_args()
    compare(args.work, args.include_companions)
