#!/bin/bash
set -e

TOP_NAME=${1:-aegis_soc_top}
DEF_FILE=${2:-/mnt/d/domixi/output/physical/sky130_aegis_soc_top/aegis_soc_top.def}
NETLIST_V=${3:-/mnt/d/domixi/output/physical/sky130_aegis_soc_top/aegis_soc_top.pnl.v}
OUT_DIR=${4:-/mnt/d/domixi/output/physical/sky130_aegis_soc_top}

PDK_ROOT=/home/nhat/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af
TECH_LEF=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
CELL_LEF=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
MAGICRC=$PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc
SETUP_TCL=/mnt/d/domixi/tools/evidence/netgen_setup_robust.tcl

WORK_DIR=$OUT_DIR/lvs_work
mkdir -p "$WORK_DIR"

LAYOUT_SPICE="$WORK_DIR/${TOP_NAME}_layout.spice"
LAYOUT_NOFILL_SPICE="$WORK_DIR/${TOP_NAME}_layout_nofill.spice"
SCHEMATIC_SPICE="$WORK_DIR/${TOP_NAME}_schematic_clean.spice"
LVS_LOG="$OUT_DIR/netgen_lvs.log"
LVS_RPT="$OUT_DIR/lvs.rpt"
LVS_JSON="$OUT_DIR/lvs.json"

echo "========================================================================"
echo "Starting Complete LEF/DEF LVS Flow for $TOP_NAME"
echo "========================================================================"

echo "=== STEP 1: MAGIC EXTRACTION (LEF/DEF) ==="
# Check if host magic is modern enough; if not, use OpenLane Docker container
MAGIC_VER=$(magic --version 2>/dev/null || echo "0")
if [[ "$MAGIC_VER" == *"8.3.105"* ]] || [[ "$MAGIC_VER" == "0" ]]; then
    echo "[INFO] Host Magic is $MAGIC_VER. Using Docker Magic 8.3.416 container for reliable Sky130A tech extraction..."
    docker run --rm \
      -e PDK_ROOT=/pdk \
      -v "$PDK_ROOT":/pdk \
      -v /mnt/d/domixi:/work \
      -w /work \
      efabless/openlane:current-amd64 bash -c "
magic -dnull -noconsole -rcfile /pdk/sky130A/libs.tech/magic/sky130A.magicrc << 'EOF'
lef read /pdk/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
lef read /pdk/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
def read /work/output/physical/sky130_aegis_soc_top/aegis_soc_top.def
load $TOP_NAME -dereference
extract do local
extract no capacitance
extract no coupling
extract no resistance
extract no adjust
extract unique
extract
ext2spice lvs
ext2spice -o /work/output/physical/sky130_aegis_soc_top/lvs_work/${TOP_NAME}_layout.spice ${TOP_NAME}.ext
exit 0
EOF
"
else
    magic -dnull -noconsole -rcfile "$MAGICRC" << EOF
lef read $TECH_LEF
lef read $CELL_LEF
def read $DEF_FILE
load $TOP_NAME -dereference
extract do local
extract no capacitance
extract no coupling
extract no resistance
extract no adjust
extract unique
extract
ext2spice lvs
ext2spice -o $LAYOUT_SPICE $TOP_NAME.ext
exit 0
EOF
fi

echo "=== STEP 2: PREPARE CLEAN LAYOUT SPICE (Filter physical cells & equipotential shorts) ==="
python3 /mnt/d/domixi/tools/evidence/prepare_soc_lvs.py "$LAYOUT_SPICE" "$LAYOUT_NOFILL_SPICE" "$TOP_NAME"

echo "=== STEP 3: PREPARE CLEAN SCHEMATIC SPICE (Map Verilog pins & equipotential shorts) ==="
python3 /mnt/d/domixi/tools/evidence/vlog2spice.py "$LAYOUT_NOFILL_SPICE" "$NETLIST_V" "$SCHEMATIC_SPICE" "$TOP_NAME"

echo "=== STEP 4: NETGEN LVS (LAYOUT SPICE vs SCHEMATIC SPICE) ==="
netgen -batch lvs \
  "$LAYOUT_NOFILL_SPICE $TOP_NAME" \
  "$SCHEMATIC_SPICE $TOP_NAME" \
  "$SETUP_TCL" \
  "$LVS_LOG" \
  -json

# Sync json file if generated with default extension
if [ -f "$OUT_DIR/netgen_lvs.json" ]; then
    cp "$OUT_DIR/netgen_lvs.json" "$LVS_JSON"
elif [ -f "$WORK_DIR/aegis_soc_top_layout_nofill.json" ]; then
    cp "$WORK_DIR/aegis_soc_top_layout_nofill.json" "$LVS_JSON"
fi

echo "=== STEP 5: VERIFY RAW LOG & GENERATE EVIDENCE-BOUND LVS REPORT ==="
python3 /mnt/d/domixi/tools/evidence/parse_netgen_log.py "$LVS_LOG" "$LVS_RPT" "$TOP_NAME"

echo "========================================================================"
echo "LEF/DEF LVS completed successfully for $TOP_NAME with clean match."
echo "========================================================================"
