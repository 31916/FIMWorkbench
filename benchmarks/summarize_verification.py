"""Verify the two experiment inventories agree and write one row per model."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "verification"
MODELS = ["AT", "AFC", "NN", "CC", "SC", "PM", "F16", "SB1", "SB2", "SB3", "SB4", "SB5"]


def read_csv(file):
    with file.open(encoding="utf-8", newline="") as stream:
        return list(csv.DictReader(stream))


def main():
    output = []
    editors = {r["model"]: r for r in read_csv(ROOT / "editor.csv")}
    replacements = read_csv(ROOT / "lor.csv")
    for model in MODELS:
        run = ROOT / "arch2026" / model
        coverage = ROOT / "all_sites" / model
        result = json.loads((run / "result.json").read_text())
        catalog = json.loads((run / "sites.json").read_text())
        if isinstance(catalog, dict):
            catalog = [catalog]
        rows = read_csv(coverage / "sites.csv")
        plans = read_csv(coverage / "fault_plan.csv")
        valid = [r for r in rows if r["status"] == "off_verified"]
        excluded = [r for r in rows if r["status"] == "excluded"]
        expected = {r["id"] for r in catalog if r["faults"]}
        assert result["status"] == "PASS"
        assert {r["site"] for r in valid} == expected
        assert len(rows) == len(catalog) == len(valid) + len(excluded)
        assert len(valid) == len(expected) == int(editors[model]["editable_slots"])
        assert {p["site"] for p in plans} == expected
        assert all((coverage / r["model"]).is_file() for r in valid)
        assert len({(r["model"], r["slot"]) for r in valid}) == len(valid)
        assert (run / "traces.mat").is_file()
        assert all(c["samples_compared"] > 0 for c in result["checks"])
        planned_lor = {(p["site"], json.loads(p["value"])) for p in plans if p["type"] == "lor"}
        tested_lor = [r for r in replacements if r["model"] == model]
        assert len(planned_lor) == len(tested_lor)
        assert planned_lor == {(r["site"], r["replacement"]) for r in tested_lor}
        assert all(int(r["local_samples"]) > 0 and int(r["output_samples"]) > 0
                   and float(r["max_error"]) == 0 for r in tested_lor)
        output.append(dict(model=model, horizon_seconds=result["horizon"], candidates=len(rows),
                           installed_off_verified=len(valid), excluded=len(excluded), planned_settings=len(plans),
                           trace_checks=len(result["checks"]), maximum_absolute_error=max(c["max_abs_error"] for c in result["checks"]),
                           lor_settings_verified=len(tested_lor), editor_verified="PASS", active_test="PASS", tested_scope=result["scope"],
                           ready_model=(coverage / valid[0]["model"]).relative_to(ROOT.parent).as_posix()))
    with (ROOT / "results.csv").open("w", newline="", encoding="utf-8") as stream:
        writer=csv.DictWriter(stream, fieldnames=output[0], lineterminator="\n")
        writer.writeheader()
        writer.writerows(output)
    print("Models:", len(output), "verified sites:", sum(r["installed_off_verified"] for r in output),
          "planned settings:", sum(r["planned_settings"] for r in output))


if __name__ == "__main__":
    main()
