"""Package producer-reported physical evidence; never infer signoff from files alone."""

import hashlib
import json
import math
from pathlib import Path
import shutil
import xml.etree.ElementTree as ET


def sha256(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def finite_number(value):
    return type(value) in (int, float) and math.isfinite(value)


def collect_physical(manifest: Path, output: Path):
    data = json.loads(manifest.read_text(encoding="utf-8-sig"))
    if data.get("schema_version") != 1:
        raise ValueError("Unsupported physical manifest schema")
    output.mkdir(parents=True, exist_ok=False)
    artifacts, issues = [], []

    def capture(label, relative):
        if not relative:
            issues.append(f"Missing {label}")
            return None
        source = (manifest.parent / relative).resolve()
        if not source.is_file() or source.stat().st_size == 0:
            issues.append(f"Missing/empty {label}: {relative}")
            return None
        target = output / f"{label}{source.suffix.lower()}"
        shutil.copy2(source, target)
        artifact = {"kind": label, "path": f"physical/{target.name}",
                    "sha256": sha256(target), "bytes": target.stat().st_size,
                    "source": str(source)}
        artifacts.append(artifact)
        return target

    paths = {}
    for key in ("gds", "layout_image", "netlist", "sdc", "spef", "sdf", "liberty", "drc_deck", "lvs_deck"):
        value = data.get("artifacts", {}).get(key)
        if key in ("sdc", "spef", "sdf", "liberty") and isinstance(value, list) and value:
            paths[key] = [capture(f"{key}_{index}", entry) for index, entry in enumerate(value)]
        else:
            paths[key] = capture(key, value or None)
    for key in ("top", "source_revision", "pdk", "pdk_version"):
        if not data.get(key):
            issues.append(f"Missing provenance: {key}")
    if paths["gds"]:
        with paths["gds"].open("rb") as stream:
            header = stream.read(4)
        if paths["gds"].suffix not in (".gds", ".gdsii") or header != b"\x00\x06\x00\x02":
            issues.append("GDS header/extension invalid (header check is not full geometry validation)")
        if data.get("gds_sha256") != sha256(paths["gds"]):
            issues.append("GDS SHA256 not bound to this physical manifest")
    if paths["layout_image"]:
        with paths["layout_image"].open("rb") as stream:
            header = stream.read(8)
        if not (header == b"\x89PNG\r\n\x1a\n" or header[:3] == b"\xff\xd8\xff"):
            issues.append("Layout image must be PNG or JPEG")

    checks = []
    for name in ("drc", "lvs"):
        item = data.get(name, {})
        report = capture(name + "_report", item.get("report"))
        complete = report is not None and all(item.get(k) for k in ("tool", "version", "command"))
        complete = complete and type(item.get("exit_code")) is int and item["exit_code"] == 0
        if name == "drc" and item.get("format", "normalized") not in ("normalized", "klayout-rdb"):
            issues.append("Unsupported DRC report format")
            complete = False
        metric = item.get("violations" if name == "drc" else "matched")
        if name == "drc" and report and item.get("format") == "klayout-rdb":
            try:
                tree = ET.parse(report).getroot()
                if tree.tag != "report-database" or tree.find("items") is None:
                    raise ValueError("Not a KLayout report database")
                if tree.findtext("top-cell") != data.get("top"):
                    raise ValueError("DRC report top-cell differs from manifest top")
                multiplicities = [int(entry.findtext("multiplicity", "1")) for entry in tree.findall("./items/item")]
                if any(value < 1 for value in multiplicities):
                    raise ValueError("Invalid DRC marker multiplicity")
                metric = sum(multiplicities)
            except (ET.ParseError, ValueError) as error:
                issues.append(f"DRC parser: {error}")
                complete = False
        valid_metric = (type(metric) is int and metric >= 0) if name == "drc" else type(metric) is bool
        failed = (type(item.get("exit_code")) is int and item["exit_code"] != 0)
        if valid_metric:
            failed = failed or (metric != 0 if name == "drc" else not metric)
        status = "FAIL" if failed else "REPORTED_PASS" if complete and valid_metric else "INCOMPLETE"
        checks.append({"id": name, "status": status, "value": metric,
                       "tool": item.get("tool"), "version": item.get("version"),
                       "command": item.get("command"), "exit_code": item.get("exit_code")})

    views, seen = data.get("required_timing_views", []), set()
    if not views or not all(isinstance(v, str) for v in views) or len(views) != len(set(views)):
        issues.append("Declare a unique required_timing_views matrix: corner/mode/setup-or-hold")
    for index, item in enumerate(data.get("timing", [])):
        report = capture(f"timing_{index}_report", item.get("report"))
        view = f'{item.get("corner")}/{item.get("mode")}/{item.get("check")}'
        if view in seen:
            issues.append(f"Duplicate timing view: {view}")
        seen.add(view)
        complete = report is not None and all(item.get(k) for k in ("corner", "mode", "tool", "version", "command"))
        complete = complete and item.get("stage") == "post_route" and item.get("check") in ("setup", "hold")
        complete = complete and item.get("unit") in ("s", "ms", "us", "ns", "ps", "fs")
        complete = complete and type(item.get("exit_code")) is int and item["exit_code"] == 0
        valid = all(finite_number(item.get(k)) for k in ("wns", "tns"))
        count = item.get("unconstrained_endpoints")
        valid = valid and type(count) is int and count >= 0
        failed = type(item.get("exit_code")) is int and item["exit_code"] != 0
        if valid:
            failed = failed or item["wns"] < 0 or item["tns"] < 0 or count > 0
            if item["tns"] > 0:
                complete = False  # Positive TNS is not a valid signed TNS value.
        status = "FAIL" if failed else "REPORTED_PASS" if complete and valid else "INCOMPLETE"
        display = {key: None if type(value) is float and not math.isfinite(value) else value
                   for key, value in item.items()}
        checks.append(dict(display, id=view, status=status))
    if set(views) != seen:
        issues.append("Timing views differ from the declared required corner/mode/check matrix")
    if not {"setup", "hold"}.issubset({v.rsplit("/", 1)[-1] for v in views}):
        issues.append("Required timing matrix must include both setup and hold")
    status = "FAIL" if any(c["status"] == "FAIL" for c in checks) else "INCOMPLETE"
    if not issues and checks and all(c["status"] == "REPORTED_PASS" for c in checks):
        status = "REPORTED_PASS"
    return {"status": status, "issues": issues, "checks": checks, "artifacts": artifacts,
            "metadata": {k: data.get(k) for k in ("top", "source_revision", "pdk", "pdk_version", "gds_sha256")},
            "manifest_sha256": sha256(manifest),
            "limitation": data.get("provenance_limitation", "Producer-reported evidence only. Imported metrics are not an independent DRC/LVS/STA rerun or tapeout signoff.")}
