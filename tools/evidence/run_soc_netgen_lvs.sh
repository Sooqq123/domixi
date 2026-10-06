#!/bin/bash
set -e

TOP_NAME=${1:-aegis_soc_top}
OUT_DIR=/mnt/d/domixi/output/physical/sky130_aegis_soc_top
WORK_DIR=$OUT_DIR/lvs_work
mkdir -p "$WORK_DIR"

LAYOUT_SPICE=$WORK_DIR/${TOP_NAME}_layout.spice
LAYOUT_NOFILL_SPICE=$WORK_DIR/${TOP_NAME}_layout_nofill.spice
PNL_VERILOG=$OUT_DIR/${TOP_NAME}.pnl.v
SCHEMATIC_SPICE=$WORK_DIR/${TOP_NAME}_schematic_clean.spice
SETUP_TCL=/mnt/d/domixi/tools/evidence/netgen_setup_robust.tcl
LOG_FILE=$OUT_DIR/netgen_lvs.log
JSON_FILE=$OUT_DIR/lvs.json
LVS_RPT=$OUT_DIR/lvs.rpt

echo "========================================================================"
echo "Starting Robust SoC Netgen LVS for $TOP_NAME"
echo "========================================================================"

echo "=== STEP 1: PREPARE LAYOUT SPICE (Filter physical cells & equipotential shorts) ==="
python3 /mnt/d/domixi/tools/evidence/prepare_soc_lvs.py "$LAYOUT_SPICE" "$LAYOUT_NOFILL_SPICE" "$TOP_NAME"

echo "=== STEP 2: PREPARE SCHEMATIC SPICE (Map Verilog pins & equipotential shorts) ==="
python3 /mnt/d/domixi/tools/evidence/vlog2spice.py "$LAYOUT_NOFILL_SPICE" "$PNL_VERILOG" "$SCHEMATIC_SPICE" "$TOP_NAME"

echo "=== STEP 3: RUN NETGEN LVS COMPARISON ==="
# Netgen outputs JSON to the file specified by LOG_FILE or alongside it
netgen -batch lvs \
  "$LAYOUT_NOFILL_SPICE $TOP_NAME" \
  "$SCHEMATIC_SPICE $TOP_NAME" \
  "$SETUP_TCL" \
  "$LOG_FILE" \
  -json

# Sync json file if generated with default extension
if [ -f "$OUT_DIR/netgen_lvs.json" ]; then
    cp "$OUT_DIR/netgen_lvs.json" "$JSON_FILE"
elif [ -f "$WORK_DIR/aegis_soc_top_layout_nofill.json" ]; then
    cp "$WORK_DIR/aegis_soc_top_layout_nofill.json" "$JSON_FILE"
fi

echo "=== STEP 4: STRICT RAW LOG VERIFICATION & REPORT GENERATION ==="
python3 /mnt/d/domixi/tools/evidence/parse_netgen_log.py "$LOG_FILE" "$LVS_RPT" "$TOP_NAME"

echo "========================================================================"
echo "Netgen LVS completed successfully for $TOP_NAME with clean match."
echo "========================================================================"
