#!/usr/bin/env python3
"""Bound the axioms of named declarations in a kernel-accepted lean4export stream.

The lower bound follows explicit expression references through definitions,
theorems and opaque constants already seen. It omits forward references and
inductive blocks. All axiom declarations in the file provide an independent
upper bound. Equal bounds certify the exact set. This is a dependency audit
for the release's NDJSON format, not a type checker.
"""

import argparse
import hashlib
import json
import time
from pathlib import Path

try:
    from orjson import loads
except ImportError:
    from json import loads


def audit(path, targets):
    digest = hashlib.sha256()
    started = time.monotonic()
    common = {"propext", "Quot.sound", "Classical.choice", "sorryAx"}
    prefixes = set()
    for name in common | set(targets):
        parts = name.split(".")
        prefixes.update(".".join(parts[:i]) for i in range(1, len(parts) + 1))

    name_paths = {0: ""}
    name_masks = bytearray([0])
    expr_masks = bytearray()
    axiom_names = []
    results = {}
    next_report = 50_000_000

    def mask_at(table, index):
        if index < 0:
            raise ValueError(f"negative index {index}")
        return table[index]

    with path.open("rb", buffering=1024 * 1024) as stream:
        header_line = next(stream)
        digest.update(header_line)
        header = loads(header_line)
        if header["meta"]["format"]["version"] != "3.1.0":
            raise ValueError(f"unexpected export format: {header}")
        for raw in stream:
            digest.update(raw)
            rec = loads(raw)
            if "ie" in rec:
                index = rec["ie"]
                if index != len(expr_masks):
                    raise ValueError(f"nonsequential expression index {index}")
                mask = 0
                if "app" in rec:
                    node = rec["app"]
                    mask = mask_at(expr_masks, node["fn"]) | mask_at(expr_masks, node["arg"])
                elif "const" in rec:
                    mask = mask_at(name_masks, rec["const"]["name"])
                elif "lam" in rec or "forallE" in rec:
                    node = rec["lam"] if "lam" in rec else rec["forallE"]
                    mask = mask_at(expr_masks, node["type"]) | mask_at(expr_masks, node["body"])
                elif "letE" in rec:
                    node = rec["letE"]
                    mask = (mask_at(expr_masks, node["type"]) | mask_at(expr_masks, node["value"])
                            | mask_at(expr_masks, node["body"]))
                elif "proj" in rec:
                    mask = mask_at(expr_masks, rec["proj"]["struct"])
                elif "mdata" in rec:
                    mask = mask_at(expr_masks, rec["mdata"]["expr"])
                elif not any(k in rec for k in ("bvar", "sort", "natVal", "strVal")):
                    raise ValueError(f"unexpected expression at {index}")
                expr_masks.append(mask)
                if len(expr_masks) == next_report:
                    print(f"Processed {next_report:,} expressions in {time.monotonic()-started:.0f}s", flush=True)
                    next_report += 50_000_000
                continue

            if "in" in rec:
                index = rec["in"]
                if index != len(name_masks):
                    raise ValueError(f"nonsequential name index {index}")
                name_masks.append(0)
                if "str" in rec:
                    node = rec["str"]
                    parent = name_paths.get(node["pre"])
                    if parent is not None:
                        name = f"{parent}.{node['str']}" if parent else node["str"]
                        # Only match real string components, including the exact boundaries.
                        if "." not in node["str"] and name in prefixes:
                            name_paths[index] = name
                continue

            kind = next(iter(rec))
            if kind not in {"axiom", "def", "thm", "opaque"}:
                continue
            decl = rec[kind]
            index = decl["name"]
            if not 0 < index < len(name_masks):
                raise ValueError(f"unknown declaration name index {index}")
            name = name_paths.get(index, f"name index {index}")
            if kind == "axiom":
                if len(axiom_names) == 8:
                    raise ValueError("this release audit supports up to eight axiom declarations")
                mask = 1 << len(axiom_names)
                axiom_names.append(name)
            else:
                mask = mask_at(expr_masks, decl["type"]) | mask_at(expr_masks, decl["value"])
            name_masks[index] = mask
            if name in targets:
                if name in results:
                    raise ValueError(f"duplicate declaration of {name}")
                results[name] = mask

    if set(results) != set(targets):
        raise ValueError(f"missing targets: {sorted(set(targets) - results.keys())}")
    print(f"Read {len(expr_masks):,} expressions and {len(name_masks)-1:,} names from {path}")
    print("Input SHA-256:", digest.hexdigest())
    print("All axiom declarations:", json.dumps(axiom_names))
    for target in targets:
        lower = [name for i, name in enumerate(axiom_names) if results[target] & (1 << i)]
        verdict = "exact" if len(lower) == len(axiom_names) else "lower bound"
        print(f"{target}: {verdict} {json.dumps(lower)}")
    return results, axiom_names


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("export", type=Path)
    parser.add_argument("target", nargs="+")
    args = parser.parse_args()
    audit(args.export, args.target)
