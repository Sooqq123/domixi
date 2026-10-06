import os
import sys
import xml.etree.ElementTree as ET
import re
import pya

def smart_patch_gds(rpt_file, in_gds, out_gds, top_name):
    print(f"[SMART-PATCH] Parsing DRC report: {rpt_file}")
    tree = ET.parse(rpt_file)
    root = tree.getroot()
    items = [it for it in root.findall('.//item') if it.findtext('category') == "'m3.6'"]
    print(f"[SMART-PATCH] Found {len(items)} m3.6 violation items.")

    layout = pya.Layout()
    layout.read(in_gds)
    top = layout.cell(top_name)
    if not top:
        top = layout.top_cell()
    dbu = layout.dbu
    m3_layer = layout.layer(70, 20)

    orig_reg = pya.Region(top.shapes(m3_layer))
    min_space_dbu = int(round(0.300 / dbu))

    dx_both = int(round(0.080 / dbu))
    dx_single = int(round(0.160 / dbu))

    patches = pya.Region()
    resolved_count = 0

    for idx, it in enumerate(items):
        val = it.findtext('values/value')
        pts = re.findall(r'([\d.]+),([\d.]+)', val)
        xs = [float(p[0]) for p in pts]
        ys = [float(p[1]) for p in pts]
        xmin = int(round(min(xs) / dbu))
        xmax = int(round(max(xs) / dbu))
        ymin = int(round(min(ys) / dbu))
        ymax = int(round(max(ys) / dbu))

        bbox = pya.Box(xmin, ymin, xmax, ymax)
        local_search = pya.Box(xmin - min_space_dbu*2, ymin - min_space_dbu*2, xmax + min_space_dbu*2, ymax + min_space_dbu*2)
        local_shapes = orig_reg.interacting(pya.Region(local_search))
        this_shape = local_shapes.interacting(pya.Region(bbox))
        other_shapes = local_shapes - this_shape
        # Sized obstacle region
        other_halo = other_shapes.sized(min_space_dbu)

        candidates = [
            # Candidate 0: symmetric (+80nm both sides)
            pya.Box(xmin - dx_both, ymin, xmax + dx_both, ymax),
            # Candidate 1: extend right (+160nm right)
            pya.Box(xmin, ymin, xmax + dx_single, ymax),
            # Candidate 2: extend left (+160nm left)
            pya.Box(xmin - dx_single, ymin, xmax, ymax),
            # Candidate 3: extend top/bottom (+75nm top and bottom)
            pya.Box(xmin, ymin - int(round(0.075/dbu)), xmax, ymax + int(round(0.075/dbu))),
        ]

        chosen = None
        for cand in candidates:
            cand_reg = pya.Region(cand)
            if (cand_reg & other_halo).is_empty():
                chosen = cand
                break

        if chosen is None:
            chosen = candidates[1] if (pya.Region(candidates[1]) & other_halo).area() < (pya.Region(candidates[0]) & other_halo).area() else candidates[0]
            print(f"  [WARN] Item {idx} at ({min(xs)}, {min(ys)}) had tight space.")
        else:
            resolved_count += 1

        patches.insert(chosen)

    print(f"[SMART-PATCH] Successfully found DRC-clean patch candidates for {resolved_count}/{len(items)} items.")
    top.shapes(m3_layer).insert(patches)
    layout.write(out_gds)
    print(f"[SMART-PATCH] Saved patched GDS to {out_gds}.")

def main():
    _rpt = globals().get('rpt_file')
    _in = globals().get('in_gds')
    _out = globals().get('out_gds')
    _top = globals().get('top_name')
    if not (_rpt and _in and _out and _top):
        if len(sys.argv) >= 5:
            _rpt, _in, _out, _top = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
        else:
            print("Usage: patch_drc_m3_smart.py <rpt> <in_gds> <out_gds> <top_name>")
            pya.Application.instance().exit(1)
            return
    smart_patch_gds(_rpt, _in, _out, _top)
    pya.Application.instance().exit(0)

if __name__ == "__main__":
    main()
