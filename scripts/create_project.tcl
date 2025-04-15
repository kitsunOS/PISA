set proj_name PISA
set proj_dir ./vivado_project
set part xc7a35tcpg236-1

set script_dir [file dirname [info script]]
set src_dir [file normalize "$script_dir/../src"]
set constr_dir [file normalize "$script_dir/../constr"]

if {[file exists "$proj_dir/$proj_name.xpr"]} {
    puts "Opening existing project..."
    open_project $proj_dir/$proj_name.xpr
} else {
    puts "Creating new project..."
    create_project $proj_name $proj_dir -part $part -force
}

add_files [glob -nocomplain "$src_dir/*.sv"]
# add_files [glob -nocomplain "$src_dir/*.svh"]
add_files -fileset constrs_1 [glob -nocomplain "$constr_dir/*.xdc"]

set_property top workbench [current_fileset]

update_compile_order -fileset sources_1

# Run via `vivado -mode batch -source scripts/create_project.tcl`