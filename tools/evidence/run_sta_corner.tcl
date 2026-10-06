set lib_file $env(LIB_FILE)
set odb_file $env(ODB_FILE)
set spef_file $env(SPEF_FILE)
set sdc_file $env(SDC_FILE)
set corner_name $env(CORNER_NAME)

puts "================================================================================"
puts "Running STA for Corner: $corner_name"
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

puts "\n>>> SETUP TIMING REPORT (MAX DELAY) for $corner_name:"
report_checks -path_delay max -fields {slew cap input fanout} -digits 3

puts "\n>>> HOLD TIMING REPORT (MIN DELAY) for $corner_name:"
report_checks -path_delay min -fields {slew cap input fanout} -digits 3

puts "\n>>> SLACK SUMMARY for $corner_name:"
puts -nonewline "Setup WNS: "
report_worst_slack -max
puts -nonewline "Setup TNS: "
report_tns -max
puts -nonewline "Hold WNS: "
report_worst_slack -min
puts -nonewline "Hold TNS: "
report_tns -min

exit
