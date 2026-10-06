#!/bin/bash
set -e

PDK_ROOT=/pdk
export PDK_ROOT
MAGICRC=$PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc
TECH_LEF=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
CELL_LEF=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
DEF_FILE=/work/output/physical/sky130_aegis_soc_top/aegis_soc_top.def
TOP_NAME=aegis_soc_top
WORK_DIR=/work/output/physical/sky130_aegis_soc_top/lvs_work/docker_test
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

LAYOUT_SPICE="$WORK_DIR/${TOP_NAME}_layout_extracted.spice"

echo "=== STEP 1: MAGIC EXTRACTION (LEF/DEF) IN DOCKER ==="
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

echo "Magic extraction finished: $LAYOUT_SPICE"
ls -lh "$LAYOUT_SPICE"
