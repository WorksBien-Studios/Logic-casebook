#!/usr/bin/env python3
"""Independent exhaustive validator for the Logic Casebook JSON bundle."""

from __future__ import annotations

import hashlib
import itertools
import json
import math
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "cases.v1.json"
MANIFEST = ROOT / "data" / "manifest.v1.json"
REPORTS = ROOT / "reports"


def checksum(case):
    clean = {k:v for k,v in case.items() if k != "checksum"}
    raw = json.dumps(clean, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(raw.encode()).hexdigest()


def numeric_context(case):
    categories = case["categories"]
    cat_index = {c["id"]:i for i,c in enumerate(categories)}
    value_index = {(c["id"],v["id"]):j for i,c in enumerate(categories) for j,v in enumerate(c["values"])}
    n, k = len(categories[0]["values"]), len(categories)
    perms = list(itertools.permutations(range(n)))
    assignments = list(itertools.product(perms, repeat=k-1))
    def ref(value):
        return cat_index[value[0]], value_index[(value[0], value[1])]
    return categories, cat_index, value_index, n, k, assignments, ref


def owner(assignment, category, value):
    return value if category == 0 else assignment[category-1].index(value)


def ordered_value(assignment, entity, ordered_category):
    return assignment[ordered_category-1][owner(assignment, *entity)]


def compile_clue(clue, cat_index, ref):
    t, args = clue["type"], clue["args"]
    out = {}
    for key, value in args.items():
        if key == "orderedCategory":
            out[key] = cat_index[value]
        elif key == "offset":
            out[key] = value
        elif key in {"left", "right"} and value and isinstance(value[0], list):
            out[key] = [ref(x) for x in value]
        else:
            out[key] = ref(value)
    return {"id":clue["id"], "type":t, "args":out, "textJA":clue["textJA"]}


def evaluate(clue, assignment):
    t, a = clue["type"], clue["args"]
    if t == "same":
        return owner(assignment,*a["left"]) == owner(assignment,*a["right"])
    if t == "different":
        return owner(assignment,*a["left"]) != owner(assignment,*a["right"])
    if t == "either":
        p = owner(assignment,*a["subject"])
        return p in {owner(assignment,*a["optionA"]), owner(assignment,*a["optionB"])}
    if t == "pairSet":
        return {owner(assignment,*x) for x in a["left"]} == {owner(assignment,*x) for x in a["right"]}
    lv = ordered_value(assignment,a["left"],a["orderedCategory"])
    rv = ordered_value(assignment,a["right"],a["orderedCategory"])
    if t == "before":
        return lv < rv
    if t == "immediatelyBefore":
        return rv-lv == 1
    if t == "offsetBefore":
        return rv-lv == a["offset"]
    raise ValueError(t)


def expected_assignment(case, cat_index, value_index, n, k):
    rows = case["solution"]["rows"]
    primary_id = case["categories"][0]["id"]
    by_primary = {value_index[(primary_id,row[primary_id])]:row for row in rows}
    result = []
    for cat in range(1,k):
        cid = case["categories"][cat]["id"]
        result.append(tuple(value_index[(cid,by_primary[p][cid])] for p in range(n)))
    return tuple(result)


def validate_case(case):
    errors = []
    categories, cat_index, value_index, n, k, assignments, ref = numeric_context(case)
    if len({c["id"] for c in categories}) != k:
        errors.append("duplicate category id")
    if any(len(c["values"]) != n for c in categories):
        errors.append("category sizes differ")
    if sum(bool(c["ordered"]) for c in categories) != 1 or not categories[-1]["ordered"]:
        errors.append("last category must be the sole ordered category")
    for c in categories:
        if len({v["id"] for v in c["values"]}) != n:
            errors.append(f"duplicate value id in {c['id']}")

    clue_ids = [c["id"] for c in case["clues"]]
    if len(clue_ids) != len(set(clue_ids)):
        errors.append("duplicate clue id")
    compiled = [compile_clue(c,cat_index,ref) for c in case["clues"]]
    survivors = assignments
    for clue in compiled:
        survivors = [a for a in survivors if evaluate(clue,a)]
    expected = expected_assignment(case,cat_index,value_index,n,k)
    if len(survivors) != 1:
        errors.append(f"solution count {len(survivors)}")
    elif survivors[0] != expected:
        errors.append("stored solution differs from recomputed solution")

    current = assignments
    applied = set()
    clue_map = {c["id"]:c for c in compiled}
    for number, step in enumerate(case["deductionSteps"],1):
        if step["step"] != number:
            errors.append(f"deduction step number mismatch at {number}")
        if step["candidateCountBefore"] != len(current):
            errors.append(f"deduction before-count mismatch at {number}")
        for cid in step["clueIDs"]:
            if cid not in clue_map:
                errors.append(f"unknown clue {cid} in deduction {number}")
                continue
            if cid in applied:
                errors.append(f"reused clue {cid} in deduction path")
            applied.add(cid)
            current = [a for a in current if evaluate(clue_map[cid],a)]
        if step["candidateCountAfter"] != len(current):
            errors.append(f"deduction after-count mismatch at {number}")
        for fact in step["deducedFacts"]:
            left, right = ref(fact["left"]), ref(fact["right"])
            if not current or any(owner(a,*left) != owner(a,*right) for a in current):
                errors.append(f"invalid deduced fact at step {number}")
    if len(current) != 1:
        errors.append("deduction path does not reach one solution")
    if applied != set(clue_ids):
        errors.append("deduction path does not account for every clue")

    metrics = case["proofMetrics"]
    if metrics["searchSpace"] != math.factorial(n) ** (k-1):
        errors.append("search-space metric mismatch")
    if metrics["solutionCount"] != len(survivors):
        errors.append("solution-count metric mismatch")
    if metrics["clueCount"] != len(compiled):
        errors.append("clue-count metric mismatch")
    if metrics["deductionStepCount"] != len(case["deductionSteps"]):
        errors.append("deduction-step metric mismatch")
    if metrics["requiresGuess"] is not False:
        errors.append("requiresGuess must be false")
    if checksum(case) != case["checksum"]:
        errors.append("checksum mismatch")
    return errors


def main():
    raw = DATA.read_bytes()
    bundle = json.loads(raw)
    manifest = json.loads(MANIFEST.read_text())
    cases = bundle["cases"]
    errors = []
    if bundle["caseCount"] != 1000 or len(cases) != 1000:
        errors.append("bundle must contain 1000 cases")
    ids = [c["caseID"] for c in cases]
    signatures = [c["structuralSignature"] for c in cases]
    checksums = [c["checksum"] for c in cases]
    if len(set(ids)) != 1000: errors.append("case IDs are not unique")
    if len(set(signatures)) != 1000: errors.append("structural signatures are not unique")
    if len(set(checksums)) != 1000: errors.append("case checksums are not unique")

    expected_difficulty = {"beginner":120,"standard":260,"advanced":360,"expert":260}
    expected_free = {"beginner":10,"standard":8,"advanced":8,"expert":4}
    actual_difficulty = Counter(c["difficulty"] for c in cases)
    actual_free = Counter(c["difficulty"] for c in cases if c["isFree"])
    if dict(actual_difficulty) != expected_difficulty: errors.append(f"difficulty allocation {dict(actual_difficulty)}")
    if dict(actual_free) != expected_free: errors.append(f"free allocation {dict(actual_free)}")

    case_failures = {}
    for index, case in enumerate(cases,1):
        case_errors = validate_case(case)
        if case_errors:
            case_failures[case["caseID"]] = case_errors

    bundle_sha = hashlib.sha256(raw).hexdigest()
    if bundle_sha != manifest["sha256"]: errors.append("bundle SHA-256 differs from manifest")
    if manifest["caseCount"] != 1000 or manifest["freeCaseCount"] != 30: errors.append("manifest allocation mismatch")
    editorial = Counter(c["editorialStatus"] for c in cases)
    release_ready = not errors and not case_failures and editorial.get("approved",0) == 1000
    if manifest["releaseReady"] != release_ready: errors.append("manifest releaseReady value is inconsistent")

    result = {
        "mechanicalValidation":"PASS" if not errors and not case_failures else "FAIL",
        "releaseReadiness":"PASS" if release_ready else "HOLD",
        "bundleSHA256":bundle_sha,
        "casesChecked":len(cases),
        "caseFailures":case_failures,
        "bundleErrors":errors,
        "difficultyCounts":dict(actual_difficulty),
        "freeDifficultyCounts":dict(actual_free),
        "editorialStatusCounts":dict(editorial),
        "uniqueStructuralSignatures":len(set(signatures)),
        "clueTypeCounts":dict(Counter(clue["type"] for c in cases for clue in c["clues"])),
    }
    REPORTS.mkdir(parents=True,exist_ok=True)
    (REPORTS/"validation-result.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    pending_review = editorial.get("pending_native_review", 0)
    if release_ready:
        gate_note = "All mandatory validation gates pass. The bundle is release ready."
    elif pending_review:
        gate_note = (
            f"Release remains on **HOLD** because {pending_review} case(s) have "
            "`pending_native_review` editorial status. Mechanical correctness does not "
            "substitute for native Japanese naturalness and ambiguity review."
        )
    else:
        gate_note = "Release remains on **HOLD** because of the bundle or case errors listed below."

    report = f"""# Logic Casebook Content Validation\n\n**Mechanical validation:** {result['mechanicalValidation']}  \n**Release readiness:** {result['releaseReadiness']}  \n**Cases checked:** {len(cases)}  \n**Unique structural signatures:** {result['uniqueStructuralSignatures']}  \n**Bundle SHA-256:** `{bundle_sha}`\n\n## Allocation\n\n| Difficulty | Total | Free |\n|---|---:|---:|\n| Beginner | {actual_difficulty['beginner']} | {actual_free['beginner']} |\n| Standard | {actual_difficulty['standard']} | {actual_free['standard']} |\n| Advanced | {actual_difficulty['advanced']} | {actual_free['advanced']} |\n| Expert | {actual_difficulty['expert']} | {actual_free['expert']} |\n| **Total** | **{len(cases)}** | **{sum(actual_free.values())}** |\n\n## Gate interpretation\n\nThe mechanical gate exhaustively recomputed every solution, replayed every deduction path, checked every deduced fact, verified content checksums and confirmed 1,000 distinct structural signatures.\n\n{gate_note}\n\n## Errors\n\n- Bundle errors: {len(errors)}\n- Cases with errors: {len(case_failures)}\n"""
    (REPORTS/"validation-report.md").write_text(report,encoding="utf-8")
    print(json.dumps(result,ensure_ascii=False))
    raise SystemExit(0 if result["mechanicalValidation"] == "PASS" else 1)


if __name__ == "__main__":
    main()
