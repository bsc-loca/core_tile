################################################################################
# Helper Functions                                                             #
################################################################################

set HPDCACHE_DIR "${g_accel_dir}/rtl/dcache/"

# Function to parse flist files
proc parseFlist {flistFile &_includeDirs &_sourceFiles &_defines basePath} {
    global HPDCACHE_DIR
    upvar 1 ${&_includeDirs} includeDirs
    upvar 1 ${&_sourceFiles} sourceFiles
    upvar 1 ${&_defines} defines

    puts "\[Sargantana\] Parsing $flistFile"

    set file [open $flistFile r]
    set content [read $file]
    close $file

    set lines [split $content "\n"]
    foreach line $lines {
        # Ignore empty lines
        if {[string trim $line] eq ""} {
            continue
        }

        # Ignore comments
        if {[string match -nocase "//*" [string trimleft $line]]} {
            continue
        }

        # Parse recursively for -F <path>
        if {[regexp {^-F\s+(.+)} $line - match]} {
            set subFlist [file join $basePath [subst -nocommands $match]]
            parseFlist $subFlist includeDirs sourceFiles defines [file dirname $subFlist]
        }

        # Parse recursively for -f <path>
        if {[regexp {^-f\s+(.+)} $line - match]} {
            # Substitute environment variables in the file path
            set subFlist [file join $basePath [subst -nocommands $match]]
            parseFlist $subFlist includeDirs sourceFiles defines ""
        }

        # Add directory to includeDirs for +incdir+
        if {[regexp {^\+incdir\+(.+)} $line - match]} {
            set directory [subst -nocommands $match]
            lappend includeDirs [file join $basePath $directory]
        }

        # Add define to list of defines for +define+
        if {[regexp {^\+define\+(.+)} $line - match]} {
            set definition [subst -nocommands $match]
            lappend defines $definition
        }

        # Add source file to sourceFiles
        if {![regexp {^-F\s+.+} $line] && ![regexp {^-f\s+.+} $line] && ![regexp {^\+incdir\+.+} $line] && ![regexp {^\+define\+.+} $line]} {
            set filePath [subst -nocommands $line]
            lappend sourceFiles [file join $basePath $filePath]
        }
    }
}

################################################################################
# Parse flists                                                                 #
################################################################################

set files_to_add [list ]
set include_paths [list ]
set define_list [list ]

puts "\[Sargantana\] Parsing root filelist"
parseFlist ${g_accel_dir}/fpga/meep_shell/filelist.f include_paths files_to_add define_list ${g_accel_dir}/fpga/meep_shell/

################################################################################
# Add files                                                                    #
################################################################################

puts "\[Sargantana\] Adding files to Vivado project"

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Add files
set fileset_obj [get_filesets sources_1]

add_files -norecurse -fileset $fileset_obj $files_to_add

################################################################################
# Configure include directories                                                #
################################################################################

puts "\[Sargantana\] Configuring include directories"

# Mark include directories
set_property include_dirs $include_paths $fileset_obj

################################################################################
# Setup defines and global includes                                            #
################################################################################

puts "\[Sargantana\] Configuring global includes"

# Mark directories with global verilog defines
set global_includes [lsearch -all -inline $files_to_add *.svh]

# Mark files with global verilog defines
foreach item $global_includes {
  set file_obj [get_files -of_objects $fileset_obj [list $item]]
  set_property "is_global_include" "1" $file_obj
}

puts "\[Sargantana\] Configuring defines found in flists"

# Add defines parsed from the flist
set_property verilog_define $define_list $fileset_obj

################################################################################
# Add bootrom                                                                  #
################################################################################

add_files -norecurse "${g_accel_dir}/fpga/meep_shell/bootrom.hex"
set_property file_type {Memory Initialization Files} [get_files  "${g_accel_dir}/fpga/meep_shell/bootrom.hex"]
