/* -----------------------------------------------
* Project Name   : DRAC
* File           : datapath.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Guillem Cabo Pitarch 
* Email(s)       : guillem.cabo@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Guillem.CP | 
*  0.2        | Arnau B.   | Split core into core and core_tile
* -----------------------------------------------
*/

`include "hpdcache_typedef.svh"

module top_tile
    import drac_pkg::*, sargantana_icache_pkg::*, mmu_pkg::*;
#(
    parameter drac_pkg::drac_cfg_t DracCfg     = drac_pkg::DracDefaultConfig,

    // HPDC Memory Interface Parameters
    parameter type hpdcache_mem_addr_t = logic [DracCfg.MemAddrWidth-1:0],
    parameter type hpdcache_mem_id_t = logic [DracCfg.MemIDWidth-1:0],
    parameter type hpdcache_mem_data_t = logic [DracCfg.MemDataWidth-1:0],
    parameter type hpdcache_mem_be_t = logic [DracCfg.MemDataWidth/8-1:0],
    parameter type hpdcache_mem_req_t =
        `HPDCACHE_DECL_MEM_REQ_T(hpdcache_mem_addr_t, hpdcache_mem_id_t),
    parameter type hpdcache_mem_resp_r_t =
        `HPDCACHE_DECL_MEM_RESP_R_T(hpdcache_mem_id_t, hpdcache_mem_data_t),
    parameter type hpdcache_mem_req_w_t =
        `HPDCACHE_DECL_MEM_REQ_W_T(hpdcache_mem_data_t, hpdcache_mem_be_t),
    parameter type hpdcache_mem_resp_w_t =
        `HPDCACHE_DECL_MEM_RESP_W_T(hpdcache_mem_id_t),
    parameter type hpdcache_nline_t = logic [PHY_ADDR_SIZE-$clog2(DracCfg.DCacheLineWidth / 8)-1:0]
)(
    `ifdef INTEL_PHYSICAL_MEM_CTRL
    input wire [27:0] hduspsr_mem_ctrl,
    input wire [27:0] uhdusplr_mem_ctrl,
    `endif
//------------------------------------------------------------------------------------
// ORIGINAL INPUTS OF LAGARTO 
//------------------------------------------------------------------------------------
    input logic                 clk_i,
    input logic                 rstn_i,
    input logic                 soft_rstn_i,
    `ifdef INTEL_FSCAN_CTECH
    input logic                 fscan_rstbypen,//AK
    `endif // INTEL_FSCAN_CTECH
    input addr_t                reset_addr_i,
    input logic [63:0]          core_id_i,
    `ifdef PITON_CINCORANCH
    input logic [1:0]           boot_main_id_i,
    `endif  // Custom for CincoRanch
    `ifdef EXTERNAL_HPM_EVENT_NUM
    input logic [`EXTERNAL_HPM_EVENT_NUM-1: 0]  external_hpm_i,
    `endif
 

//------------------------------------------------------------------------------------
// DEBUG RING SIGNALS INPUT
//------------------------------------------------------------------------------------    
    input logic    debug_contr_halt_req_i,
    input logic    debug_contr_resume_req_i,
    input logic    debug_contr_progbuf_req_i,
    input logic    debug_contr_halt_on_reset_i,

    input logic    debug_reg_rnm_read_en_i,
    input reg_t    debug_reg_rnm_read_reg_i,
    input logic    debug_reg_rf_en_i,
    input phreg_t  debug_reg_rf_preg_i,
    input logic    debug_reg_rf_we_i,
    input bus64_t  debug_reg_rf_wdata_i,

//------------------------------------------------------------------------------------
// I-CANCHE INPUT INTERFACE
//------------------------------------------------------------------------------------
    
    //- From L2
    input  logic                   io_mem_grant_valid,
    input  logic [511:0]           io_mem_grant_bits_data,
    input  logic [1:0]             io_mem_grant_bits_addr_beat,
    input  logic                   io_mem_grant_inval,
    input  logic [11:0]            io_mem_grant_inval_addr,
    

//----------------------------------------------------------------------------------
// D-CACHE  INTERFACE
//----------------------------------------------------------------------------------

    //      dCache Read interface
    input  logic                          mem_req_read_ready_i,
    output logic                          mem_req_read_valid_o,
    output hpdcache_mem_req_t             mem_req_read_o,

    output logic                          mem_resp_read_ready_o,
    input  logic                          mem_resp_read_valid_i,
    input  hpdcache_mem_resp_r_t          mem_resp_read_i,

    //      dCache Write interface
    input  logic                          mem_req_write_ready_i,
    output logic                          mem_req_write_valid_o,
    output hpdcache_mem_req_t             mem_req_write_o,

    input  logic                          mem_req_write_data_ready_i,
    output logic                          mem_req_write_data_valid_o,
    output hpdcache_mem_req_w_t           mem_req_write_data_o,

    output logic                          mem_resp_write_ready_o,
    input  logic                          mem_resp_write_valid_i,
    input  hpdcache_mem_resp_w_t          mem_resp_write_i,

`ifdef HPDCACHE_OPENPITON
    //      Invalidation interface
    input  logic                          mem_inval_valid_i,
    input  hpdcache_nline_t               mem_inval_i,
`endif

//-----------------------------------------------------------------------------------
// I-CACHE OUTPUT INTERFACE
//-----------------------------------------------------------------------------------

    //- To L2
    output logic                          io_mem_acquire_valid,
    output logic [PHY_ADDR_SIZE-1:0]      io_mem_acquire_bits_addr_block,

//-----------------------------------------------------------------------------------
// DEBUGGING MODULE SIGNALS
//-----------------------------------------------------------------------------------

    output logic   debug_contr_halt_ack_o,
    output logic   debug_contr_halted_o,
    output logic   debug_contr_resume_ack_o,
    output logic   debug_contr_running_o,
    output logic   debug_contr_progbuf_ack_o,
    output logic   debug_contr_parked_o,
    output logic   debug_contr_unavail_o,
    output logic   debug_contr_progbuf_xcpt_o,
    output logic   debug_contr_havereset_o,

    output phreg_t debug_reg_rnm_read_resp_o,
    output bus64_t debug_reg_rf_rdata_o,

    output visa_signals_t       visa_o,


//-----------------------------------------------------------------------------
// PMU INTERFACE
//-----------------------------------------------------------------------------
    input  logic                io_core_pmu_l2_hit_i        ,

//-----------------------------------------------------------------------------
// BOOTROM CONTROLER INTERFACE
//-----------------------------------------------------------------------------
    output logic [39:0]         brom_req_address_o  ,
    output logic                brom_req_valid_o    ,

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
    output logic  [63:0]        pcr_req_core_id_o,  // core id of the tile
`endif // CONF_SARGANTANA_ENABLE_PCR

//-----------------------------------------------------------------------------
// INTERRUPTS
//-----------------------------------------------------------------------------
    input  logic                time_irq_i, // timer interrupt
    input  logic [1:0]          irq_i,      // external interrupt in
    input  logic                soft_irq_i, // software interrupt
    input  logic [63:0]         time_i     // time passed since the core is reset

);

// PPN Size is address size - set bits - offset bits
localparam int unsigned ICACHE_NUM_SETS = 64;
localparam int unsigned ICACHE_INDEX_SIZE = $clog2(ICACHE_NUM_SETS) + $clog2(ICACHELINE_SIZE/8);
localparam int unsigned ICACHE_PPN_SIZE = PHY_VIRT_MAX_ADDR_SIZE - ICACHE_INDEX_SIZE;
localparam int unsigned ICACHE_VPN_SIZE = PHY_VIRT_MAX_ADDR_SIZE - ICACHE_INDEX_SIZE;

// *** dCache ***
parameter HPDCACHE_NREQUESTERS = 2; // Core + PTW

localparam hpdcache_pkg::hpdcache_user_cfg_t HPDcacheUserCfg = '{
    // 2 requesters: Core and MMU
    nRequesters: HPDCACHE_NREQUESTERS,
    // Address and word size as configured in drac_pkg
    paWidth: drac_pkg::PHY_ADDR_SIZE,
    wordWidth: riscv_pkg::XLEN,
    // Configure size, associativity and cacheline size via config parameter
    sets: DracCfg.DCacheNumSets,
    ways: DracCfg.DCacheNumWays,
    clWords: DracCfg.DCacheLineWidth / riscv_pkg::XLEN,
    // Configure the request to access the whole cacheline
    reqWords: DracCfg.DCacheLineWidth / riscv_pkg::XLEN,
    // Core is configured to support 7 bit IDs, currently hardcoded!
    reqTransIdWidth: 7,
    // Up to 8 requesters
    reqSrcIdWidth: 3,
    // Use Pseudo-LRU
    victimSel: hpdcache_pkg::HPDCACHE_VICTIM_PLRU,
    // Put two ways side-by-side on an SRAM line
    dataWaysPerRamWord: 2,
    // Put all the sets in the same SRAM (TODO: Confirm with Cesar)
    dataSetsPerRam: DracCfg.DCacheNumSets,
    // Use byte-enable SRAMs
    dataRamByteEnable: 1'b1,
    // Access the whole cacheline in a single cycle, for request & refills
    accessWords: DracCfg.DCacheLineWidth / riscv_pkg::XLEN,
    // Configure the MSHRs via the config parameter
    mshrSets: DracCfg.DCacheMSHRSets,
    mshrWays: DracCfg.DCacheMSHRWays,
    // Store 2 ways per SRAM line
    mshrWaysPerRamWord: 2,
    mshrSetsPerRam: DracCfg.DCacheMSHRSets,
    mshrRamByteEnable: 1'b1,
    // Use SRAMs for the MSHRs
    mshrUseRegbank: 0,
    // Bypass data to the core when refilling
    refillCoreRspFeedthrough: 1'b1,
    refillFifoDepth: 2,
    // Configure the write buffer entries via the config parameter
    wbufDirEntries: DracCfg.DCacheWBUFSize,
    wbufDataEntries: DracCfg.DCacheWBUFSize,
    // Have a whole cacheline in each write buffer entry.
    // Caution! It says words, but really it's the width of the core request!
    wbufWords: 1,
    wbufTimecntWidth: 3,
    // Number of replay table entries
    rtabEntries: 8,
    // Number of invalidation entries
    flushEntries: 4,
    flushFifoDepth: 2,
    // Memory interface parameters, configured via the config parameter
    memAddrWidth: DracCfg.MemAddrWidth,
    memIdWidth: DracCfg.MemIDWidth,
    memDataWidth: DracCfg.MemDataWidth,
    // Write-through or Write-back configuration, depending on config parameter
    // Only allows one or the other
    wtEn: DracCfg.DCacheWTNotWB ? 1'b1 : 1'b0,
    wbEn: DracCfg.DCacheWTNotWB ? 1'b0 : 1'b1
};

  localparam hpdcache_pkg::hpdcache_cfg_t HPDcacheCfg = hpdcache_pkg::hpdcacheBuildConfig(
      HPDcacheUserCfg
  );

  `HPDCACHE_TYPEDEF_REQ_ATTR_T(hpdcache_req_offset_t, hpdcache_data_word_t, hpdcache_data_be_t,
                               hpdcache_req_data_t, hpdcache_req_be_t, hpdcache_req_sid_t,
                               hpdcache_req_tid_t, hpdcache_tag_t, HPDcacheCfg);
  `HPDCACHE_TYPEDEF_REQ_T(hpdcache_req_t, hpdcache_req_offset_t, hpdcache_req_data_t,
                          hpdcache_req_be_t, hpdcache_req_sid_t, hpdcache_req_tid_t,
                          hpdcache_tag_t);
  `HPDCACHE_TYPEDEF_RSP_T(hpdcache_rsp_t, hpdcache_req_data_t, hpdcache_req_sid_t,
                          hpdcache_req_tid_t);

// iCache
logic                            icache_flush;
logic                            icache_req_valid;
logic                            icache_req_kill;
logic [ICACHE_INDEX_SIZE-1:0]    icache_req_idx;
logic [ICACHE_VPN_SIZE-1:0]      icache_req_vpn;

// To Core
logic                            icache_resp_ready;
logic                            icache_resp_valid;
logic [ICACHELINE_SIZE-1:0]      icache_resp_data;
logic                            icache_resp_xcpt;

logic                            nc_fetch_resp_valid;
logic [ICACHELINE_SIZE-1:0]      nc_fetch_resp_data;
logic                            nc_fetch_req_valid;
logic [PHY_VIRT_MAX_ADDR_SIZE-1:0] nc_fetch_req_addr;

logic                            icache_tlb_resp_miss;
logic                            icache_tlb_resp_ptw_v;
logic [ICACHE_PPN_SIZE-1:0]      icache_tlb_resp_ppn;
logic                            icache_tlb_resp_xcpt;

logic                            icache_tlb_req_valid;
logic [ICACHE_VPN_SIZE-1:0]      icache_tlb_req_vpn;

logic icache_en_translation;
logic icache_invalidate;
logic icache_nc_busy;
logic icache_nc_valid;
logic [ICACHELINE_SIZE-1:0]      icache_nc_data;
logic core_fetch_req_valid;

//--PMU
pmu_interface_t pmu_interface;
// TODO!!!
//assign pmu_interface.icache_req = lagarto_ireq.valid;
//assign pmu_interface.icache_kill = lagarto_ireq.kill;
//assign pmu_interface.icache_busy = !icache_resp.ready;

// Debug wires
debug_contr_in_t                debug_contr_in;
debug_reg_in_t                  debug_reg_in;
debug_contr_out_t               debug_contr_out;
debug_reg_out_t                 debug_reg_out;

// *** Memory Management Unit ***

//assign pmu_interface.itlb_stall = itlb_icache_comm.resp.miss && !itlb_icache_comm.tlb_ready;

// *** Core Instance ***

sargantana_subtile #(
    .DracCfg(DracCfg),

    .MMU_REQUESTER_SID(0),
    .CORE_REQUESTER_SID(1),

    .ICACHELINE_SIZE(ICACHELINE_SIZE),
    .ICACHE_INDEX_SIZE(ICACHE_INDEX_SIZE),
    .ICACHE_PPN_SIZE(ICACHE_PPN_SIZE),
    .ICACHE_VPN_SIZE(ICACHE_VPN_SIZE),

    .hpdcache_req_t(hpdcache_req_t),
    .hpdcache_tag_t(hpdcache_tag_t),
    .hpdcache_rsp_t(hpdcache_rsp_t)
) subtile_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .soft_rstn_i(soft_rstn_i),
    .reset_addr_i(reset_addr_i),
    .core_id_i(core_id_i),

    // Chip-specific connections

    `ifdef INTEL_FSCAN_CTECH
    .fscan_rstbypen(fscan_rstbypen),//AK
    `endif // INTEL_FSCAN_CTECH
    `ifdef PITON_CINCORANCH
    .boot_main_id_i(boot_main_id_i),
    `endif  // Custom for CincoRanch
    `ifdef EXTERNAL_HPM_EVENT_NUM
    .external_hpm_i(external_hpm_i),
    `endif

    // iCache Interface

    .icache_flush_o(icache_flush),
    .icache_req_valid_o(core_fetch_req_valid),
    .icache_req_kill_o(icache_req_kill),
    .icache_req_idx_o(icache_req_idx),
    .icache_req_vpn_o(icache_req_vpn),

    // To Core
    .icache_resp_ready_i(icache_resp_ready & ~icache_nc_busy),
    .icache_resp_valid_i(icache_resp_valid | icache_nc_valid),
    .icache_resp_data_i(icache_nc_valid ? icache_nc_data : icache_resp_data),
    .icache_resp_xcpt_i(icache_resp_xcpt),

    .icache_tlb_resp_miss_o(icache_tlb_resp_miss),
    .icache_tlb_resp_ptw_v_o(icache_tlb_resp_ptw_v),
    .icache_tlb_resp_ppn_o(icache_tlb_resp_ppn),
    .icache_tlb_resp_xcpt_o(icache_tlb_resp_xcpt),

    .icache_tlb_req_valid_i(icache_tlb_req_valid),
    .icache_tlb_req_vpn_i(icache_tlb_req_vpn),

    .icache_en_translation_o(icache_en_translation),

    // HPDCache interface
    .dcache_req_valid_o(dcache_req_valid),
    .dcache_req_ready_i(dcache_req_ready),
    .dcache_req_o(dcache_req),
    .dcache_req_abort_o(dcache_req_abort),
    .dcache_req_tag_o(dcache_req_tag),
    .dcache_req_pma_o(dcache_req_pma),

    .dcache_rsp_valid_i(dcache_rsp_valid),
    .dcache_rsp_i(dcache_rsp),
    .wbuf_empty_i(wbuf_empty),

    // Debug Module
    .visa_o(visa_o),
    .debug_contr_i(debug_contr_in),
    .debug_reg_i(debug_reg_in),

    .debug_contr_o(debug_contr_out),
    .debug_reg_o(debug_reg_out),

    // PMU Interface
    .pmu_interface_i(pmu_interface),

`ifdef CONF_SARGANTANA_ENABLE_PCR
    // PCR
    .pcr_req_ready_i(pcr_req_ready_i),    // ready bit of the pcr
    .pcr_resp_valid_i(pcr_resp_valid_i),   // ready bit of the pcr
    .pcr_resp_data_i(pcr_resp_data_i),    // read data from performance counter module
    .pcr_resp_core_id_i(pcr_resp_core_id_i), // core id of the tile that the date is sended
    .pcr_req_valid_o(pcr_req_valid_o),    // valid bit to make a pcr request
    .pcr_req_addr_o(pcr_req_addr_o),     // read/write address to performance counter module (up to 29 aux counters possible in riscv encoding.h)h
    .pcr_req_data_o(pcr_req_data_o),     // write data to performance counter module
    .pcr_req_we_o(pcr_req_we_o),       // Cmd of the petition
    .pcr_req_core_id_o(pcr_req_core_id_o),   // core id of the tile
`endif // CONF_SARGANTANA_ENABLE_PCR

    // Interrupts
    .time_irq_i(time_irq_i), // timer interrupt
    .irq_i(irq_i),      // external interrupt in
    .soft_irq_i(soft_irq_i),
    .time_i(time_i)     // time passed since the core is reset
);

// Debug donnections
assign debug_contr_in.halt_req      = debug_contr_halt_req_i;
assign debug_contr_in.resume_req    = debug_contr_resume_req_i;
assign debug_contr_in.progbuf_req   = debug_contr_progbuf_req_i;
assign debug_contr_in.halt_on_reset = debug_contr_halt_on_reset_i;

assign debug_reg_in.rnm_read_en     = debug_reg_rnm_read_en_i;
assign debug_reg_in.rnm_read_reg    = debug_reg_rnm_read_reg_i;
assign debug_reg_in.rf_en           = debug_reg_rf_en_i;
assign debug_reg_in.rf_preg         = debug_reg_rf_preg_i;
assign debug_reg_in.rf_we           = debug_reg_rf_we_i;
assign debug_reg_in.rf_wdata        = debug_reg_rf_wdata_i;

assign debug_contr_halt_ack_o       = debug_contr_out.halt_ack;
assign debug_contr_halted_o         = debug_contr_out.halted;
assign debug_contr_resume_ack_o     = debug_contr_out.resume_ack;
assign debug_contr_running_o        = debug_contr_out.running;
assign debug_contr_progbuf_ack_o    = debug_contr_out.progbuf_ack;
assign debug_contr_parked_o         = debug_contr_out.parked;
assign debug_contr_unavail_o        = debug_contr_out.unavail;
assign debug_contr_progbuf_xcpt_o   = debug_contr_out.progbuf_xcpt;
assign debug_contr_havereset_o      = debug_contr_out.havereset;

assign debug_reg_rnm_read_resp_o    = debug_reg_out.rnm_read_resp;
assign debug_reg_rf_rdata_o         = debug_reg_out.rf_rdata;

// *** iCache ***

nc_icache_buffer nc_icache_bf (
    .clk_i,
    .rstn_i,

    .en_translation_i(icache_en_translation),
    .core_req_valid_i(core_fetch_req_valid),
    .core_req_addr_i({icache_req_vpn, icache_req_idx}),
    .core_req_invalidate_i(icache_flush),
    .core_req_kill_i(icache_req_kill),

    .core_rsp_nc_busy_o(icache_nc_busy),
    .core_rsp_valid_o(icache_nc_valid),
    .core_rsp_data_o(icache_nc_data),

    .icache_req_valid_o(icache_req_valid),

    .req_nc_valid_o(brom_req_valid_o),
    .req_nc_vaddr_o(brom_req_address_o),

    .l2_grant_valid_i(io_mem_grant_valid & ~io_mem_grant_inval),
    .l2_resp_data_i(io_mem_grant_bits_data)
);

sargantana_top_icache # (
    .KILL_RESP          ( 1'b1          ),
    .LINES_256          ( 1'b0          ),

    .ICACHE_MEM_BLOCK   (ICACHELINE_SIZE/8),  // In Bytes
    .PADDR_SIZE         (PHY_ADDR_SIZE),
    .ADDR_SIZE          (PHY_VIRT_MAX_ADDR_SIZE),
    .IDX_BITS_SIZE      (12), // TODO: Where does this come from?
    .FETCH_WIDHT        (ICACHELINE_SIZE)
) icache (
    `ifdef INTEL_PHYSICAL_MEM_CTRL
    .hduspsr_mem_ctrl           (hduspsr_mem_ctrl),
    `endif
    .clk_i                      (clk_i),
    .rstn_i                     (rstn_i),
    .flush_i                    (icache_flush),

    .lagarto_ireq_valid_i       (icache_req_valid),
    .lagarto_ireq_kill_i        (icache_req_kill),
    .lagarto_ireq_idx_i         (icache_req_idx),
    .lagarto_ireq_vpn_i         (icache_req_vpn),

    .icache_resp_ready_o        (icache_resp_ready),
    .icache_resp_valid_o        (icache_resp_valid),
    .icache_resp_data_o         (icache_resp_data),
    .icache_resp_xcpt_o         (icache_resp_xcpt),
    .icache_resp_vaddr_o        ( /* unused */),

    .mmu_tresp_miss_i           (icache_tlb_resp_miss),
    .mmu_tresp_ptw_v_i          (icache_tlb_resp_ptw_v),
    .mmu_tresp_ppn_i            (icache_tlb_resp_ppn),
    .mmu_tresp_xcpt_i           (icache_tlb_resp_xcpt),

    .icache_treq_valid_o        (icache_tlb_req_valid),
    .icache_treq_vpn_o          (icache_tlb_req_vpn),

    .ifill_resp_valid_i         (io_mem_grant_valid),
    .ifill_resp_ack_i           (&io_mem_grant_bits_addr_beat),
    .ifill_resp_data_i          (io_mem_grant_bits_data),
    .ifill_resp_inv_valid_i     (io_mem_grant_inval),
    .ifill_resp_inv_paddr_i     (io_mem_grant_inval_addr),

    .icache_ifill_req_valid_o   (io_mem_acquire_valid),
    //.icache_ifill_req_way_o     (ifill_req.way),
    .icache_ifill_req_paddr_o   (io_mem_acquire_bits_addr_block),

    .imiss_time_pmu_o           (pmu_interface.icache_miss_time),
    .imiss_kill_pmu_o           (pmu_interface.icache_miss_kill)
);

// Core-dCache Interface
logic          dcache_req_valid [HPDCACHE_NREQUESTERS];
logic          dcache_req_ready [HPDCACHE_NREQUESTERS];
hpdcache_req_t dcache_req       [HPDCACHE_NREQUESTERS];
logic          dcache_req_abort [HPDCACHE_NREQUESTERS];
hpdcache_tag_t dcache_req_tag   [HPDCACHE_NREQUESTERS];
hpdcache_pkg::hpdcache_pma_t dcache_req_pma   [HPDCACHE_NREQUESTERS];

logic           dcache_rsp_valid [HPDCACHE_NREQUESTERS];
hpdcache_rsp_t  dcache_rsp [HPDCACHE_NREQUESTERS];
logic wbuf_empty;

hpdcache #(
    .HPDcacheCfg          (HPDcacheCfg),
    .hpdcache_tag_t       (hpdcache_tag_t),
    .hpdcache_data_word_t (hpdcache_data_word_t),
    .hpdcache_data_be_t   (hpdcache_data_be_t),
    .hpdcache_req_offset_t(hpdcache_req_offset_t),
    .hpdcache_req_data_t  (hpdcache_req_data_t),
    .hpdcache_req_be_t    (hpdcache_req_be_t),
    .hpdcache_req_sid_t   (hpdcache_req_sid_t),
    .hpdcache_req_tid_t   (hpdcache_req_tid_t),
    .hpdcache_req_t       (hpdcache_req_t),
    .hpdcache_rsp_t       (hpdcache_rsp_t),
    .hpdcache_mem_addr_t  (hpdcache_mem_addr_t),
    .hpdcache_mem_id_t    (hpdcache_mem_id_t),
    .hpdcache_mem_data_t  (hpdcache_mem_data_t),
    .hpdcache_mem_be_t    (hpdcache_mem_be_t),
    .hpdcache_mem_req_t   (hpdcache_mem_req_t),
    .hpdcache_mem_req_w_t (hpdcache_mem_req_w_t),
    .hpdcache_mem_resp_r_t(hpdcache_mem_resp_r_t),
    .hpdcache_mem_resp_w_t(hpdcache_mem_resp_w_t),
    .hpdcache_nline_t     (hpdcache_nline_t)
) dcache (
    `ifdef INTEL_PHYSICAL_MEM_CTRL
    .uhdusplr_mem_ctrl (uhdusplr_mem_ctrl),
    `endif
    .clk_i(clk_i),
    .rst_ni(rstn_i),

    // Core interface
    .core_req_valid_i                  (dcache_req_valid),
    .core_req_ready_o                  (dcache_req_ready),
    .core_req_i                        (dcache_req),
    .core_req_abort_i                  (dcache_req_abort),
    .core_req_tag_i                    (dcache_req_tag),
    .core_req_pma_i                    (dcache_req_pma),

    .core_rsp_valid_o                  (dcache_rsp_valid),
    .core_rsp_o                        (dcache_rsp),

    // Read / Invalidation memory interface
    .mem_req_read_ready_i         (mem_req_read_ready_i),
    .mem_req_read_valid_o         (mem_req_read_valid_o),
    .mem_req_read_o               (mem_req_read_o),

    .mem_resp_read_ready_o        (mem_resp_read_ready_o),
    .mem_resp_read_valid_i        (mem_resp_read_valid_i),
    .mem_resp_read_i              (mem_resp_read_i),
  `ifdef HPDCACHE_OPENPITON
    // Invalidation interface
    .mem_resp_read_inval_i        (mem_inval_valid_i),
    .mem_resp_read_inval_nline_i  (mem_inval_i),
  `endif

    // dMem writeback interface
    .mem_req_write_ready_i        (mem_req_write_ready_i),
    .mem_req_write_valid_o        (mem_req_write_valid_o),
    .mem_req_write_o              (mem_req_write_o),

    .mem_req_write_data_ready_i   (mem_req_write_data_ready_i),
    .mem_req_write_data_valid_o   (mem_req_write_data_valid_o),
    .mem_req_write_data_o         (mem_req_write_data_o),

    .mem_resp_write_ready_o       (mem_resp_write_ready_o),
    .mem_resp_write_valid_i       (mem_resp_write_valid_i),
    .mem_resp_write_i             (mem_resp_write_i),

    // PMU events
    .evt_stall_o(pmu_interface.dcache_stall),
    .evt_stall_refill_o(pmu_interface.dcache_stall_refill),
    .evt_rtab_rollback_o(pmu_interface.dcache_rtab_rollback),
    .evt_req_on_hold_o(pmu_interface.dcache_req_onhold),
    .evt_prefetch_req_o(pmu_interface.dcache_prefetch_req),
    .evt_read_req_o(pmu_interface.dcache_read_req),
    .evt_write_req_o(pmu_interface.dcache_write_req),
    .evt_cmo_req_o(pmu_interface.dcache_cmo_req),
    .evt_uncached_req_o(pmu_interface.dcache_uncached_req),
    .evt_cache_read_miss_o(pmu_interface.dcache_miss_read_req),
    .evt_cache_write_miss_o(pmu_interface.dcache_miss_write_req),

    // Write buffer
    .wbuf_empty_o(wbuf_empty),
    .wbuf_flush_i(1'b0), // Unused

    // Config
    .cfg_enable_i                        (1'b1),
    .cfg_wbuf_inhibit_write_coalescing_i (!WriteCoalescingEn),
    .cfg_wbuf_threshold_i                (WriteCoalescingTh),
    .cfg_wbuf_reset_timecnt_on_write_i   (1'b1),
    .cfg_wbuf_sequential_waw_i           (1'b0),
    .cfg_prefetch_updt_plru_i            (1'b1),
    .cfg_error_on_cacheable_amo_i        (1'b0), //Replicated amo mode
    .cfg_rtab_single_entry_i             (1'b0),
    .cfg_default_wb_i                    (1'b0)  // Disable writeback mode

);

//PMU
//TODO!!! assign pmu_interface.icache_miss_l2_hit = ifill_resp.ack & io_core_pmu_l2_hit_i;

endmodule
