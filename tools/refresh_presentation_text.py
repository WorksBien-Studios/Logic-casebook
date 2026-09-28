#!/usr/bin/env python3
"""Re-render the Japanese presentation strings (titles, questions, clue text,
deduction explanations) with more natural phrasing.

This tool changes ONLY presentation text (titleJA / questionJA / clue.textJA /
deductionStep.explanationJA). It never touches categories, clue args, the
solution, deductionStep candidate counts, deducedFacts relations, proofMetrics
or structuralSignature -- so puzzle logic is provably unchanged and
tools/validate_cases.py keeps validating the same solve path. Each case's
checksum and contentVersion are updated to reflect the text revision.
"""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CASES_DIR = ROOT / "data" / "cases"
INDEX_PATH = CASES_DIR / "index.v1.json"
MANIFEST_PATH = ROOT / "data" / "manifest.v1.json"

TITLE_RE = re.compile(r"^(.*\S) (\d+)$")
NEW_CONTENT_VERSION = 2


def value_name(categories, ref):
    cat_id, val_id = ref
    for cat in categories:
        if cat["id"] == cat_id:
            for val in cat["values"]:
                if val["id"] == val_id:
                    return val["nameJA"]
    raise KeyError(ref)


def category_label(categories, cat_id):
    for cat in categories:
        if cat["id"] == cat_id:
            return cat["nameJA"]
    raise KeyError(cat_id)


def render_clue_text(clue, categories):
    t, a = clue["type"], clue["args"]
    q = lambda ref: f"「{value_name(categories, ref)}」"
    if t == "same":
        return f"{q(a['left'])}と{q(a['right'])}は同じ組です。"
    if t == "different":
        return f"{q(a['left'])}と{q(a['right'])}は同じ組ではありません。"
    if t == "either":
        return f"{q(a['subject'])}と同じ組なのは、{q(a['optionA'])}または{q(a['optionB'])}のどちらかです。"
    if t == "pairSet":
        left0, left1 = q(a["left"][0]), q(a["left"][1])
        right0, right1 = q(a["right"][0]), q(a["right"][1])
        return f"{left0}と{left1}の相手は{right0}と{right1}です（どちらがどちらかは未確定です）。"
    label = category_label(categories, a["orderedCategory"])
    if t == "before":
        return f"{q(a['left'])}の{label}は、{q(a['right'])}の{label}より前です。"
    if t == "immediatelyBefore":
        return f"{q(a['left'])}の{label}は、{q(a['right'])}の{label}の直前です。"
    if t == "offsetBefore":
        return f"{q(a['left'])}の{label}は、{q(a['right'])}の{label}より{a['offset']}つ前です。"
    raise ValueError(t)


def render_title(title_ja):
    m = TITLE_RE.match(title_ja)
    if not m:
        return title_ja
    base, cycle = m.group(1), int(m.group(2))
    return f"{base}（その{cycle}）"


def render_question(categories):
    names = "、".join(c["nameJA"] for c in categories[1:])
    return f"各人物の{names}を特定してください。"


def render_explanation(step, prior_text):
    ids_sorted = sorted(int(cid.replace("clue-", "")) for cid in step["clueIDs"])
    if len(ids_sorted) == 1:
        cited = f"手がかり{ids_sorted[0]}"
    else:
        cited = "手がかり" + "、".join(str(i) for i in ids_sorted)
    reason = f"{cited}を使うと、候補は{step['candidateCountBefore']}通りから{step['candidateCountAfter']}通りに絞れます。"
    if step["deducedFacts"]:
        reason += step["deducedFacts"][0]["textJA"]
    return reason


def case_checksum(case):
    clean = {k: v for k, v in case.items() if k != "checksum"}
    payload = json.dumps(clean, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode()).hexdigest()


def refresh_case(case):
    categories = case["categories"]
    case["titleJA"] = render_title(case["titleJA"])
    case["questionJA"] = render_question(categories)
    for clue in case["clues"]:
        clue["textJA"] = render_clue_text(clue, categories)
    for step in case["deductionSteps"]:
        step["explanationJA"] = render_explanation(step, step["explanationJA"])
    case["contentVersion"] = NEW_CONTENT_VERSION
    case["checksum"] = case_checksum(case)
    return case


def main():
    index = json.loads(INDEX_PATH.read_text(encoding="utf-8"))
    all_cases = []
    for entry in index["shards"]:
        path = ROOT / entry["path"]
        shard = json.loads(path.read_text(encoding="utf-8"))
        shard["cases"] = [refresh_case(c) for c in shard["cases"]]
        raw = json.dumps(shard, ensure_ascii=False, indent=2) + "\n"
        path.write_text(raw, encoding="utf-8")
        entry["sha256"] = hashlib.sha256(raw.encode("utf-8")).hexdigest()
        all_cases.extend(shard["cases"])

    index["contentVersion"] = NEW_CONTENT_VERSION
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
    manifest["contentVersion"] = NEW_CONTENT_VERSION
    manifest["sha256"] = bundle_sha
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"refreshed {len(all_cases)} cases: {bundle_sha}")


if __name__ == "__main__":
    main()
