import os
import sys
import pya

def patch_gds(input_gds, output_gds, top_name):
    print(f"[PATCH] Loading {input_gds}...")
    layout = pya.Layout()
    layout.read(input_gds)
    top = layout.cell(top_name)
    if not top:
        top = layout.top_cell()
    dbu = layout.dbu
    m3_layer = layout.layer(70, 20)

    # Convert to Region for robust geometric manipulation
    reg = pya.Region(top.shapes(m3_layer))
    reg.merge()

    min_area_dbu2 = int(round(0.240 / (dbu * dbu)))
    bad_shapes = reg.with_area(0, min_area_dbu2)
    print(f"[PATCH] Found {bad_shapes.count()} polygons with area < 0.240 um2 on layer 70/20")

    # For each bad polygon, create an extension patch along X (horizontal direction)
    # Adding 80nm (80 DBU) to left and right expands width from 585nm to 745nm
    # Area becomes 745 * 330 = 0.24585 um2 > 0.240 um2
    patches = pya.Region()
    dx = int(round(0.080 / dbu)) # 80 DBU
    for p in bad_shapes.each():
        bbox = p.bbox()
        patch_box = pya.Box(bbox.left - dx, bbox.bottom, bbox.right + dx, bbox.top)
        patches.insert(patch_box)

    print(f"[PATCH] Generated {patches.count()} patch boxes.")
    # Add patches into region and merge
    reg = reg + patches
    reg.merge()

    # Verify if any shapes remain < 0.240 um2
    remaining_bad = reg.with_area(0, min_area_dbu2)
    print(f"[PATCH] Remaining bad polygons after patch: {remaining_bad.count()}")

    # Clear old m3 shapes from top cell and insert patched region
    top.shapes(m3_layer).clear()
    top.shapes(m3_layer).insert(reg)

    print(f"[PATCH] Writing patched GDS to {output_gds}...")
    layout.write(output_gds)
    print("[PATCH] Done.")

def main():
    _in = globals().get('in_gds')
    _out = globals().get('out_gds')
    _top = globals().get('top_name')
    if not (_in and _out and _top):
        if len(sys.argv) >= 4:
            _in, _out, _top = sys.argv[1], sys.argv[2], sys.argv[3]
        else:
            print("Missing in_gds, out_gds, or top_name")
            pya.Application.instance().exit(1)
            return
    patch_gds(_in, _out, _top)
    pya.Application.instance().exit(0)

if __name__ == "__main__":
    main()
