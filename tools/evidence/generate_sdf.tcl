set lib_file $env(LIB_FILE)
set odb_file $env(ODB_FILE)
set spef_file $env(SPEF_FILE)
set sdc_file $env(SDC_FILE)
set out_sdf $env(OUT_SDF)

puts "================================================================================"
puts "Generating SDF: $out_sdf"
puts "  Lib:  $lib_file"
puts "  ODB:  $odb_file"
puts "  SPEF: $spef_file"
puts "  SDC:  $sdc_file"
puts "================================================================================"

read_liberty $lib_file
read_db $odb_file
read_spef $spef_file
read_sdc $sdc_file
set_propagated_clock [all_clocks]

write_sdf $out_sdf
puts ">>> SDF generated successfully: $out_sdf"
exit
