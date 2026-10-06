# Magic GDS extraction script for Sky130A
drc off
gds readonly true
gds rescale false
gds warning default
puts "Reading GDS: $::env(GDS_FILE)"
gds read $::env(GDS_FILE)
puts "Loading top cell: $::env(TOP_NAME)"
load $::env(TOP_NAME) -dereference

puts "Extracting..."
extract do local
extract no capacitance
extract no coupling
extract no resistance
extract no adjust
extract unique
extract

puts "Converting to SPICE..."
ext2spice lvs
ext2spice -o $::env(SPICE_OUT) $::env(TOP_NAME).ext
puts "Extraction completed successfully."
exit 0
