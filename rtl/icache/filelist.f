// Simulation / FPGA / ASIC memory library
rtl/memory_library/include/bist_define.h
-F rtl/memory_library/filelist.f

// iCache
+incdir+./includes/
./includes/sargantana_icache_pkg.sv
./rtl/sargantana_cleaning_module.sv
./rtl/sargantana_icache_memory/rtl/sargantana_idata_memory.sv
./rtl/sargantana_icache_memory/rtl/sargantana_itag_memory_sram.sv
./rtl/sargantana_icache_memory/rtl/sargantana_top_memory.sv
./rtl/sargantana_icache_memory/rtl/sargantana_icache_way.sv
./rtl/sargantana_icache_tzc.sv
./rtl/sargantana_icache_lfsr.sv
./rtl/sargantana_icache_checker.sv
./rtl/sargantana_icache_ctrl/rtl/sargantana_icache_ctrl.sv
./rtl/sargantana_icache_tzc_idx.sv
./rtl/sargantana_icache_ff.sv
./rtl/sargantana_icache_replace_unit.sv
./rtl/sargantana_top_icache.sv
./rtl/wrapper_sargantana_top_icache.sv
