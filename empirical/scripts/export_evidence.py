"""Export numerical evidence from the sealed F study. Requires NumPy."""

import argparse
import csv
import gzip
import hashlib
import io
import json
from itertools import chain
from pathlib import Path

import numpy as np


HELDOUT = "Analysis/Results/heldout"
SUPERVISION = "Finalization/Supervision"
SEALED_MANIFEST_SHA256 = "9640ff3a83b309a86b85171496f9755c243db66decabc0f257410f349f9a1201"
FREEZE_SHA256 = "9c60eaefbe8b57e6d5475edd9601c0a650806bb93acede09a3bcc0d1de859e9c"
ARMS = ("corrected_score_gate", "score_only", "count_rate", "count_rate_gate", "persistence")
DETECTORS = ("state", "quantity")
ROLES = {"172.30.1.2": "affected", "172.30.1.3": "peer"}
NS = 1_000_000_000


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


class Evidence:
    """Read only files bound by the sealed F artifact manifest."""

    def __init__(self, root):
        self.root = root
        source = (root / "ARTIFACT_MANIFEST.json").read_bytes()
        require(sha256(source) == SEALED_MANIFEST_SHA256, "Unexpected F artifact manifest")
        manifest = json.loads(source)
        require(manifest["freeze_verification"]["manifest_sha256"] == FREEZE_SHA256,
                "Unexpected F pretest freeze")
        self.index = {row["path"]: row for row in manifest["files"]}
        self.sources = {}

    def read(self, name, record=True):
        content = (self.root / name).read_bytes()
        digest = sha256(content)
        require(digest == self.index[name]["sha256"], f"Sealed digest mismatch: {name}")
        if record:
            self.sources[name] = digest
        return content

    def json(self, name):
        return json.loads(self.read(name))


def write_csv(path, rows):
    rows = iter(rows)
    first = next(rows)
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=first.keys(), lineterminator="\n")
        writer.writeheader()
        for row in chain((first,), rows):
            writer.writerow({key: int(value) if isinstance(value, (bool, np.bool_)) else value
                             for key, value in row.items()})


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2, allow_nan=False) + "\n", encoding="utf-8")


def flat_fields(data, prefix=""):
    for key, value in data.items():
        name = f"{prefix}{key}"
        if isinstance(value, dict):
            yield from flat_fields(value, name + "_")
        elif isinstance(value, list):
            yield name, "|".join(value)
        else:
            yield name, value


def native_row(case, trial, detector, role, arrays, i):
    def feature(name, j):
        return arrays[name][i, j].item()

    return {
        "case_id": case,
        "trial_id": trial,
        "detector": detector,
        "target_role": role,
        "bin_index": i,
        "x1": feature("x", 0),
        "x2": feature("x", 1),
        "component": arrays["component"][i].item(),
        "K1": feature("K", 0),
        "K2": feature("K", 1),
        "n": arrays["n"][i].item(),
        "O15_1": feature("O15", 0),
        "O15_2": feature("O15", 1),
        "n15": arrays["n15"][i].item(),
        "E1": feature("E", 0),
        "E2": feature("E", 1),
        "valid": arrays["valid"][i].item(),
        "gate1": feature("gate", 0),
        "gate2": feature("gate", 1),
        "rate1": feature("rate", 0),
        "rate2": feature("rate", 1),
        "integer_count_threshold1": feature("integer_count_threshold", 0),
        "integer_count_threshold2": feature("integer_count_threshold", 1),
        **{f"family_{arm}": arrays[f"family_{arm}"][i].item() for arm in ARMS},
    }


def export_native(evidence, output, trials):
    index = evidence.json("NativeHeldout/INPUT_INDEX.json")
    parameters = {}
    for detector in DETECTORS:
        model = evidence.json(f"Models/{detector}_model.json")
        policy = evidence.json(f"Models/{detector}_policy.json")
        del model["service_scope"]
        parameters[detector] = {"model": model, "policy": policy}
    write_json(output / "native_parameters.json", parameters)

    expected = {f"{trial}_{detector}_{source}" for trial in trials
                for detector in DETECTORS for source in ROLES}
    require(len(index["cases"]) == 144 and {row["case_id"] for row in index["cases"]} == expected,
            "Native case grid does not match F")
    case_metadata = []
    series = {}
    for row in index["cases"]:
        original_id = row["case_id"]
        trial, detector, source = original_id.split("_")
        role = ROLES[source]
        case = f"{trial}_{detector}_{role}"
        replay = evidence.read(f"{HELDOUT}/{original_id}.npz", record=False)
        require(sha256(replay) == row["replay_sha256"], f"Replay index mismatch: {case}")
        fixture = evidence.read(f"NativeHeldout/{row['fixture']}", record=False)
        require(sha256(fixture) == row["fixture_sha256"], f"Fixture index mismatch: {case}")
        for suffix in ("model", "policy"):
            require(evidence.sources[f"Models/{detector}_{suffix}.json"] == row[f"{suffix}_sha256"],
                    f"Parameter index mismatch: {case} {suffix}")
        with np.load(io.BytesIO(replay), allow_pickle=False) as archive:
            arrays = dict(archive)
        require(arrays["x"].shape == (300, 2)
                and np.array_equal(arrays["timestamp"] - trials[trial]["capture_start_ns"] // NS,
                                   np.arange(300)),
                f"Unexpected time grid: {case}")
        hashes = {key: sha256(np.asarray(arrays[key], dtype="<f8").tobytes(order="F"))
                  for key in ("K", "n", "O15")}
        hashes["valid"] = sha256(np.asarray(arrays["valid"], dtype="u1").tobytes(order="F"))
        family = np.column_stack([arrays[f"family_{arm}"] for arm in ARMS])
        hashes["family"] = sha256(family.astype("u1").tobytes(order="F"))
        require(hashes == row["expected_hashes"], f"Frozen array hashes differ: {case}")

        series[trial, detector, role] = arrays
        case_metadata.append({
            "case_id": case,
            "fixture": Path(row["fixture"]).name,
            "fixture_sha256": row["fixture_sha256"],
            "replay_sha256": row["replay_sha256"],
            "model_sha256": row["model_sha256"],
            "policy_sha256": row["policy_sha256"],
            "expected_hashes": hashes,
        })
    write_json(output / "native_case_index.json", {
        "score_tolerance": index["score_tolerance"], "cases": case_metadata,
    })
    write_csv(output / "native_cases.csv", (
        native_row(f"{trial}_{detector}_{role}", trial, detector, role, arrays, i)
        for (trial, detector, role), arrays in series.items() for i in range(300)
    ))
    return series


def family_series(series, trial, detector):
    return {
        arm: np.logical_or.reduce([series[trial, detector, role][f"family_{arm}"]
                                   for role in ROLES.values()])
        for arm in ARMS
    }


def export_trials(output, final, trials, series, contract):
    trial_rows, measurement_rows = [], []
    for trial, summary in final["trials"].items():
        report = trials[trial]
        families = {detector: family_series(series, trial, detector) for detector in DETECTORS}
        for detector in DETECTORS:
            counts = {arm: int(flags.sum()) for arm, flags in families[detector].items()}
            require(counts == summary["alarm_seconds"][detector], f"Alarm totals differ: {trial}")
        flags = families["state"]
        count_same = np.array_equal(flags[ARMS[0]], flags[ARMS[3]])
        gate_same = np.array_equal(flags[ARMS[0]], flags[ARMS[4]])
        require(count_same == report["state_count_gate_identical_every_bin"]
                and gate_same == report["state_persistence_identical_every_bin"],
                f"Alarm agreement differs: {trial}")
        trial_rows.append({
            "trial_id": trial,
            "block_id": report["block_id"],
            **dict(flat_fields(summary)),
            "state_count_gate_identical_every_bin": count_same,
            "state_persistence_identical_every_bin": gate_same,
            "detection_pattern_pass": contract["detection_by_trial"][trial],
            "baseline_primary_alarm_seconds": report["models"]["state"]["arms"][ARMS[0]][
                "baseline_alarm_seconds"],
        })
        measurement = final["measurement_by_trial"][trial]
        # Keep measurements and tested outcomes while dropping narrative and nested per-check text.
        selected_measurement = {
            key: value for key, value in measurement.items()
            if key not in ("raw_response_effect", "raw_initiation")
        }
        for key in ("raw_initiation", "raw_response_effect"):
            selected_measurement[key] = {
                field: value for field, value in measurement[key].items()
                if field not in ("scope", "checks")
            }
        measurement_rows.append({"trial_id": trial, **dict(flat_fields(selected_measurement))})
    write_csv(output / "trial_summary.csv", trial_rows)
    # Some checks apply only to raw-load trials. Use blank cells for non-applicable measures.
    keys = dict.fromkeys(key for row in measurement_rows for key in row)
    write_csv(output / "measurement_summary.csv", (
        dict.fromkeys(keys) | row for row in measurement_rows
    ))
    write_csv(output / "arm_summary.csv", (
        {"arm": arm, **dict(flat_fields(summary))} for arm, summary in final["arm_totals"].items()
    ))


def export_cohorts(evidence, output, contract):
    paired = evidence.json(f"{HELDOUT}/PAIRED_APPLICATION_COMPARISONS.json")
    keys = ("kind", "block_id", "role", "channel", "phase")
    contrasts = {tuple(row[k] for k in keys): row for row in paired["comparisons"]
                 if row["arm"] == "conditional_proxy" and row["reference_arm"] == "observe"}
    rows = []
    for kind, groups in contract["primary_paired_groups"].items():
        for group, result in groups.items():
            for item in result["rows"]:
                row = {"kind": kind, "group": group, **item}
                contrast = contrasts[tuple(row[k] for k in keys)]
                if kind == "connection":
                    passed = contrast["complete"] and contrast["no_additional_nonsuccess_pass"]
                else:
                    passed = contrast["joint_engineering_target_pass"]
                require(row["p95_delta_ms"] == contrast["p95_latency_delta_ms"]
                        and row["newly_harmed"] == contrast["treated_failure_reference_success"]
                        and row["failure_difference"] == contrast["intended_nonsuccess_delta"]
                        and row["pass"] == passed,
                        f"Cohort sources disagree: {row}")
                for key in ("matched_ids", "intended_matched_ids", "both_success", "both_nonsuccess",
                            "treated_success_reference_failure", "margin_ms"):
                    row[key] = contrast[key]
                for side in ("treated", "reference"):
                    side_data = contrast[side]
                    latency = side_data["logical_or_message_latency_ms_successes"]
                    row[f"{side}_intended_nonsuccess"] = side_data["intended_nonsuccess"]
                    row[f"{side}_latency_n"] = latency["n"] if kind != "connection" else None
                    row[f"{side}_p95_ms"] = latency["p95"] if kind != "connection" else None
                # Margin is inapplicable for binary connection outcomes.
                if kind == "connection":
                    row["margin_ms"] = None
                rows.append(row)
    require(len(rows) == 199 and sum(row["pass"] for row in rows) == 197,
            "Unexpected primary cohort totals")
    write_csv(output / "primary_cohorts.csv", rows)


def json_lines(content):
    return [json.loads(line) for line in gzip.decompress(content).splitlines()]


def export_f04_timing(evidence, output, trial, series):
    base = trial["capture_start_ns"]
    actual_start = trial["main_window"]["actual_start_ns"]
    arm_metrics = trial["models"]["state"]["arms"]
    action = trial["conditional_actions"][0]
    events = {key: trial["main_window"][key + "_ns"] for key in
              ("actual_start", "actual_end", "scheduled_start", "scheduled_end")}
    events = {key.replace("_", "_load_", 1): value for key, value in events.items()}
    events.update({f"{arm}_first_crossing": arm_metrics[arm]["first_new_crossing_available_ns"]
                   for arm in ARMS})
    events.update(action_attempted=action["attempted_ns"], action_installed=action["installed_ns"],
                  nominal_admission_end=action["installed_ns"] + action["ttl_seconds"] * NS,
                  nominal_ack_end=action["installed_ns"]
                  + (action["ttl_seconds"] + action["completion_grace_seconds"]) * NS)
    for interval in trial["applications"]["action_intervals"]:
        for endpoint in ("start", "end"):
            events[f"{interval['kind']}_{endpoint}"] = interval[f"{endpoint}_ns"]
    write_csv(output / "f04_events.csv", (
        {"event": event, "trial_offset_ns": value - base,
         "since_actual_load_start_ns": value - actual_start}
        for event, value in sorted(events.items(), key=lambda entry: entry[1])
    ))

    decisions = json_lines(evidence.read("Lab/results/f04p/state_decisions.jsonl.gz"))
    require(len(decisions) == 300, "Incomplete F04 decision stream")
    affected = series["f04p", "state", "affected"]
    family = family_series(series, "f04p", "state")
    rows = []
    for i, wrapped in enumerate(decisions):
        decision = wrapped["decision"]
        source = decision["sources"]["172.30.1.2"]
        require(decision["second"] == base // NS + i
                and all(decision["family"][arm] == family[arm][i] for arm in ARMS)
                and source["K"][0] == affected["K"][i, 0]
                and source["O15"][0] == affected["O15"][i, 0]
                and source["E"][0] == affected["E"][i, 0],
                f"F04 live/replay discrepancy at bin {i}")
        rows.append({
            "bin_index": i,
            "bin_start_offset_ns": i * NS,
            "bin_end_offset_ns": (i + 1) * NS,
            "decision_offset_ns": wrapped["wall_ns"] - base,
            "decision_since_actual_load_start_ns": wrapped["wall_ns"] - actual_start,
            "eligible": decision["eligible"],
            "valid": source["valid"],
            "affected_K1": source["K"][0],
            "n": source["n"],
            "affected_O15_1": source["O15"][0],
            "affected_E1": source["E"][0],
            "affected_rate1": affected["rate"][i, 0].item(),
            "affected_integer_count_threshold1": affected["integer_count_threshold"][i, 0].item(),
            "affected_gate1": source["gate"][0],
            **{f"family_{arm}": decision["family"][arm] for arm in ARMS},
        })
    write_csv(output / "f04_timeline.csv", rows)


def logical_rows(trial, role, channel):
    return {row["seq"]: row for row in trial["applications"]["logical_rows"]
            if row["role"] == role and row["channel"] == channel}


def relative(value, origin):
    return value - origin if value is not None else None


def export_matched_requests(output, treated, reference, filename, channel, phase):
    t = logical_rows(treated, "affected", channel)
    r = logical_rows(reference, "affected", channel)
    t_base = treated["capture_start_ns"]
    r_base = reference["capture_start_ns"]
    rows = []
    for seq, item in sorted(t.items()):
        if phase not in item["cohorts"]:
            continue
        match = r[seq]
        offset = item["scheduled_start_ns"] - t_base
        require(offset == match["scheduled_start_ns"] - r_base, f"Schedule mismatch: {seq}")
        rows.append({
            "seq": seq,
            "scheduled_offset_ns": offset,
            "treated_latency_ms": item["latency_ms"],
            "reference_latency_ms": match["latency_ms"],
            "treated_attempt_count": item["attempt_count"],
            "reference_attempt_count": match["attempt_count"],
            "treated_start_offset_ns": relative(item["start_ns"], t_base),
            "reference_start_offset_ns": relative(match["start_ns"], r_base),
            "treated_ack_offset_ns": relative(item["ack_ns"], t_base),
            "reference_ack_offset_ns": relative(match["ack_ns"], r_base),
            "treated_intent_to_complete": item["intent_to_complete"],
            "reference_intent_to_complete": match["intent_to_complete"],
            "treated_success": item["verified_success"],
            "reference_success": match["verified_success"],
            "treated_not_dispatched": item["not_dispatched"],
            "reference_not_dispatched": match["not_dispatched"],
        })
    write_csv(output / filename, rows)
    return rows


def request_p95(rows, side):
    latency = [row[f"{side}_latency_ms"] for row in rows if row[f"{side}_success"]]
    return float(np.quantile(latency, 0.95, method="linear"))


def export_retained_failures(evidence, output, f02p, f02o, f04p, f04o):
    cohort = evidence.json(f"{SUPERVISION}/F04_PRIMARY_LATENCY_COHORT_v1.json")
    rows = export_matched_requests(output, f04p, f04o, "f04_guarded_requests.csv",
                                   "continuity_new_tcp", "guarded_admission")
    require(len(rows) == cohort["matched"] == 58 and all(
        row["treated_success"] and row["reference_success"]
        and row["treated_attempt_count"] == row["reference_attempt_count"] == 1 for row in rows
    ), "F04 request identity or outcome mismatch")
    for side in ("treated", "reference"):
        require(abs(request_p95(rows, side) - cohort[f"{side}_quantiles"]["p95"]) < 1e-10,
                f"F04 {side} p95 differs from frozen cohort")
    rows = export_matched_requests(output, f02p, f02o, "f02_matched_requests.csv", "new_tcp", "full")
    require(len(rows) == 543 and all(row["treated_intent_to_complete"]
                                    and row["reference_intent_to_complete"] for row in rows),
            "Unexpected F02 cohort identities or intent")
    t_fail = sum(not row["treated_success"] for row in rows)
    r_fail = sum(not row["reference_success"] for row in rows)
    require(t_fail - r_fail == -7 and sum(not row["treated_success"] and row["reference_success"]
                                        for row in rows) == 1
            and abs(request_p95(rows, "treated") - request_p95(rows, "reference")
                    - 22.098613549999993) < 1e-10,
            "F02 whole-trial adverse outcome differs")

    findings = evidence.json(f"{SUPERVISION}/F02_RUNTIME_RESOURCE_FORENSICS_v1/DIAGNOSIS_v3.json")
    dispatch = [
        {"trial_id": stream["trial_id"], "role": stream["role"], **job}
        for stream in findings["client_streams"] for job in stream["missed_jobs"]
    ]
    for job in findings["first_call_uncertain_cases"]:
        dispatch.append({
            "trial_id": job["trial_id"], "role": job["role"], "channel": job["channel"],
            "seq": job["seq"], "scheduled_phase_s": job["scheduled_phase_s"],
            "observed_phase_s": None, "actual_connect_calls": int(job["initiation_called"]),
            "timing_status": "deadline_crossing_unverified",
            "pre_due_lag_ns": job["pre_due_lag_ns"], "post_due_lag_ns": job["post_due_lag_ns"],
        })
    require(len(dispatch) == 142, "Unexpected number of F02 initiation anomalies")
    dispatch.sort(key=lambda row: (row["trial_id"], row["role"], row["scheduled_phase_s"]))
    keys = dict.fromkeys(key for row in dispatch for key in row)
    write_csv(output / "f02_dispatch_failures.csv", (dict.fromkeys(keys) | row for row in dispatch))


def export_study(root, output):
    evidence = Evidence(root)
    final = evidence.json("FINAL_RESULT.json")
    frozen = evidence.json("Finalization/DESCRIPTIVE_SUMMARY_v1.json")
    require(all(final[key] == value for key, value in frozen.items() if key != "created_utc"),
            "Final result differs from the frozen descriptive metrics")
    require(final["status"] == "NOT_PASSED" and final["planned_trials"] == 36
            and final["completed_trials"] == 36 and final["freeze_sha256"] == FREEZE_SHA256,
            "Unexpected scientific result")
    trials = evidence.json(f"{HELDOUT}/RESULTS.json")["trials"]
    contract = evidence.json(f"{HELDOUT}/COMBINED_CONTRACT.json")
    original_native = evidence.json("NativeHeldout/VERIFICATION.json")
    reproduction = evidence.json("REPRODUCTION_CHECK.json")
    fit = evidence.json("Models/BENIGN_FIT_REPORT.json")
    series = export_native(evidence, output, trials)
    export_trials(output, final, trials, series, contract)
    export_cohorts(evidence, output, contract)
    export_f04_timing(evidence, output, trials["f04p"], series)
    detailed = {trial: evidence.json(f"{HELDOUT}/{trial}.json")
                for trial in ("f02p", "f02o", "f04p", "f04o")}
    export_retained_failures(evidence, output, **detailed)

    write_json(output / "study_summary.json", {
        **{key: final[key] for key in (
            "status", "study_complete", "planned_trials", "completed_trials", "freeze_sha256",
            "frozen_files", "primary_cohorts_passed", "primary_cohorts_assessed",
            "primary_groups", "failed_primary_cohorts", "absolute_selective_trials_passed",
            "combined_flags",
        )},
        "fit_trials": fit["fit_trials"],
        "calibration_trials": fit["calibration_trials"],
        "original_native_verification": original_native,
        "separate_copy_reproduction": {key: reproduction[key] for key in (
            "status", "normalized_json_files_exact", "replay_npz_cases", "array_comparisons_exact",
        )},
    })
    write_json(output / "provenance.json", {
        "sealed_artifact_manifest_sha256": SEALED_MANIFEST_SHA256,
        "pretest_freeze_manifest_sha256": FREEZE_SHA256,
        "source_sha256": dict(sorted(evidence.sources.items())),
        "export_sha256": {path.name: sha256(path.read_bytes()) for path in sorted(output.iterdir())
                          if path.is_file() and path.name != "provenance.json"},
    })


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sealed_study", type=Path, help="root of the sealed F evidence package")
    parser.add_argument("output", type=Path, help="new output directory")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    export_study(args.sealed_study, args.output)


if __name__ == "__main__":
    main()
