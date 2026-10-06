"""Run inside KLayout: klayout -z -r export_layout.py -rd gds_path=... -rd png_path=..."""

from pathlib import Path
import traceback
import pya


def export():
    source = Path(gds_path).resolve()  # Injected by KLayout -rd.
    target = Path(png_path).resolve()
    if not source.is_file() or source.suffix.lower() not in (".gds", ".gdsii"):
        raise ValueError("Supply an existing GDS/GDSII file")
    if target.exists() or target.suffix.lower() != ".png":
        raise ValueError("Supply a new .png output path; existing images are not overwritten")
    window = pya.Application.instance().main_window()
    cellview = window.load_layout(str(source), 1)
    layout = cellview.layout()
    top_name = globals().get("top_cell", "")
    if top_name:
        cell = layout.cell(top_name)
        if cell is None:
            raise ValueError("Requested top cell does not exist")
    elif len(layout.top_cells()) == 1:
        cell = layout.top_cells()[0]
    else:
        raise ValueError("Multiple top cells: provide -rd top_cell=<name>")
    view = window.current_view()
    view.select_cell(cell.cell_index(), 0)
    if globals().get("layer_props"):
        view.load_layer_props(str(Path(layer_props).resolve()))
    else:
        view.add_missing_layers()
    view.max_hier()
    view.zoom_fit()
    target.parent.mkdir(parents=True, exist_ok=True)
    view.save_image(str(target), 1600, 1000)
    print("Layout image exported from GDS:", target)


try:
    export()
except Exception:
    traceback.print_exc()
    pya.Application.instance().exit(1)
else:
    pya.Application.instance().exit(0)
