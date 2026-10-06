set lib_file $env(LIB_FILE)
set odb_file $env(ODB_FILE)
set spef_file $env(SPEF_FILE)
set sdc_file $env(SDC_FILE)
set corner_name $env(CORNER_NAME)

read_liberty $lib_file
read_db $odb_file
read_spef $spef_file
read_sdc $sdc_file
set_propagated_clock [all_clocks]

puts "================================================================================"
puts "CORNER $corner_name: DETAILED TIMING REPORT"
puts "================================================================================"

puts "--- Top 1 Setup Path ---"
report_checks -path_delay max -fields {slew cap input fanout} -digits 3

puts "--- Top 1 Hold Path ---"
report_checks -path_delay min -fields {slew cap input fanout} -digits 3

puts "--- Reg-to-Reg Setup Path ---"
report_checks -path_delay max -to [all_registers -data_pins] -fields {slew cap input fanout} -digits 3

puts "--- Reg-to-Reg Hold Path ---"
report_checks -path_delay min -to [all_registers -data_pins] -fields {slew cap input fanout} -digits 3

puts "--- Slack Summary ---"
puts "WNS (max): [sta::worst_slack max]"
puts "TNS (max): [sta::total_negative_slack max]"
puts "WNS (min): [sta::worst_slack min]"
puts "TNS (min): [sta::total_negative_slack min]"

exit
