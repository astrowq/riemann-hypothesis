"""Compare Alpöge's joined release with the published archive and original Git tree."""

import argparse
import hashlib
import stat
import tarfile
from pathlib import Path, PurePosixPath


ARCHIVE_SHA256 = "9631b4f020199e580ba86178cb56c6e9b09f690c2369a80dc4334aa93f49c7fc"
MIRROR_TREE = "e517b335d21898fd2506ad538a1e1775c0aaa4e4"


def git_hash(kind, data):
    header = kind + b" " + str(len(data)).encode("ascii") + b"\0"
    return hashlib.sha1(header + data).digest()


def tree_hash(directory):
    entries = []
    for name, value in directory.items():
        filename = name.encode("utf-8")
        if isinstance(value, dict):
            mode, digest = b"40000", tree_hash(value)
            sort_key = filename + b"/"
        else:
            mode, digest = value
            sort_key = filename
        entries.append((sort_key, mode + b" " + filename + b"\0" + digest))
    return git_hash(b"tree", b"".join(record for _, record in sorted(entries)))


def compare_checkout(directory, expected, *, root=False):
    entries = {entry.name: entry for entry in directory.iterdir()}
    if root:
        # Lake writes outside src. The audit also creates this top-level Lean input after Main builds.
        entries.pop(".lake", None)
        entries.pop("AuditRH.lean", None)
    if entries.keys() != expected.keys():
        difference = sorted(entries.keys() ^ expected.keys())
        raise SystemExit(f"Path set differs in {directory}: {difference}")
    for name, value in expected.items():
        path = entries[name]
        mode = path.lstat().st_mode
        if isinstance(value, dict):
            if not stat.S_ISDIR(mode):
                raise SystemExit(f"Expected a source directory: {path}")
            compare_checkout(path, value)
        else:
            if not stat.S_ISREG(mode):
                raise SystemExit(f"Expected a regular source file: {path}")
            git_mode = b"100755" if mode & 0o111 else b"100644"
            if (git_mode, git_hash(b"blob", path.read_bytes())) != value:
                raise SystemExit(f"Source content or executable bit differs: {path}")


def main(archive, checkout=None):
    with archive.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    print(f"Joined archive: {archive.stat().st_size:,} bytes, SHA-256 {digest}", flush=True)
    if digest != ARCHIVE_SHA256:
        raise SystemExit("Joined archive differs from the published SHA-256")

    root = {}
    files = lean_files = 0
    with tarfile.open(archive, "r|gz") as release:
        for member in release:
            if member.isdir():
                continue
            path = PurePosixPath(member.name).relative_to("lean")
            if not member.isfile() or ".." in path.parts:
                raise ValueError(f"Unexpected archive entry: {member.name}")
            directory = root
            for component in path.parts[:-1]:
                directory = directory.setdefault(component, {})
            if path.name in directory:
                raise ValueError(f"Duplicate archive entry: {member.name}")
            mode = b"100755" if member.mode & 0o111 else b"100644"
            with release.extractfile(member) as source:
                directory[path.name] = (mode, git_hash(b"blob", source.read()))
            files += 1
            lean_files += path.suffix == ".lean"

    actual_tree = tree_hash(root).hex()
    print(f"Git tree: {actual_tree} ({files:,} files, {lean_files:,} Lean files)")
    if actual_tree != MIRROR_TREE:
        raise SystemExit("Archive contents differ from the original mirror tree")
    if checkout is not None:
        compare_checkout(checkout, root, root=True)
        print(f"Build checkout {checkout}: all {files:,} released paths, Git blob hashes and modes matched.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--checkout", type=Path, help="also compare the Linux build directory with the release")
    args = parser.parse_args()
    main(args.archive, args.checkout)
