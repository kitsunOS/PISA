set proj_name PISA
set proj_dir ./vivado_project
set part xc7a35tcpg236-1

create_project $proj_name $proj_dir -part $part -force

set script_dir [file dirname [info script]]
set src_dir [file normalize "$script_dir/../src"]
set constr_dir [file normalize "$script_dir/../constr"]

add_files [glob -nocomplain "$src_dir/*.v"]
add_files -fileset constrs_1 [glob -nocomplain "$constr_dir/*.xdc"]

set_property top workbench [current_fileset]

update_compile_order -fileset sources_1

save_project_as $proj_name.xpr -force