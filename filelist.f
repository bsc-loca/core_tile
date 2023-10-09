-F ./rtl/core/sargantana/filelist.f
./rtl/dcache/rtl/src/target/generic/hpdcache_params_pkg.sv
-f ./rtl/dcache/rtl/hpdcache.Flist
-F ./rtl/icache/filelist.f
-F ./rtl/mmu/filelist.f
+incdir+./includes
./includes/sargantana_hpdc_pkg.sv
./includes/wt_cache_pkg.sv

// Should this be in the HPDC's flist?
./rtl/dcache/rtl/src/common/hpdcache_fifo_reg_initialized.sv
./rtl/dcache/rtl/src/utils/hpdcache_l15_req_arbiter.sv
./rtl/dcache/rtl/src/utils/hpdcache_l15_resp_demux.sv

./rtl/interface_dcache/rtl/dcache_interface.sv
./rtl/interface_icache/rtl/icache_interface.sv
./rtl/top_tile.sv

./fpga/common/rtl/bootrom.sv
./rtl/dcache/rtl/src/target/cinco-ranch/hpdcache_to_l15.sv
./rtl/dcache/rtl/src/target/cinco-ranch/hpdcache_subsystem_l15_adapter.sv
./rtl/drac_openpiton_wrapper.sv
