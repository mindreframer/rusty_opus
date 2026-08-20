#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
manifest="$root/test/fixtures/manifest.json"
python3 - "$root" "$manifest" <<'PY'
import hashlib, json, pathlib, re, sys
root = pathlib.Path(sys.argv[1])
fixture_dir = root / "test/fixtures"
manifest = json.loads(pathlib.Path(sys.argv[2]).read_text())
items = manifest.get("fixtures")
if not isinstance(items, list) or not items:
    raise SystemExit("fixture manifest must contain a non-empty fixtures list")

ids, paths = set(), set()
required = {"id", "path", "format", "sha256", "feature", "provenance"}
for item in items:
    missing = required - item.keys()
    if missing:
        raise SystemExit(f"fixture entry is missing {sorted(missing)}: {item.get('id')}")
    if item["id"] in ids or item["path"] in paths:
        raise SystemExit(f"duplicate fixture id or path: {item['id']}")
    ids.add(item["id"])
    paths.add(item["path"])
    relative = pathlib.PurePosixPath(item["path"])
    if relative.is_absolute() or ".." in relative.parts or len(relative.parts) != 1:
        raise SystemExit(f"fixture path must be one relative filename: {item['path']}")
    if not re.fullmatch(r"[0-9a-f]{64}", item["sha256"]):
        raise SystemExit(f"invalid fixture SHA-256: {item['id']}")
    if not item["format"].startswith(("corrupt_", "unsupported_")):
        for key in ("sample_rate", "channels", "duration_seconds"):
            if key not in item:
                raise SystemExit(f"audio fixture is missing {key}: {item['id']}")
        if item["channels"] not in (1, 2) or item["sample_rate"] <= 0 or item["duration_seconds"] <= 0:
            raise SystemExit(f"invalid audio metadata: {item['id']}")
    path = fixture_dir / item["path"]
    if not path.is_file():
        raise SystemExit(f"fixture missing: {path}")
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != item["sha256"]:
        raise SystemExit(f"fixture hash mismatch: {path}")

actual = {path.name for path in fixture_dir.iterdir() if path.is_file() and path.name != "manifest.json"}
if actual != paths:
    raise SystemExit(f"manifest/file mismatch: unlisted={sorted(actual - paths)}, missing={sorted(paths - actual)}")
print(f"fixture audit passed ({len(items)} fixtures)")
PY
