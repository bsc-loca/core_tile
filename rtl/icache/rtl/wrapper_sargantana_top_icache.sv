/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : top_icache.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Neiel I. Leyva Santes. 
 * Email(s)       : neiel.leyva@bsc.es
 * References     : 
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Commit | Description
 *  ******     | Neiel L.  |        | 
 * -----------------------------------------------
 */



module wrapper_sargantana_top_icache 
    import sargantana_icache_pkg::*;
#(
    parameter logic KILL_RESP   = 1'b1,
    parameter logic LINES_256   = 1'b0
)
(
    `ifdef INTEL_PHYSICAL_MEM_CTRL
    input wire [27:0]     hduspsr_mem_ctrl,
    `endif
    input  logic          clk_i              ,
    input  logic          rstn_i             ,
    input  logic          flush_i            , 
    // Core interface                           
    input  ireq_i_t       lagarto_ireq_i     , //- From Lagarto.
    output iresp_o_t      icache_resp_o      , //- To Lagarto.
    // MMU interface                         
    input  tresp_i_t      mmu_tresp_i        , //- From MMU.
    output treq_o_t       icache_treq_o      , //- To MMU.
    // iFill interface
    input  ifill_resp_i_t ifill_resp_i       , //- From upper levels.
    output ifill_req_o_t  icache_ifill_req_o , //- To upper levels. 

    // PMU
    output logic imiss_time_pmu_o            , 
    output logic imiss_kill_pmu_o           
);

sargantana_top_icache #(
    .KILL_RESP                  (KILL_RESP),
    .LINES_256                  (LINES_256),

    .ICACHE_MEM_BLOCK           (ICACHE_MEM_BLOCK),
    .PADDR_SIZE                 (drac_pkg::PHY_ADDR_SIZE),
    .ADDR_SIZE                  (drac_pkg::PHY_ADDR_SIZE),
    .IDX_BITS_SIZE              ($bits(drac_pkg::icache_idx_t)),
    .VPN_BITS_SIZE              ($bits(drac_pkg::icache_vpn_t)),
    .FETCH_WIDHT                (FETCH_WIDHT)
) icache (
    `ifdef INTEL_PHYSICAL_MEM_CTRL
    .hduspsr_mem_ctrl           (hduspsr_mem_ctrl),
    `endif
    .clk_i                      (clk_i),
    .rstn_i                     (rstn_i),
    .flush_i                    (flush_i),

    .lagarto_ireq_valid_i       (lagarto_ireq_i.valid),
    .lagarto_ireq_kill_i        (lagarto_ireq_i.kill),
    .lagarto_ireq_idx_i         (lagarto_ireq_i.idx),
    .lagarto_ireq_vpn_i         (lagarto_ireq_i.vpn),
    
    .icache_resp_ready_o        (icache_resp_o.ready),
    .icache_resp_valid_o        (icache_resp_o.valid),
    .icache_resp_data_o         (icache_resp_o.data),
    .icache_resp_vaddr_o        (icache_resp_o.vaddr),
    .icache_resp_xcpt_o         (icache_resp_o.xcpt),
    
    .mmu_tresp_miss_i           (mmu_tresp_i.miss),
    .mmu_tresp_ptw_v_i          (mmu_tresp_i.ptw_v),
    .mmu_tresp_ppn_i            (mmu_tresp_i.ppn),
    .mmu_tresp_xcpt_i           (mmu_tresp_i.xcpt),

    .icache_treq_valid_o        (icache_treq_o.valid),
    .icache_treq_vpn_o          (icache_treq_o.vpn),

    .ifill_resp_valid_i         (ifill_resp_i.valid),
    .ifill_resp_ack_i           (ifill_resp_i.ack),
    .ifill_resp_data_i          (ifill_resp_i.data),
    .ifill_resp_inv_valid_i     (ifill_resp_i.inv.valid),
    .ifill_resp_inv_paddr_i     (ifill_resp_i.inv.paddr),
    
    .icache_ifill_req_valid_o   (icache_ifill_req_o.valid),
    // .icache_ifill_req_way_o     (icache_ifill_req_o.way),
    .icache_ifill_req_paddr_o   (icache_ifill_req_o.paddr),

    .imiss_time_pmu_o           (imiss_time_pmu_o),
    .imiss_kill_pmu_o           (imiss_kill_pmu_o)
);


endmodule
