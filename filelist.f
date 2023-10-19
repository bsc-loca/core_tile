../ariane/corev_apu/riscv-dbg/src/dm_pkg.sv
../ariane/corev_apu/axi/src/axi_pkg.sv
./includes/ariane_axi_pkg.sv

-F ./rtl/core/sargantana/filelist.f
./rtl/dcache/rtl/src/target/generic/hpdcache_params_pkg.sv
-f ./rtl/dcache/rtl/hpdcache.Flist
-F ./rtl/icache/filelist.f
-F ./rtl/mmu/filelist.f
+incdir+./includes
+incdir+../ariane/corev_apu/register_interface/include/
./includes/sargantana_hpdc_pkg.sv
./includes/wt_cache_pkg.sv

// Should this be in the HPDC's flist?
./rtl/dcache/rtl/src/common/hpdcache_fifo_reg_initialized.sv
./rtl/dcache/rtl/src/utils/hpdcache_l15_req_arbiter.sv
./rtl/dcache/rtl/src/utils/hpdcache_l15_resp_demux.sv


./rtl/interface_dcache/rtl/dcache_interface.sv
./rtl/interface_icache/rtl/icache_interface.sv
./rtl/interface_icache/rtl/nc_icache_buffer.sv
./rtl/top_tile.sv

./fpga/common/rtl/bootrom.sv
./rtl/dcache/rtl/src/target/cinco-ranch/hpdcache_to_l15.sv
./rtl/dcache/rtl/src/target/cinco-ranch/hpdcache_subsystem_l15_adapter.sv
./rtl/drac_openpiton_wrapper.sv

./rtl/riscv_peripherals.sv
./rtl/rv_plic/rtl/rv_plic_target.sv
./rtl/rv_plic/rtl/rv_plic_gateway.sv
./rtl/rv_plic/rtl/plic_regmap.sv
./rtl/rv_plic/rtl/plic_top.sv

./rtl/clint.sv
../ariane/corev_apu/clint/axi_lite_interface.sv
../ariane/core/include/axi_intf.sv
../ariane/corev_apu/axi_mem_if/src/axi2mem.sv
../ariane/common/submodules/common_cells/src/cdc_2phase.sv
../ariane/corev_apu/riscv-dbg/debug_rom/debug_rom.sv
../ariane/corev_apu/riscv-dbg/src/dm_csrs.sv
../ariane/corev_apu/riscv-dbg/src/dm_mem.sv
../ariane/corev_apu/riscv-dbg/src/dm_top.sv
../ariane/corev_apu/riscv-dbg/src/dmi_cdc.sv
../ariane/corev_apu/riscv-dbg/src/dmi_jtag.sv
../ariane/corev_apu/riscv-dbg/src/dm_sba.sv
../ariane/corev_apu/riscv-dbg/src/dmi_jtag_tap.sv
../ariane/corev_apu/src/tech_cells_generic/src/deprecated/cluster_clk_cells.sv
../ariane/corev_apu/src/tech_cells_generic/src/deprecated/pulp_clk_cells.sv
../ariane/corev_apu/src/tech_cells_generic/src/rtl/tc_clk.sv
../ariane/common/submodules/common_cells/src/deprecated/fifo_v2.sv
../ariane/corev_apu/riscv-dbg/debug_rom/debug_rom_one_scratch.sv
