`include "hpdcache_typedef.svh"

module sargantana_subtile
    import drac_pkg::*, sargantana_icache_pkg::*, mmu_pkg::*, hpdcache_pkg::*;
#(
    parameter drac_pkg::drac_cfg_t DracCfg     = drac_pkg::DracDefaultConfig,

    parameter int unsigned NREQUESTERS = 2,
    parameter int unsigned MMU_REQUESTER_SID = 0,
    parameter int unsigned CORE_REQUESTER_SID = 0,

    parameter int unsigned ICACHELINE_SIZE = 0,
    parameter int unsigned ICACHE_INDEX_SIZE = 0,
    parameter int unsigned ICACHE_PPN_SIZE = 0,
    parameter int unsigned ICACHE_VPN_SIZE = 0,

    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_rsp_t = logic
)(
//------------------------------------------------------------------------------------
// ORIGINAL INPUTS OF LAGARTO 
//------------------------------------------------------------------------------------
    input logic                 clk_i,
    input logic                 rstn_i,
    input logic                 soft_rstn_i,
    input addr_t                reset_addr_i,
    input logic [63:0]          core_id_i,

//------------------------------------------------------------------------------------
// Chip-specific connections
//------------------------------------------------------------------------------------
    `ifdef INTEL_FSCAN_CTECH
    input logic                 fscan_rstbypen,//AK
    `endif // INTEL_FSCAN_CTECH

    `ifdef PITON_CINCORANCH
    input logic [1:0]           boot_main_id_i,
    `endif  // Custom for CincoRanch

    `ifdef EXTERNAL_HPM_EVENT_NUM
    input logic [`EXTERNAL_HPM_EVENT_NUM-1: 0] external_hpm_i,
    `endif

//------------------------------------------------------------------------------------
// DEBUG RING SIGNALS INPUT
//------------------------------------------------------------------------------------
    input debug_contr_in_t      debug_contr_i,
    input debug_reg_in_t        debug_reg_i,

//------------------------------------------------------------------------------------
// I-CACHE INTERFACE
//------------------------------------------------------------------------------------

    // Core interface
    // From Core
    output logic                            icache_flush_o,
    output logic                            icache_req_valid_o,
    output logic                            icache_req_kill_o,
    output logic [ICACHE_INDEX_SIZE-1:0]    icache_req_idx_o,
    output logic [ICACHE_VPN_SIZE-1:0]      icache_req_vpn_o,

    // To Core
    input  logic                            icache_resp_ready_i,
    input  logic                            icache_resp_valid_i,
    input  logic [ICACHELINE_SIZE-1:0]      icache_resp_data_i,
    input  logic                            icache_resp_xcpt_i,

    // iTLB interface
    output logic                            icache_tlb_resp_miss_o,
    output logic                            icache_tlb_resp_ptw_v_o,
    output logic [ICACHE_PPN_SIZE-1:0]      icache_tlb_resp_ppn_o,
    output logic                            icache_tlb_resp_xcpt_o,

    //- To MMU
    input  logic                            icache_tlb_req_valid_i,
    input  logic [ICACHE_VPN_SIZE-1:0]      icache_tlb_req_vpn_i,

    output logic                            icache_en_translation_o,
    output logic                            icache_invalidate_o,

//----------------------------------------------------------------------------------
// HPDCache INTERFACE
//----------------------------------------------------------------------------------

    output logic           dcache_req_valid_o   [NREQUESTERS],
    input  logic           dcache_req_ready_i   [NREQUESTERS],
    output hpdcache_req_t  dcache_req_o         [NREQUESTERS],
    output logic           dcache_req_abort_o   [NREQUESTERS],
    output hpdcache_tag_t  dcache_req_tag_o     [NREQUESTERS],
    output hpdcache_pma_t  dcache_req_pma_o     [NREQUESTERS],

    input  logic           dcache_rsp_valid_i [NREQUESTERS],
    input  hpdcache_rsp_t  dcache_rsp_i       [NREQUESTERS],
    input  logic           wbuf_empty_i,

//-----------------------------------------------------------------------------------
// DEBUGGING MODULE SIGNALS
//-----------------------------------------------------------------------------------
    output debug_contr_out_t    debug_contr_o,
    output debug_reg_out_t      debug_reg_o,

// VISA
    output visa_signals_t       visa_o,

//-----------------------------------------------------------------------------
// PMU INTERFACE
//-----------------------------------------------------------------------------
    input  pmu_interface_t      pmu_interface_i,

`ifdef CONF_SARGANTANA_ENABLE_PCR
//-----------------------------------------------------------------------------
// PCR
//-----------------------------------------------------------------------------
    //PCR req inputs
    input  logic                pcr_req_ready_i,    // ready bit of the pcr

    //PCR resp inputs
    input  logic                pcr_resp_valid_i,   // ready bit of the pcr
    input  logic [63:0]         pcr_resp_data_i,    // read data from performance counter module
    input  logic [63:0]         pcr_resp_core_id_i, // core id of the tile that the date is sended

    //PCR outputs request
    output logic                pcr_req_valid_o,    // valid bit to make a pcr request
    output logic  [11:0]        pcr_req_addr_o,     // read/write address to performance counter module (up to 29 aux counters possible in riscv encoding.h)
    output logic  [63:0]        pcr_req_data_o,     // write data to performance counter module
    output logic  [2:0]         pcr_req_we_o,       // Cmd of the petition
    output logic  [63:0]        pcr_req_core_id_o   // core id of the tile
`endif // CONF_SARGANTANA_ENABLE_PCR

//-----------------------------------------------------------------------------
// INTERRUPTS
//-----------------------------------------------------------------------------
    input  logic                 time_irq_i, // timer interrupt
    input  logic [1:0]           irq_i,      // external interrupt in
    input  logic                 soft_irq_i, // software interrupt
    input  logic [63:0]          time_i     // time passed since the core is reset
);

// Response Interface icache to datapath
resp_icache_cpu_t resp_icache_interface_datapath;

// Request Datapath to Icache interface
req_cpu_icache_t req_datapath_icache_interface;

// Response Interface dcache to datapath
resp_dcache_cpu_t resp_dcache_interface_datapath;

// Request Datapath to Dcache interface
req_cpu_dcache_t req_datapath_dcache_interface;

// Response CSR Interface to datapath
logic [1:0] priv_lvl;
logic en_translation;

// *** Memory Management Unit ***

// ptw -> dmem
ptw_dmem_comm_t ptw_dmem_comm;
dmem_ptw_comm_t dmem_ptw_comm;

// iTLB interface
cache_tlb_comm_t                 icache_itlb_comm;
tlb_cache_comm_t                 itlb_icache_comm;

assign icache_itlb_comm.req.valid       = icache_tlb_req_valid_i;
assign icache_itlb_comm.req.asid        = 1'b0;
assign icache_itlb_comm.req.vpn         = icache_tlb_req_vpn_i;
assign icache_itlb_comm.req.passthrough = 1'b0;
assign icache_itlb_comm.req.instruction = 1'b1;
assign icache_itlb_comm.req.store       = 1'b0;
assign icache_itlb_comm.priv_lvl        = priv_lvl;
assign icache_itlb_comm.vm_enable       = en_translation;

assign icache_tlb_resp_miss_o  = itlb_icache_comm.resp.miss;
assign icache_tlb_resp_ptw_v_o = itlb_icache_comm.tlb_ready;
assign icache_tlb_resp_ppn_o   = itlb_icache_comm.resp.ppn[ICACHE_PPN_SIZE-1:0];
assign icache_tlb_resp_xcpt_o  = itlb_icache_comm.resp.xcpt.fetch;

// *** Core Instance ***

top_drac #(
    .DracCfg(DracCfg)
) sargantana_inst (
    .clk_i,
    .rstn_i,
    .soft_rstn_i,
    .reset_addr_i,
    .core_id_i,

    `ifdef INTEL_FSCAN_CTECH
    .fscan_rstbypen,//AK
    `endif // INTEL_FSCAN_CTECH
    `ifdef PITON_CINCORANCH
    .boot_main_id_i,
    `endif  // Custom for CincoRanch
    `ifdef EXTERNAL_HPM_EVENT_NUM
    .external_hpm_i,
    `endif

    // iCache Interface
    .req_icache_ready_i(req_icache_ready),
    .req_cpu_icache_o(req_datapath_icache_interface),
    .en_translation_o(en_translation),
    .priv_lvl_o(priv_lvl),
    .resp_icache_cpu_i(resp_icache_interface_datapath),

    // dCache Interface
    .resp_dcache_cpu_i(resp_dcache_interface_datapath),
    .req_cpu_dcache_o(req_datapath_dcache_interface),

    // iTLB Interface
    .icache_itlb_comm_i(icache_itlb_comm),
    .itlb_icache_comm_o(itlb_icache_comm),

    // PTW - Memory Interface
    .ptw_dmem_comm_o(ptw_dmem_comm),
    .dmem_ptw_comm_i(dmem_ptw_comm),

    // Debug Module
    .visa_o,
    .debug_contr_i,
    .debug_reg_i,

    .debug_contr_o,
    .debug_reg_o,

    // PMU Interface
    .pmu_interface_i,

`ifdef CONF_SARGANTANA_ENABLE_PCR
    // PCR
    .pcr_req_ready_i,    // ready bit of the pcr
    .pcr_resp_valid_i,   // ready bit of the pcr
    .pcr_resp_data_i,    // read data from performance counter module
    .pcr_resp_core_id_i, // core id of the tile that the date is sended
    .pcr_req_valid_o,    // valid bit to make a pcr request
    .pcr_req_addr_o,     // read/write address to performance counter module (up to 29 aux counters possible in riscv encoding.h)h
    .pcr_req_data_o,     // write data to performance counter module
    .pcr_req_we_o,       // Cmd of the petition
    .pcr_req_core_id_o,   // core id of the tile
`endif // CONF_SARGANTANA_ENABLE_PCR

    // Interrupts
    .time_irq_i,
    .irq_i,
    .soft_irq_i,
    .time_i
);

// *** iCache Interface ***

icache_interface icache_interface_inst(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // Inputs ICache
    .icache_resp_datablock_i    ( icache_resp_data_i  ),
    .icache_resp_valid_i        ( icache_resp_valid_i ),
    .icache_req_ready_i         ( icache_resp_ready_i ),
    .tlb_resp_xcp_if_i          ( icache_resp_xcpt_i  ),
    .en_translation_i           ( en_translation      ),

    // Outputs ICache
    .icache_invalidate_o    ( icache_flush_o     ),
    .icache_req_bits_idx_o  ( icache_req_idx_o   ),
    .icache_req_kill_o      ( icache_req_kill_o  ),
    .icache_req_valid_o     ( icache_req_valid_o ),
    .icache_req_bits_vpn_o  ( icache_req_vpn_o   ),

    // Fetch stage interface - Request packet from fetch_stage
    .req_fetch_icache_i   (req_datapath_icache_interface  ),

    // Fetch stage interface - Response packet icache to fetch
    .resp_icache_fetch_o  (resp_icache_interface_datapath ),
    .req_fetch_ready_o(req_icache_ready)
);

assign icache_en_translation_o = en_translation;

// *** dCache Interface ***

dcache_interface #(
    .DracCfg(DracCfg),
    .SID(CORE_REQUESTER_SID),
    .hpdcache_req_t(hpdcache_req_t),
    .hpdcache_tag_t(hpdcache_tag_t),
    .hpdcache_rsp_t(hpdcache_rsp_t)
) dcache_interface_inst(
    .clk_i,
    .rstn_i,

    // CPU Interface
    .req_cpu_dcache_i(req_datapath_dcache_interface),
    .resp_dcache_cpu_o(resp_dcache_interface_datapath),

    // dCache Interface
    .dcache_ready_i(dcache_req_ready_i[CORE_REQUESTER_SID]),
    .dcache_valid_i(dcache_rsp_valid_i[CORE_REQUESTER_SID]),
    .core_req_valid_o(dcache_req_valid_o[CORE_REQUESTER_SID]),
    .req_dcache_o(dcache_req_o[CORE_REQUESTER_SID]),
    .req_dcache_abort_o(dcache_req_abort_o[CORE_REQUESTER_SID]),
    .req_dcache_tag_o(dcache_req_tag_o[CORE_REQUESTER_SID]),
    .req_dcache_pma_o(dcache_req_pma_o[CORE_REQUESTER_SID]),
    .rsp_dcache_i(dcache_rsp_i[CORE_REQUESTER_SID]),
    .wbuf_empty_i
);

// *** MMU Interface ***

bsc_mmu_hpdc_adapter #(
    .SID(MMU_REQUESTER_SID),

    .hpdcache_req_t(hpdcache_req_t),
    .hpdcache_tag_t(hpdcache_tag_t),
    .hpdcache_rsp_t(hpdcache_rsp_t)
) mmu_hpdc_adapter_inst (
    // PTW interface
    .dmem_ptw_comm_o(dmem_ptw_comm),
    .ptw_dmem_comm_i(ptw_dmem_comm),

    // dCache Interface
    .req_dcache_ready_i(dcache_req_ready_i[MMU_REQUESTER_SID]),
    .req_dcache_valid_o(dcache_req_valid_o[MMU_REQUESTER_SID]),
    .req_dcache_o(dcache_req_o[MMU_REQUESTER_SID]),
    .req_dcache_abort_o(dcache_req_abort_o[MMU_REQUESTER_SID]),
    .req_dcache_tag_o(dcache_req_tag_o[MMU_REQUESTER_SID]),
    .req_dcache_pma_o(dcache_req_pma_o[MMU_REQUESTER_SID]),
    .rsp_dcache_valid_i(dcache_rsp_valid_i[MMU_REQUESTER_SID]),
    .rsp_dcache_i(dcache_rsp_i[MMU_REQUESTER_SID])
);

endmodule
