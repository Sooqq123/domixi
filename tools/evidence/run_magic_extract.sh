#!/bin/bash
set -e

TOP_NAME=$1
GDS_FILE=$2
SPICE_OUT=$3

export TOP_NAME
export GDS_FILE
export SPICE_OUT
export PDK_ROOT=/home/nhat/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af
MAGICRC=$PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc

EXT_DIR=$(dirname "$SPICE_OUT")/magic_ext
mkdir -p "$EXT_DIR"
cd "$EXT_DIR"

echo "[MAGIC-EXT] Sourcing magic extraction for $TOP_NAME from $GDS_FILE..."
magic -dnull -noconsole -rcfile "$MAGICRC" << EOF
drc off
gds readonly true
gds rescale false
gds warning default
gds read $GDS_FILE
load $TOP_NAME -dereference
extract do local
extract no capacitance
extract no coupling
extract no resistance
extract no adjust
extract unique
extract
ext2spice lvs
ext2spice -o $SPICE_OUT $TOP_NAME.ext
exit 0
EOF

echo "[MAGIC-EXT] Extracted SPICE generated: $SPICE_OUT"
