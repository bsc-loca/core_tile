set project spyglass_reports
new_project ${project}
current_methodology $env(SPYGLASS_HOME)/GuideWare/latest/block/rtl_handoff

##Data Import Section
read_file -type sourcelist ./filelist.f

##Common Options Section
set_option top top_tile
read_file -type awl ./scripts/waiver.awl

set_option language_mode mixed
set_option designread_disable_flatten no
# for bigger modules synthesis
set_option mthresh 100000
set_option allow_module_override yes

set_option enableSV09 yes

set_parameter handle_large_bus yes

##Goal Setup Section
define_goal my_lint -policy {lint} {set_parameter fullpolicy yes}

# Overload rules
#set_option overloadrules 12345+severity=Error

current_goal lint/lint_rtl
set_option enable_pass_exit_codes yes
set_goal_option enable_pass_exit_codes yes

set rc [run_goal]
close_project -force

exit [lindex $rc 0]