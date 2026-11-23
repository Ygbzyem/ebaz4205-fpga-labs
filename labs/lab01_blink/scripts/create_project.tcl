# -----------------------------------------------------------------------------
# create_project.tcl - Create the Vivado project for Lab 01 (Vivado 2020.2)
#
# The project is created in build/lab01_blink/ (ignored by Git). Source files
# are referenced in place (not copied), so edits in rtl/ tb/ constraints/ are
# what Git tracks.
#
# Usage (from labs/lab01_blink):
#   vivado -mode batch -source scripts/create_project.tcl      (then open the .xpr)
#   or, in the Vivado Tcl console:  source <path>/scripts/create_project.tcl
#
# WARNING: -force deletes an existing build/lab01_blink project.
# -----------------------------------------------------------------------------

set lab_dir   [file normalize [file join [file dirname [info script]] ..]]
set proj_name lab01_blink
set proj_dir  [file join $lab_dir build $proj_name]
set part      xc7z010clg400-1
set top_rtl   lab01_top
set top_sim   tb_blink_core

create_project $proj_name $proj_dir -part $part -force
set_property target_language Verilog [current_project]

# Design sources (Synthesis + Simulation)
set rtl_files [glob -nocomplain [file join $lab_dir rtl *.v]]
if {[llength $rtl_files] > 0} {
    add_files -norecurse $rtl_files
} else {
    puts "INFO: no RTL in rtl/ yet - add it later with add_files"
}

# Simulation-only sources
set tb_files [glob -nocomplain [file join $lab_dir tb *.v]]
if {[llength $tb_files] > 0} {
    add_files -fileset sim_1 -norecurse $tb_files
}

# Constraints
set xdc_files [glob -nocomplain [file join $lab_dir constraints *.xdc]]
if {[llength $xdc_files] > 0} {
    add_files -fileset constrs_1 -norecurse $xdc_files
}

# Tops
set_property top $top_rtl [get_filesets sources_1]
set_property top $top_sim [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# The testbench needs ~2 us at HALF_PERIOD = 5; default run time is 1000 ns
set_property -name {xsim.simulate.runtime} -value {10us} -objects [get_filesets sim_1]

puts "INFO: project created at $proj_dir"
