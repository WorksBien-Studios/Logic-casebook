#!/usr/bin/env python3
from pathlib import Path
import hashlib, json

ROOT = Path(__file__).resolve().parents[1]
INDEX_PATH = ROOT / "data/cases/index.v1.json"
OUTPUT_PATH = ROOT / "data/cases.v1.json"

def main():
    index = json.loads(INDEX_PATH.read_text(encoding="utf-8"))
    cases = []
    for entry in index["shards"]:
        path = ROOT / entry["path"]
        raw = path.read_bytes()
        digest = hashlib.sha256(raw).hexdigest()
        if digest != entry["sha256"]:
            raise SystemExit(f"checksum mismatch: {entry['path']}")
        shard = json.loads(raw)
        if shard["caseCount"] != entry["caseCount"] or len(shard["cases"]) != entry["caseCount"]:
            raise SystemExit(f"count mismatch: {entry['path']}")
        cases.extend(shard["cases"])
    if len(cases) != index["caseCount"]:
        raise SystemExit(f"bundle count mismatch: {len(cases)}")
    bundle = {
        "bundleSchemaVersion": index["bundleSchemaVersion"],
        "bundleID": index["bundleID"],
        "contentVersion": index["contentVersion"],
        "generatedAt": index["generatedAt"],
        "generatorSeed": index["generatorSeed"],
        "releaseStatus": index["releaseStatus"],
        "caseCount": index["caseCount"],
        "cases": cases,
    }
    raw = (json.dumps(bundle, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    digest = hashlib.sha256(raw).hexdigest()
    if digest != index["assembledBundleSHA256"]:
        raise SystemExit(f"assembled checksum mismatch: {digest}")
    OUTPUT_PATH.write_bytes(raw)
    print(f"assembled {len(cases)} cases: {digest}")

if __name__ == "__main__":
    main()
