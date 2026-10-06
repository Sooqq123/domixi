#!/bin/bash
set -e

TOP_NAME=aegis_soc_top
DEF_FILE=/mnt/d/domixi/output/physical/sky130_aegis_soc_top/aegis_soc_top.def
OUT_DIR=/mnt/d/domixi/output/physical/sky130_aegis_soc_top

export PDK_ROOT=/home/nhat/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af
TECH_LEF=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
CELL_LEF=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
MAGICRC=$PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc

WORK_DIR=$OUT_DIR/lvs_work
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

LAYOUT_SPICE="$WORK_DIR/${TOP_NAME}_layout.spice"

echo "=== MAGIC EXTRACTION (LEF/DEF) FOR $TOP_NAME ==="
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

echo "Magic extraction completed for $TOP_NAME: $LAYOUT_SPICE"
