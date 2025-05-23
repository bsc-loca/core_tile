// Standalone Config
-F ../../standalone_config.f
-F ../../simulator/bsc-dm/filelist.f

// HPDC Memories
../../rtl/dcache/rtl/src/common/macros/behav/hpdcache_sram_1rw.sv
../../rtl/dcache/rtl/src/common/macros/behav/hpdcache_sram_wbyteenable_1rw.sv
../../rtl/dcache/rtl/src/common/macros/behav/hpdcache_sram_wmask_1rw.sv

// Core Tile
-F ../../filelist.f

// HPDC Arbiters
../../rtl/dcache/rtl/src/utils/hpdcache_mem_req_read_arbiter.sv
../../rtl/dcache/rtl/src/utils/hpdcache_mem_req_write_arbiter.sv
../../rtl/dcache/rtl/src/utils/hpdcache_mem_resp_demux.sv

// Common Cells
+incdir+../../rtl/common_cells/include/
../../rtl/common_cells/include/common_cells/registers.svh
../../rtl/common_cells/include/common_cells/assertions.svh
../../rtl/common_cells/src/binary_to_gray.sv
../../rtl/common_cells/src/cb_filter_pkg.sv
../../rtl/common_cells/src/cc_onehot.sv
../../rtl/common_cells/src/cf_math_pkg.sv
../../rtl/common_cells/src/clk_int_div.sv
../../rtl/common_cells/src/delta_counter.sv
../../rtl/common_cells/src/ecc_pkg.sv
../../rtl/common_cells/src/edge_propagator_tx.sv
../../rtl/common_cells/src/exp_backoff.sv
../../rtl/common_cells/src/fifo_v3.sv
../../rtl/common_cells/src/gray_to_binary.sv
../../rtl/common_cells/src/isochronous_4phase_handshake.sv
../../rtl/common_cells/src/isochronous_spill_register.sv
../../rtl/common_cells/src/lfsr.sv
../../rtl/common_cells/src/lfsr_16bit.sv
../../rtl/common_cells/src/lfsr_8bit.sv
../../rtl/common_cells/src/mv_filter.sv
../../rtl/common_cells/src/onehot_to_bin.sv
../../rtl/common_cells/src/plru_tree.sv
../../rtl/common_cells/src/popcount.sv
../../rtl/common_cells/src/rr_arb_tree.sv
../../rtl/common_cells/src/rstgen_bypass.sv
../../rtl/common_cells/src/serial_deglitch.sv
../../rtl/common_cells/src/shift_reg.sv
../../rtl/common_cells/src/shift_reg_gated.sv
../../rtl/common_cells/src/spill_register_flushable.sv
../../rtl/common_cells/src/stream_demux.sv
../../rtl/common_cells/src/stream_filter.sv
../../rtl/common_cells/src/stream_fork.sv
../../rtl/common_cells/src/stream_intf.sv
../../rtl/common_cells/src/stream_join.sv
../../rtl/common_cells/src/stream_mux.sv
../../rtl/common_cells/src/stream_throttle.sv
../../rtl/common_cells/src/sub_per_hash.sv
../../rtl/common_cells/src/sync.sv
../../rtl/common_cells/src/sync_wedge.sv
../../rtl/common_cells/src/unread.sv
../../rtl/common_cells/src/read.sv
../../rtl/common_cells/src/cdc_reset_ctrlr_pkg.sv
../../rtl/common_cells/src/cdc_2phase.sv
../../rtl/common_cells/src/cdc_4phase.sv
../../rtl/common_cells/src/addr_decode.sv
../../rtl/common_cells/src/addr_decode_napot.sv
../../rtl/common_cells/src/cb_filter.sv
../../rtl/common_cells/src/cdc_fifo_2phase.sv
../../rtl/common_cells/src/counter.sv
../../rtl/common_cells/src/ecc_decode.sv
../../rtl/common_cells/src/ecc_encode.sv
../../rtl/common_cells/src/edge_detect.sv
../../rtl/common_cells/src/lzc.sv
../../rtl/common_cells/src/max_counter.sv
../../rtl/common_cells/src/rstgen.sv
../../rtl/common_cells/src/spill_register.sv
../../rtl/common_cells/src/stream_delay.sv
../../rtl/common_cells/src/stream_fifo.sv
../../rtl/common_cells/src/stream_fork_dynamic.sv
../../rtl/common_cells/src/clk_mux_glitch_free.sv
../../rtl/common_cells/src/cdc_reset_ctrlr.sv
../../rtl/common_cells/src/cdc_fifo_gray.sv
../../rtl/common_cells/src/fall_through_register.sv
../../rtl/common_cells/src/id_queue.sv
../../rtl/common_cells/src/stream_to_mem.sv
../../rtl/common_cells/src/stream_arbiter_flushable.sv
../../rtl/common_cells/src/stream_fifo_optimal_wrap.sv
../../rtl/common_cells/src/stream_register.sv
../../rtl/common_cells/src/stream_xbar.sv
../../rtl/common_cells/src/cdc_fifo_gray_clearable.sv
../../rtl/common_cells/src/cdc_2phase_clearable.sv
../../rtl/common_cells/src/mem_to_banks.sv
../../rtl/common_cells/src/stream_arbiter.sv
../../rtl/common_cells/src/stream_omega_net.sv

// AXI
+incdir+rtl/axi/include/
rtl/axi/include/axi/typedef.svh
rtl/axi/include/axi/assign.svh
rtl/axi/src/axi_pkg.sv
rtl/axi/src/axi_intf.sv
rtl/axi/src/axi_atop_filter.sv
rtl/axi/src/axi_burst_splitter.sv
rtl/axi/src/axi_bus_compare.sv
rtl/axi/src/axi_cdc_dst.sv
rtl/axi/src/axi_cdc_src.sv
rtl/axi/src/axi_cut.sv
rtl/axi/src/axi_delayer.sv
rtl/axi/src/axi_demux_simple.sv
rtl/axi/src/axi_dw_downsizer.sv
rtl/axi/src/axi_dw_upsizer.sv
rtl/axi/src/axi_fifo.sv
rtl/axi/src/axi_id_remap.sv
rtl/axi/src/axi_id_prepend.sv
rtl/axi/src/axi_isolate.sv
rtl/axi/src/axi_join.sv
rtl/axi/src/axi_lite_demux.sv
rtl/axi/src/axi_lite_dw_converter.sv
rtl/axi/src/axi_lite_from_mem.sv
rtl/axi/src/axi_lite_join.sv
rtl/axi/src/axi_lite_lfsr.sv
rtl/axi/src/axi_lite_mailbox.sv
rtl/axi/src/axi_lite_mux.sv
rtl/axi/src/axi_lite_regs.sv
rtl/axi/src/axi_lite_to_apb.sv
rtl/axi/src/axi_lite_to_axi.sv
rtl/axi/src/axi_modify_address.sv
rtl/axi/src/axi_mux.sv
rtl/axi/src/axi_rw_join.sv
rtl/axi/src/axi_rw_split.sv
rtl/axi/src/axi_serializer.sv
rtl/axi/src/axi_slave_compare.sv
rtl/axi/src/axi_throttle.sv
rtl/axi/src/axi_to_detailed_mem.sv
rtl/axi/src/axi_cdc.sv
rtl/axi/src/axi_demux.sv
rtl/axi/src/axi_err_slv.sv
rtl/axi/src/axi_dw_converter.sv
rtl/axi/src/axi_from_mem.sv
rtl/axi/src/axi_id_serialize.sv
rtl/axi/src/axi_lfsr.sv
rtl/axi/src/axi_multicut.sv
rtl/axi/src/axi_to_axi_lite.sv
rtl/axi/src/axi_to_mem.sv
rtl/axi/src/axi_iw_converter.sv
rtl/axi/src/axi_lite_xbar.sv
rtl/axi/src/axi_xbar.sv
rtl/axi/src/axi_to_mem_banked.sv
rtl/axi/src/axi_to_mem_interleaved.sv
rtl/axi/src/axi_to_mem_split.sv
rtl/axi/src/axi_xp.sv
rtl/axi_riscv_atomics/src/axi_res_tbl.sv
rtl/axi_riscv_atomics/src/axi_riscv_amos_alu.sv
rtl/axi_riscv_atomics/src/axi_riscv_amos.sv
rtl/axi_riscv_atomics/src/axi_riscv_amos_wrap.sv
rtl/axi_riscv_atomics/src/axi_riscv_lrsc.sv
rtl/axi_riscv_atomics/src/axi_riscv_lrsc_wrap.sv
rtl/axi_riscv_atomics/src/axi_riscv_atomics.sv
rtl/axi_riscv_atomics/src/axi_riscv_atomics_wrap.sv
rtl/axi_riscv_atomics/src/axi_riscv_atomics_structs.sv
includes/fpga_pkg.sv

// HPDC AXI Adapters
../../rtl/dcache/rtl/src/utils/hpdcache_mem_to_axi_read.sv
../../rtl/dcache/rtl/src/utils/hpdcache_mem_to_axi_write.sv

// Common FPGA Modules
rtl/axi_arbiter.sv
rtl/bootrom.sv
rtl/axi_wrapper.sv
rtl/axi_timer.sv
