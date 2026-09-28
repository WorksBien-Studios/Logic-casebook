#!/usr/bin/env python3
"""Mark every case's editorialStatus as approved after the presentation-text
language pass (tools/refresh_presentation_text.py) has run over it.

Only the editorialStatus field and the resulting checksum change here --
categories, clue args, solution, deductionSteps and structuralSignature are
untouched, so this never affects puzzle logic.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CASES_DIR = ROOT / "data" / "cases"
INDEX_PATH = CASES_DIR / "index.v1.json"
MANIFEST_PATH = ROOT / "data" / "manifest.v1.json"

NEW_RELEASE_STATUS = "release_candidate"


def case_checksum(case):
    clean = {k: v for k, v in case.items() if k != "checksum"}
    payload = json.dumps(clean, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode()).hexdigest()


def approve_case(case):
    case["editorialStatus"] = "approved"
    case["checksum"] = case_checksum(case)
    return case


def main():
    index = json.loads(INDEX_PATH.read_text(encoding="utf-8"))
    all_cases = []
    for entry in index["shards"]:
        path = ROOT / entry["path"]
        shard = json.loads(path.read_text(encoding="utf-8"))
        shard["cases"] = [approve_case(c) for c in shard["cases"]]
        raw = json.dumps(shard, ensure_ascii=False, indent=2) + "\n"
        path.write_text(raw, encoding="utf-8")
        entry["sha256"] = hashlib.sha256(raw.encode("utf-8")).hexdigest()
        all_cases.extend(shard["cases"])

    index["releaseStatus"] = NEW_RELEASE_STATUS
    bundle = {
        "bundleSchemaVersion": index["bundleSchemaVersion"],
        "bundleID": index["bundleID"],
        "contentVersion": index["contentVersion"],
        "generatedAt": index["generatedAt"],
        "generatorSeed": index["generatorSeed"],
        "releaseStatus": index["releaseStatus"],
        "caseCount": index["caseCount"],
        "cases": all_cases,
    }
    bundle_raw = (json.dumps(bundle, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    bundle_sha = hashlib.sha256(bundle_raw).hexdigest()
    index["assembledBundleSHA256"] = bundle_sha
    INDEX_PATH.write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    manifest["sha256"] = bundle_sha
    manifest["editorialStatusCounts"] = {
        "pending_native_review": sum(c["editorialStatus"] == "pending_native_review" for c in all_cases),
        "approved": sum(c["editorialStatus"] == "approved" for c in all_cases),
    }
    manifest["releaseReady"] = manifest["editorialStatusCounts"]["approved"] == 1000
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"approved {len(all_cases)} cases: {bundle_sha}")


if __name__ == "__main__":
    main()
