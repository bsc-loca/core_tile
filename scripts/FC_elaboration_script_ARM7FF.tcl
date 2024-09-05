##########################
### To execute this tcl script from root folder: 
### fc_shell -f scripts/FC_elaboration_script_ARM7FF.tcl
##########################
## SETUP for DESIGN/RTL ##
##########################
# Obtain root path
set script_dir [file dirname [info script]]
set root_folder [file normalize [file join $script_dir ".."]]

set DESIGN top_tile 
set RTL_path $root_folder/rtl 
set RTL_filelist $root_folder/parsed_filelist.f

###########################
## SETUP for TECHNO/LIBS ##
###########################
set tech_file_path /technos/ARM7FF/PDK/ndm/1p15m_1x1xa1ya5y2yy2yx2r
set qrc_path /technos/GF12LPPLUS/PDK_V1.0_3.0/PEX/QRC/tcad/11M_3Mx_4Cx_2Kx_2Gx_LB
set std_cell_timing_path /technos/ARM7FF/standardCells
set std_cell_lef_path /technos/ARM7FF/standardCells
set macros_path /technos/ARM7FF/customMacros/cincoranch_macros

set search_path ""
	lappend search_path $std_cell_lef_path/sch300mcpp64_base_svt_c11/r14p0/lef/
	lappend search_path $std_cell_lef_path/sch300mcpp64_base_lvt_c11/r14p0/lef/
	lappend search_path $std_cell_lef_path/sch300mcpp64_base_ulvt_c11/r14p0/lef/
	lappend search_path $std_cell_lef_path/sch300mcpp64_base_svt_c8/r14p0/lef/
	lappend search_path $std_cell_lef_path/sch300mcpp64_base_lvt_c8/r14p0/lef/
	lappend search_path $std_cell_lef_path/sch300mcpp64_base_ulvt_c8/r14p0/lef/
	lappend search_path $std_cell_timing_path/sch300mcpp64_base_svt_c11/r14p0/db/
	lappend search_path $std_cell_timing_path/sch300mcpp64_base_lvt_c11/r14p0/db/
	lappend search_path $std_cell_timing_path/sch300mcpp64_base_ulvt_c11/r14p0/db/
	lappend search_path $std_cell_timing_path/sch300mcpp64_base_svt_c8/r14p0/db/
	lappend search_path $std_cell_timing_path/sch300mcpp64_base_lvt_c8/r14p0/db/
	lappend search_path $std_cell_timing_path/sch300mcpp64_base_ulvt_c8/r14p0/db/
	lappend search_path $macros_path/
	lappend search_path $root_folder/includes/
	lappend search_path "$RTL_path/core/sargantana/includes"
	lappend search_path "$RTL_path/core/sargantana/rtl"
	lappend search_path "$RTL_path/core/sargantana/rtl/csr/rtl"
	lappend search_path "$RTL_path/core/sargantana/rtl/common_cells/test"
	lappend search_path "$RTL_path/core/sargantana/rtl/common_cells/formal"
	lappend search_path "$RTL_path/core/sargantana/rtl/common_cells/src"
	lappend search_path "$RTL_path/core/sargantana/rtl/datapath/rtl/exe_stage/rtl"
	lappend search_path "$RTL_path/core/sargantana/rtl/datapath/rtl/exe_stage/rtl/fpu"
	lappend search_path "$RTL_path/core/sargantana/rtl/datapath/rtl/exe_stage/rtl/mixgemm_uengine/src/sim"
	lappend search_path "$RTL_path/core/sargantana/rtl/datapath/rtl/exe_stage/rtl/mixgemm_uengine/src/pkg"
	lappend search_path "$RTL_path/core/sargantana/rtl/datapath/rtl/exe_stage/rtl/mixgemm_uengine/src/rtl"
	lappend search_path "$RTL_path/core/sargantana/rtl/datapath/rtl/interface_csr/rtl"
	lappend search_path "$RTL_path/core/sargantana/rtl/datapath/rtl"
	lappend search_path "$RTL_path/core/sargantana/rtl/datapath/rtl/if_stage_1/rtl"
	lappend search_path "$RTL_path/core/sargantana/rtl/datapath/rtl/rr_stage/rtl"
	lappend search_path "$RTL_path/core/sargantana/rtl/datapath/rtl/wb_stage/rtl"
	lappend search_path "$RTL_path/core/sargantana/rtl/datapath/rtl/ir_stage/rtl"
	lappend search_path "$RTL_path/core/sargantana/rtl/datapath/rtl/if_stage_2/rtl"
	lappend search_path "$RTL_path/core/sargantana/rtl/datapath/rtl/id_stage/rtl"
	lappend search_path "$RTL_path/core/sargantana/rtl/control_unit/rtl"
	lappend search_path "$RTL_path/icache/includes"
	lappend search_path "$RTL_path/icache/rtl"
	lappend search_path "$RTL_path/icache/rtl/memory_library/rtl"
	lappend search_path "$RTL_path/icache/rtl/memory_library/include"
	lappend search_path "$RTL_path/mmu/includes"
	lappend search_path "$RTL_path/mmu/rtl"
	lappend search_path "$RTL_path/mmu/rtl/tlb"
	lappend search_path "$RTL_path/mmu/rtl/common"
	lappend search_path "$RTL_path/mmu/rtl/ptw"
	lappend search_path "$RTL_path/dcache/rtl/src"
	lappend search_path "$RTL_path/dcache/rtl/memory_library/rtl"
	lappend search_path "$RTL_path/dcache/rtl/memory_library/include"
	lappend search_path "$RTL_path/common_cells/formal"
	lappend search_path "$RTL_path/common_cells/src"
	lappend search_path "$RTL_path/interface_dcache/rtl"
	lappend search_path "$RTL_path/interface_icache/rtl"
	lappend search_path "$RTL_path/openpiton_adapter/rtl"
	lappend search_path "$RTL_path/dcache/rtl/include"
	lappend search_path "$RTL_path/core/sargantana/rtl/common_cells/include/common_cells"
	lappend search_path "$RTL_path/dcache/rtl/include"
set target_library ""
	lappend target_library sch300mcpp64_cln07ff41001_base_svt_c11_tt_typical_max_0p75v_85c.db
	lappend target_library sch300mcpp64_cln07ff41001_base_lvt_c11_tt_typical_max_0p75v_85c.db
	lappend target_library sch300mcpp64_cln07ff41001_base_ulvt_c11_tt_typical_max_0p75v_85c.db
	lappend target_library sch300mcpp64_cln07ff41001_base_svt_c8_tt_typical_max_0p75v_85c.db
	lappend target_library sch300mcpp64_cln07ff41001_base_lvt_c8_tt_typical_max_0p75v_85c.db
	lappend target_library sch300mcpp64_cln07ff41001_base_ulvt_c8_tt_typical_max_0p75v_85c.db
set synthetic_library [list dw_foundation.sldb]
set link_library [concat  [concat  * $target_library] $synthetic_library]
	lappend link_library RF_SP_512x38_M2B1S1_tt_typical_0p75v_0p75v_85c.db
	lappend link_library RF_SP_512x128_M2B1S2_tt_typical_0p75v_0p75v_85c.db
	lappend link_library RF_SP_128x108_M2B1S2_tt_typical_0p75v_0p75v_85c.db
	lappend link_library RF_2P_128x256_M1B2S2_tt_0p75v_0p75v_85c.db
	lappend link_library RF_SP_2048x132_M4B2S2_tt_typical_0p75v_0p75v_85c.db
	lappend link_library RF_SP_8192x32_M16B2S2_tt_typical_0p75v_0p75v_85c.db
	lappend link_library SRAM_SP_HDE_8192x128_M4B8S2_tt_0p75v_0p75v_85c.db
	lappend link_library RF_2P_1024x66_M4B4S2_tt_0p75v_0p75v_85c.db
	lappend link_library RF_SP_1024x96_M2B2S2_tt_typical_0p75v_0p75v_85c.db
	lappend link_library RF_SP_4096x64_M8B2S2_tt_typical_0p75v_0p75v_85c.db
	lappend link_library SRAM_SP_HDE_8192x144_M4B8S2_tt_0p75v_0p75v_85c.db
	lappend link_library RF_2P_64x206_M1B1S2_tt_0p75v_0p75v_85c.db
	lappend link_library RF_2P_128x208_M1B2S2_tt_0p75v_0p75v_85c.db
	lappend link_library SRAM_SP_HDE_16384x36_M16B4S2_tt_0p75v_0p75v_85c.db
	lappend link_library RF_2P_64x55_M2B2S1_tt_0p75v_0p75v_85c.db
	lappend link_library RF_2P_64x64_M1B1S1_tt_0p75v_0p75v_85c.db
	lappend link_library RF_SP_128x64_M2B1S1_tt_typical_0p75v_0p75v_85c.db
	lappend link_library RF_SP_32x40_M2B1S1_tt_typical_0p75v_0p75v_85c.db
	lappend link_library RF_SP_128x38_M2B1S1_tt_typical_0p75v_0p75v_85c.db
	lappend link_library RF_SP_64x112_M2B1S2_tt_typical_0p75v_0p75v_85c.db
	lappend link_library RF_SP_64x128_M2B1S2_tt_typical_0p75v_0p75v_85c.db
	lappend link_library RF_SP_128x128_M2B1S2_tt_typical_0p75v_0p75v_85c.db
	lappend link_library RF_SP_128x29_M4B1S1_tt_typical_0p75v_0p75v_85c.db
	lappend link_library RF_SP_64x64_M2B1S1_tt_typical_0p75v_0p75v_85c.db
	lappend link_library RF_SP_32x106_M2B1S2_tt_typical_0p75v_0p75v_85c.db
	lappend link_library RF_SP_64x104_M2B1S2_tt_typical_0p75v_0p75v_85c.db
	lappend link_library SRAM_SP_HDE_512x132_M2B4S2_tt_0p75v_0p75v_85c.db
	lappend link_library SRAM_SP_HDE_2048x128_M2B4S2_tt_0p75v_0p75v_85c.db
	lappend link_library SRAM_SP_HDE_2048x32_M2B4S2_tt_0p75v_0p75v_85c.db
	lappend link_library SRAM_SP_HDE_2048x92_M2B4S2_tt_0p75v_0p75v_85c.db
	lappend link_library SRAM_SP_HDE_8192x64_M4B8S2_tt_0p75v_0p75v_85c.db
	lappend link_library SRAM_SP_HDE_32768x36_M16B8S2_tt_0p75v_0p75v_85c.db
	lappend link_library SRAM_SP_HDE_512x100_M2B4S2_tt_0p75v_0p75v_85c.db
	lappend link_library RF_SP_1024x66_M2B2S2_tt_typical_0p75v_0p75v_85c.db
	lappend link_library RF_SP_256x132_M2B1S2_tt_typical_0p75v_0p75v_85c.db
	lappend link_library RF_SP_32x88_M2B1S2_tt_typical_0p75v_0p75v_85c.db
	lappend link_library RF_SP_32x94_M2B1S2_tt_typical_0p75v_0p75v_85c.db

set reference_libraries ""
    lappend reference_libraries /technos/ARM7FF/standardCells/sch300mcpp64_base_svt_c11/r14p0/lef/sch300mcpp64_cln07ff41001_base_svt_c11.lef
    lappend reference_libraries /technos/ARM7FF/standardCells/sch300mcpp64_base_lvt_c11/r14p0/lef/sch300mcpp64_cln07ff41001_base_lvt_c11.lef
    lappend reference_libraries /technos/ARM7FF/standardCells/sch300mcpp64_base_ulvt_c11/r14p0/lef/sch300mcpp64_cln07ff41001_base_ulvt_c11.lef
    lappend reference_libraries /technos/ARM7FF/standardCells/sch300mcpp64_base_svt_c8/r14p0/lef/sch300mcpp64_cln07ff41001_base_svt_c8.lef
    lappend reference_libraries /technos/ARM7FF/standardCells/sch300mcpp64_base_lvt_c8/r14p0/lef/sch300mcpp64_cln07ff41001_base_lvt_c8.lef
    lappend reference_libraries /technos/ARM7FF/standardCells/sch300mcpp64_base_ulvt_c8/r14p0/lef/sch300mcpp64_cln07ff41001_base_ulvt_c8.lef
    lappend reference_libraries $macros_path/RF_SP_512x38_M2B1S1.lef
    lappend reference_libraries $macros_path/RF_SP_512x128_M2B1S2.lef
    lappend reference_libraries $macros_path/RF_SP_128x108_M2B1S2.lef
    lappend reference_libraries $macros_path/RF_2P_128x256_M1B2S2.lef
    lappend reference_libraries $macros_path/RF_SP_2048x132_M4B2S2.lef
    lappend reference_libraries $macros_path/RF_SP_8192x32_M16B2S2.lef
    lappend reference_libraries $macros_path/SRAM_SP_HDE_8192x128_M4B8S2.lef
    lappend reference_libraries $macros_path/RF_2P_1024x66_M4B4S2.lef
    lappend reference_libraries $macros_path/RF_SP_1024x96_M2B2S2.lef
    lappend reference_libraries $macros_path/RF_SP_4096x64_M8B2S2.lef
    lappend reference_libraries $macros_path/SRAM_SP_HDE_8192x144_M4B8S2.lef
    lappend reference_libraries $macros_path/RF_2P_64x206_M1B1S2.lef
    lappend reference_libraries $macros_path/RF_2P_128x208_M1B2S2.lef
    lappend reference_libraries $macros_path/SRAM_SP_HDE_16384x36_M16B4S2.lef
    lappend reference_libraries $macros_path/RF_2P_64x55_M2B2S1.lef
    lappend reference_libraries $macros_path/RF_2P_64x64_M1B1S1.lef
    lappend reference_libraries $macros_path/RF_SP_128x64_M2B1S1.lef
    lappend reference_libraries $macros_path/RF_SP_32x40_M2B1S1.lef
    lappend reference_libraries $macros_path/RF_SP_128x38_M2B1S1.lef
    lappend reference_libraries $macros_path/RF_SP_64x112_M2B1S2.lef
    lappend reference_libraries $macros_path/RF_SP_64x128_M2B1S2.lef
    lappend reference_libraries $macros_path/RF_SP_128x128_M2B1S2.lef
    lappend reference_libraries $macros_path/RF_SP_128x29_M4B1S1.lef
    lappend reference_libraries $macros_path/RF_SP_64x64_M2B1S1.lef
    lappend reference_libraries $macros_path/RF_SP_32x106_M2B1S2.lef
    lappend reference_libraries $macros_path/RF_SP_64x104_M2B1S2.lef
    lappend reference_libraries $macros_path/SRAM_SP_HDE_512x132_M2B4S2.lef
    lappend reference_libraries $macros_path/SRAM_SP_HDE_2048x128_M2B4S2.lef
    lappend reference_libraries $macros_path/SRAM_SP_HDE_2048x32_M2B4S2.lef
    lappend reference_libraries $macros_path/SRAM_SP_HDE_2048x92_M2B4S2.lef
    lappend reference_libraries $macros_path/SRAM_SP_HDE_8192x64_M4B8S2.lef
    lappend reference_libraries $macros_path/SRAM_SP_HDE_32768x36_M16B8S2.lef
    lappend reference_libraries $macros_path/SRAM_SP_HDE_512x100_M2B4S2.lef
    lappend reference_libraries $macros_path/RF_SP_1024x66_M2B2S2.lef
    lappend reference_libraries $macros_path/RF_SP_256x132_M2B1S2.lef
    lappend reference_libraries $macros_path/RF_SP_32x88_M2B1S2.lef
    lappend reference_libraries $macros_path/RF_SP_32x94_M2B1S2.lef

set TLUPLUS_TYP_FILE /technos/ARM7FF/PDK/synopsys_tluplus/1p15m_1x1xa1ya5y2yy2yx2r/typical.tluplus
set TLUPLUS_MAX_FILE /technos/ARM7FF/PDK/synopsys_tluplus/1p15m_1x1xa1ya5y2yy2yx2r/rcbest.tluplus
set TLUPLUS_MIN_FILE /technos/ARM7FF/PDK/synopsys_tluplus/1p15m_1x1xa1ya5y2yy2yx2r/rcworst.tluplus
set ITFMAP_FILE /technos/ARM7FF/PDK/synopsys_tluplus/1p15m_1x1xa1ya5y2yy2yx2r/tluplus.map
set TECH_F "/technos/ARM7FF/PDK/ndm/1p15m_1x1xa1ya5y2yy2yx2r/sch300mcpp64_tech.tf"

create_lib -technology $TECH_F -ref_libs $reference_libraries $DESIGN.dlib

########################################
## SETUP for LOG-FILE and APP_OPTIONS ##
########################################
set sh_output_log_file "3_fc_log_file.log"
if {![file exists 0_work_files]} {file mkdir 0_work_files }
set_host_options -max_cores 8
set hdlin_sv_ieee_assignment_patterns 2

set_app_options -name hdlin.hdl_library.default_dirname -value ./0_HDL_LIBRARIES
set_app_options -name hdlin.elaborate.preserve_sequential -value "all"

###########################
## ANALYZE and ELABORATE ##
###########################
analyze -format sverilog -vcs " -f $RTL_filelist"

elaborate ${DESIGN}

set_top_module ${DESIGN}

exit

