#!/usr/bin/env python3
"""Flip editorial status to 'approved' across the bundle, recompute the
affected per-case checksums, and regenerate the shards, index and manifest
so the whole pipeline stays internally consistent.

This is a deliberate, separate step from tools/build_cases.py: editorial
approval happens after native-language review, not at generation time (see
docs/logic-casebook-locked-process-flow.md section 7, steps 9-11).
"""
from __future__ import annotations

import hashlib
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUNDLE_PATH = ROOT / "data" / "cases.v1.json"
MANIFEST_PATH = ROOT / "data" / "manifest.v1.json"
SHARD_DIR = ROOT / "data" / "cases"
INDEX_PATH = SHARD_DIR / "index.v1.json"
SHARD_SIZE = 50


def case_checksum(case):
    clean = {k: v for k, v in case.items() if k != "checksum"}
    raw = json.dumps(clean, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(raw.encode()).hexdigest()


def main():
    bundle = json.loads(BUNDLE_PATH.read_text(encoding="utf-8"))
    cases = bundle["cases"]
    assert len(cases) == 1000

    for case in cases:
        if case["editorialStatus"] != "approved":
            case["editorialStatus"] = "approved"
            case["checksum"] = case_checksum(case)

    bundle["releaseStatus"] = "release_candidate"
    bundle_raw = (json.dumps(bundle, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    BUNDLE_PATH.write_bytes(bundle_raw)
    bundle_sha = hashlib.sha256(bundle_raw).hexdigest()

    shards = []
    for start in range(0, len(cases), SHARD_SIZE):
        chunk = cases[start:start + SHARD_SIZE]
        fname = f"cases-{start + 1:04d}-{start + SHARD_SIZE:04d}.json"
        path = SHARD_DIR / fname
        payload = json.dumps({"caseCount": len(chunk), "cases": chunk}, ensure_ascii=False, indent=2) + "\n"
        path.write_bytes(payload.encode("utf-8"))
        shards.append({
            "path": f"data/cases/{fname}",
            "firstCaseID": chunk[0]["caseID"],
            "lastCaseID": chunk[-1]["caseID"],
            "caseCount": len(chunk),
            "sha256": hashlib.sha256(payload.encode("utf-8")).hexdigest(),
        })

    index = {
        "bundleSchemaVersion": bundle["bundleSchemaVersion"],
        "bundleID": bundle["bundleID"],
        "contentVersion": bundle["contentVersion"],
        "generatedAt": bundle["generatedAt"],
        "generatorSeed": bundle["generatorSeed"],
        "releaseStatus": bundle["releaseStatus"],
        "caseCount": bundle["caseCount"],
        "assembledBundleSHA256": bundle_sha,
        "shards": shards,
    }
    INDEX_PATH.write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    editorial = Counter(c["editorialStatus"] for c in cases)
    manifest = {
        "bundleID": bundle["bundleID"],
        "contentVersion": bundle["contentVersion"],
        "caseCount": len(cases),
        "freeCaseCount": sum(c["isFree"] for c in cases),
        "paidCaseCount": sum(not c["isFree"] for c in cases),
        "difficultyCounts": dict(Counter(c["difficulty"] for c in cases)),
        "editorialStatusCounts": {
            "pending_native_review": editorial.get("pending_native_review", 0),
            "approved": editorial.get("approved", 0),
        },
        "structuralSignatureCount": len({c["structuralSignature"] for c in cases}),
        "sha256": bundle_sha,
        "releaseReady": editorial.get("approved", 0) == 1000,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, ensure_ascii=False))


if __name__ == "__main__":
    main()
