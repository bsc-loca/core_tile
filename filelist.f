-F ${TILE_TOP}/rtl/core/sargantana/filelist.f
${TILE_TOP}/rtl/dcache/rtl/src/target/cinco_ranch/cinco_ranch_hpdcache_params_pkg.sv
-f ${HPDCACHE_DIR}/rtl/hpdcache.Flist
${HPDCACHE_DIR}/rtl/src/common/macros/behav/hpdcache_sram_1rw.sv
${HPDCACHE_DIR}/rtl/src/common/macros/behav/hpdcache_sram_wbyteenable_1rw.sv
${HPDCACHE_DIR}/rtl/src/common/macros/behav/hpdcache_sram_wmask_1rw.sv
-F ${TILE_TOP}/rtl/icache/icache/filelist.f
${TILE_TOP}/rtl/icache/icache_dos/includes/drac_icache_pkg.sv
${TILE_TOP}/rtl/icache/icache_dos/includes/sargantana_vidriol_pkg.sv
-F ${TILE_TOP}/rtl/icache/icache_dos/filelist.f
+incdir+${TILE_TOP}/includes

${TILE_TOP}/rtl/interface_dcache/rtl/dcache_interface.sv
${TILE_TOP}/rtl/interface_icache/rtl/icache_interface.sv
${TILE_TOP}/rtl/interface_icache/rtl/nc_icache_buffer.sv
${TILE_TOP}/rtl/core/sargantana/rtl/mmu/rtl/dcache_adapters/bsc_mmu_hpdc_adapter.sv
${TILE_TOP}/rtl/sargantana_subtile.sv
${TILE_TOP}/rtl/top_tile.sv
