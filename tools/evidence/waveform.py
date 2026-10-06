"""Bounded, streaming VCD preview. Raw VCD remains the authoritative trace."""

from fnmatch import fnmatchcase
from html import escape
from pathlib import Path
import re


def read_vcd(path: Path, patterns=(), start=0, end=None, max_signals=12, max_events=2000):
    if start < 0 or (end is not None and end <= start):
        raise ValueError("Require 0 <= start < end (VCD timestamp ticks)")
    scopes, declarations, header = [], [], []
    with path.open(encoding="ascii", errors="replace") as stream:
        for line in stream:
            header.append(line)
            if "$enddefinitions" in line:
                break
        else:
            raise ValueError("VCD has no enddefinitions marker")
        header_text = "".join(header)
        match = re.search(r"\$timescale\s+(.*?)\s+\$end", header_text, re.S)
        if not match:
            raise ValueError("VCD timescale is missing")
        timescale = " ".join(match[1].split())
        for directive, args in re.findall(r"\$(scope|upscope|var)\s+(.*?)\$end", header_text, re.S):
            fields = args.split()
            if directive == "scope":
                scopes.append(fields[1])
            elif directive == "upscope":
                scopes.pop()
            else:
                declarations.append({"name": ".".join(scopes + [fields[3]]),
                                     "width": int(fields[1]), "code": fields[2]})
        # Prefer testbench-level signals; preserve aliases by full hierarchical name.
        candidates = sorted(declarations, key=lambda d: (d["name"].count("."), d["name"]))
        selected = []
        for pattern in patterns or ("*clk", "*rst*", "*reset*", "*valid*", "*ready*", "*"):
            for signal in candidates:
                if fnmatchcase(signal["name"], pattern) and signal not in selected:
                    selected.append(signal)
                    if len(selected) == max_signals:
                        break
            if len(selected) == max_signals:
                break
        if not selected:
            raise ValueError("No VCD signals match the requested patterns")
        events = {s["code"]: [] for s in selected}
        previous = {code: "x" for code in events}
        timestamp, last_timestamp, capped = 0, 0, False
        for line in stream:
            token = line.strip()
            if not token:
                continue
            if token.startswith("#"):
                timestamp = int(token[1:])
                if timestamp < last_timestamp:
                    raise ValueError("VCD timestamps are not monotonic")
                last_timestamp = timestamp
                if end is not None and timestamp > end:
                    break
                continue
            if token[0] in "01xXzZ":
                code, value = token[1:], token[0].lower()
            elif token[0] in "bB":
                fields = token[1:].split()
                if len(fields) != 2:
                    continue
                value, code = fields[0].lower(), fields[1]
            else:
                continue
            if code not in events:
                continue
            if timestamp <= start:
                previous[code] = value
            elif len(events[code]) < max_events:
                events[code].append((timestamp, value))
            else:
                capped = True
        stop = min(last_timestamp, end) if end is not None else last_timestamp
        if stop <= start:
            raise ValueError("VCD contains no time span in the requested window")
        for signal in selected:
            signal["events"] = [(start, previous[signal["code"]])] + events[signal["code"]]
        # Clip every lane at the first overflow boundary, avoiding invented flat tails.
        if capped:
            stop = min([stop] + [v[-1][0] for v in events.values() if len(v) >= max_events])
        return {"timescale": timescale, "start": start, "end": stop,
                "truncated": capped, "signals": selected, "declared_signals": len(declarations)}


def render_svg(trace, output: Path):
    left, plot, lane = 350, 1000, 42
    height = 105 + lane * len(trace["signals"])
    start, end = trace["start"], trace["end"]
    scale = plot / max(1, end - start)
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="{height}" viewBox="0 0 1400 {height}">',
             '<rect width="100%" height="100%" fill="#111827"/>',
             '<g font-family="monospace" font-size="12" fill="#e5e7eb">',
             f'<text x="20" y="23">VCD preview — tick = {escape(trace["timescale"])}; raw VCD is authoritative</text>']
    if trace["truncated"]:
        parts.append('<text x="20" y="43" fill="#fbbf24">Preview clipped at event limit; select a smaller time window.</text>')
    for i in range(6):
        x = left + plot * i / 5
        parts += [f'<path d="M{x},55 V{height - 20}" stroke="#374151"/>',
                  f'<text x="{x}" y="65">{start + (end - start) * i / 5:g}</text>']
    for index, signal in enumerate(trace["signals"]):
        y = 93 + index * lane
        parts.append(f'<text x="12" y="{y}">{escape(signal["name"][-45:])}<title>{escape(signal["name"])}</title></text>')
        values = [(t, v) for t, v in signal["events"] if t <= end] + [(end, "")]
        for j, ((t, value), (next_t, _)) in enumerate(zip(values, values[1:])):
            x1, x2 = left + (t - start) * scale, left + (next_t - start) * scale
            unknown = bool(set(value) & {"x", "z"})
            color = "#fbbf24" if unknown else "#34d399"
            if signal["width"] == 1 and value in {"0", "1"}:
                level = y - 13 if value == "1" else y + 5
                parts.append(f'<path d="M{x1:.2f},{level} H{x2:.2f}" stroke="{color}" fill="none"/>')
                if j and values[j-1][1] in {"0", "1"} and values[j-1][1] != value:
                    parts.append(f'<path d="M{x1:.2f},{y-13} V{y+5}" stroke="{color}"/>')
            else:
                label = value.upper() if unknown else f"0x{int(value, 2):X}"
                parts.append(f'<rect x="{x1:.2f}" y="{y-15}" width="{max(0, x2-x1):.2f}" height="23" fill="none" stroke="{color}"><title>{escape(label)}</title></rect>')
                if x2 - x1 > 12 + len(label) * 7:
                    parts.append(f'<text x="{x1+4:.2f}" y="{y+1}" fill="{color}">{escape(label)}</text>')
    parts.append('</g></svg>')
    output.write_text("\n".join(parts), encoding="utf-8")
