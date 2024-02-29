set DESIGN top_tile

# Open the filelist for reading
set file_path ./dc_filelist.f
set constraints_path ./1_constraints.tcl

set file [open $file_path "r"]

# Initialize an empty list to store the names
set names_list {}

# Read each line from the file and append it to the list
while {[gets $file name] != -1} {
    lappend names_list $name
}

# Close the file
close $file

sg_read_waiver -file ./scripts/lint_intel_waiver.awl

set_app_var search_path "./includes/"

set_app_var enable_lint true

# Reading Intel linting rules
source ./scripts/lint_intel_rules.tcl

analyze -format sverilog "$names_list"

elaborate $DESIGN

read_sdc $constraints_path

check_lint

report_lint -verbose -file report_lint.txt
report_lint

exit
