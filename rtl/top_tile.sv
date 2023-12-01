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

module top_tile
    import drac_pkg::*, sargantana_icache_pkg::*, mmu_pkg::*, hpdcache_pkg::*, sargantana_hpdc_pkg::*;
(
//------------------------------------------------------------------------------------
// ORIGINAL INPUTS OF LAGARTO 
//------------------------------------------------------------------------------------
    input logic                 clk_i,
    input logic                 rstn_i,
    input logic                 soft_rstn_i,
    input addr_t                reset_addr_i,

//------------------------------------------------------------------------------------
// DEBUG RING SIGNALS INPUT
// debug_halt_i is istall_test 
//------------------------------------------------------------------------------------    
    input                       debug_halt_i,

    input addr_t                IO_FETCH_PC_VALUE,
    input                       IO_FETCH_PC_UPDATE,
    
    input                       IO_REG_READ,
    input  [4:0]                IO_REG_ADDR,
    input                       IO_REG_WRITE,
    input bus64_t               IO_REG_WRITE_DATA,
    input  [5:0]		IO_REG_PADDR,
    input			IO_REG_PREAD,

//------------------------------------------------------------------------------------
// I-CANCHE INPUT INTERFACE
//------------------------------------------------------------------------------------
    
    //- From L2
    input  logic         io_mem_grant_valid                 ,
    input  logic [511:0] io_mem_grant_bits_data             ,
    input  logic   [1:0] io_mem_grant_bits_addr_beat        ,
    

//----------------------------------------------------------------------------------
// D-CACHE  INTERFACE
//----------------------------------------------------------------------------------

    //      Miss read interface
    input  logic                          mem_req_miss_read_ready_i,
    output logic                          mem_req_miss_read_valid_o,
    output hpdcache_mem_req_t             mem_req_miss_read_o,
    input  hpdcache_mem_id_t              mem_req_miss_read_base_id_i,

    output logic                          mem_resp_miss_read_ready_o,
    input  logic                          mem_resp_miss_read_valid_i,
    input  hpdcache_mem_resp_r_t          mem_resp_miss_read_i,

    //      Write-buffer write interface
    input  logic                          mem_req_wbuf_write_ready_i,
    output logic                          mem_req_wbuf_write_valid_o,
    output hpdcache_mem_req_t             mem_req_wbuf_write_o,
    input  hpdcache_mem_id_t              mem_req_wbuf_write_base_id_i,

    input  logic                          mem_req_wbuf_write_data_ready_i,
    output logic                          mem_req_wbuf_write_data_valid_o,
    output hpdcache_mem_req_w_t           mem_req_wbuf_write_data_o,

    output logic                          mem_resp_wbuf_write_ready_o,
    input  logic                          mem_resp_wbuf_write_valid_i,
    input  hpdcache_mem_resp_w_t          mem_resp_wbuf_write_i,

    //      Uncached read interface
    input  logic                          mem_req_uc_read_ready_i,
    output logic                          mem_req_uc_read_valid_o,
    output hpdcache_mem_req_t             mem_req_uc_read_o,
    input  hpdcache_mem_id_t              mem_req_uc_read_base_id_i,

    output logic                          mem_resp_uc_read_ready_o,
    input  logic                          mem_resp_uc_read_valid_i,
    input  hpdcache_mem_resp_r_t          mem_resp_uc_read_i,

    //      Uncached write interface
    input  logic                          mem_req_uc_write_ready_i,
    output logic                          mem_req_uc_write_valid_o,
    output hpdcache_mem_req_t             mem_req_uc_write_o,
    input  hpdcache_mem_id_t              mem_req_uc_write_base_id_i,

    input  logic                          mem_req_uc_write_data_ready_i,
    output logic                          mem_req_uc_write_data_valid_o,
    output hpdcache_mem_req_w_t           mem_req_uc_write_data_o,

    output logic                          mem_resp_uc_write_ready_o,
    input  logic                          mem_resp_uc_write_valid_i,
    input  hpdcache_mem_resp_w_t          mem_resp_uc_write_i,


//-----------------------------------------------------------------------------------
// I-CACHE OUTPUT INTERFACE
//-----------------------------------------------------------------------------------

    //- To L2
    output logic         io_mem_acquire_valid               ,
    output logic [BLOCK_ADDR_SIZE-1:0] io_mem_acquire_bits_addr_block,
    output logic         io_mem_acquire_bits_client_xact_id ,
    output logic   [1:0] io_mem_acquire_bits_addr_beat      ,
    output logic [127:0] io_mem_acquire_bits_data           ,
    output logic         io_mem_acquire_bits_is_builtin_type,
    output logic   [2:0] io_mem_acquire_bits_a_type         ,
    output logic  [16:0] io_mem_acquire_bits_union          ,
    output logic         io_mem_grant_ready                 ,

//-----------------------------------------------------------------------------------
// DEBUGGING MODULE SIGNALS
//-----------------------------------------------------------------------------------

// PC
    output addr_t               IO_FETCH_PC,
    output addr_t               IO_DEC_PC,
    output addr_t               IO_RR_PC,
    output addr_t               IO_EXE_PC,
    output addr_t               IO_WB_PC,
// WB
    output logic                IO_WB_PC_VALID,
    output logic  [4:0]         IO_WB_ADDR,
    output logic                IO_WB_WE,
    output bus64_t              IO_WB_BITS_ADDR,

    output logic		IO_REG_BACKEND_EMPTY,
    output logic  [5:0]		IO_REG_LIST_PADDR,
    output bus64_t              IO_REG_READ_DATA,


//-----------------------------------------------------------------------------
// PMU INTERFACE
//-----------------------------------------------------------------------------
    input  logic                io_core_pmu_l2_hit_i        ,

//-----------------------------------------------------------------------------
// BOOTROM CONTROLER INTERFACE
//-----------------------------------------------------------------------------
    input  logic                brom_ready_i        ,
    input  logic [31:0]         brom_resp_data_i    ,
    input  logic                brom_resp_valid_i   ,
    output logic [23:0]         brom_req_address_o  ,
    output logic                brom_req_valid_o    ,
   
    input logic                 csr_spi_config_i,

//-----------------------------------------------------------------------------
// INTERRUPTS
//-----------------------------------------------------------------------------
    input logic                 time_irq_i, // timer interrupt
    input logic                 irq_i,      // external interrupt in
    input  logic [63:0]         time_i,     // time passed since the core is reset

//-----------------------------------------------------------------------------
// PCR
//-----------------------------------------------------------------------------
    //PCR req inputs
    input  logic                pcr_req_ready_i,    // ready bit of the pcr

    //PCR resp inputs
    input  logic                pcr_resp_valid_i,   // ready bit of the pcr
    input  logic [63:0]         pcr_resp_data_i,    // read data from performance counter module
    input  logic                pcr_resp_core_id_i, // core id of the tile that the date is sended

    //PCR outputs request
    output logic                pcr_req_valid_o,    // valid bit to make a pcr request
    output logic  [11:0]        pcr_req_addr_o,     // read/write address to performance counter module (up to 29 aux counters possible in riscv encoding.h)
    output logic  [63:0]        pcr_req_data_o,     // write data to performance counter module
    output logic  [2:0]         pcr_req_we_o,       // Cmd of the petition
    output logic                pcr_req_core_id_o   // core id of the tile

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
resp_csr_cpu_t resp_csr_interface_datapath;
logic [1:0] priv_lvl;
logic [2:0] fcsr_rm;
logic [1:0] fcsr_fs;
logic en_ld_st_translation;
logic en_translation;
logic [39:0] vpu_csr;

addr_t dcache_addr;

// struct debug input/output
debug_in_t debug_in;
debug_out_t debug_out;

//iCache
iresp_o_t      icache_resp  ;
ireq_i_t       lagarto_ireq ;
tresp_i_t      itlb_tresp   ;
treq_o_t       itlb_treq    ;
ifill_resp_i_t ifill_resp   ;
ifill_req_o_t  ifill_req    ;
logic          iflush       ;
logic          req_icache_ready;

//--PMU
pmu_interface_t pmu_interface;
assign pmu_interface.icache_req = lagarto_ireq.valid;
assign pmu_interface.icache_kill = lagarto_ireq.kill;
assign pmu_interface.icache_miss_l2_hit = imiss_l2_hit;
assign pmu_interface.icache_miss_kill = imiss_kill_pmu;
assign pmu_interface.icache_busy = !icache_resp.ready;
assign pmu_interface.icache_miss_time = imiss_time_pmu;
assign pmu_interface.itlb_access = pmu_itlb_access;
assign pmu_interface.itlb_miss = pmu_itlb_miss;
assign pmu_interface.dtlb_access = pmu_dtlb_access;
assign pmu_interface.dtlb_miss = pmu_dtlb_miss;
assign pmu_interface.ptw_buffer_hit = pmu_ptw_hit;
assign pmu_interface.ptw_buffer_miss = pmu_ptw_miss;
assign pmu_interface.itlb_stall = pmu_itlb_miss_cycle;


//L2 Network conection - response
assign ifill_resp.data  = io_mem_grant_bits_data             ;  
assign ifill_resp.beat  = io_mem_grant_bits_addr_beat        ;
assign ifill_resp.valid = io_mem_grant_valid                 ;
assign ifill_resp.ack   = io_mem_grant_bits_addr_beat[0] &
                          io_mem_grant_bits_addr_beat[1] ;

//L2 Network conection - request
assign io_mem_acquire_valid                = ifill_req.valid        ;
assign io_mem_acquire_bits_addr_block      = ifill_req.paddr        ;
assign io_mem_acquire_bits_client_xact_id  =   1'b0                 ;
assign io_mem_acquire_bits_addr_beat       =   2'b0                 ;
assign io_mem_acquire_bits_data            = 127'b0                 ;
assign io_mem_acquire_bits_is_builtin_type =   1'b1                 ;
assign io_mem_acquire_bits_a_type          =   3'b001               ;
assign io_mem_acquire_bits_union           =  17'b00000000111000001 ;
assign io_mem_grant_ready                  =   1'b1                 ;

// *** Memory Management Unit ***

// Page Table Walker - iTLB/dTLB - dCache Connections
tlb_ptw_comm_t itlb_ptw_comm, dtlb_ptw_comm;
ptw_tlb_comm_t ptw_itlb_comm, ptw_dtlb_comm;
ptw_dmem_comm_t ptw_dmem_comm;
dmem_ptw_comm_t dmem_ptw_comm;

mmu_pkg::csr_ptw_comm_t csr_ptw_comm;

// Page Table Walker - iCache/dCache Connections

mmu_pkg::cache_tlb_comm_t icache_itlb_comm, core_dtlb_comm;
mmu_pkg::tlb_cache_comm_t itlb_icache_comm, dtlb_core_comm;

assign icache_itlb_comm.req.valid = itlb_treq.valid;
assign icache_itlb_comm.req.asid = 1'b0;
assign icache_itlb_comm.req.vpn = itlb_treq.vpn;
assign icache_itlb_comm.req.passthrough = 1'b0;
assign icache_itlb_comm.req.instruction = 1'b1;
assign icache_itlb_comm.req.store = 1'b0;
assign icache_itlb_comm.priv_lvl = priv_lvl;
assign icache_itlb_comm.vm_enable = en_translation;

assign itlb_tresp.miss   = itlb_icache_comm.resp.miss;
assign itlb_tresp.ptw_v  = ptw_itlb_comm.resp.valid;
assign itlb_tresp.ppn    = itlb_icache_comm.resp.ppn;
assign itlb_tresp.xcpt   = itlb_icache_comm.resp.xcpt.fetch;

assign pmu_itlb_miss_cycle = itlb_icache_comm.resp.miss && !itlb_icache_comm.tlb_ready;

sew_t sew;
assign sew = sew_t'(vpu_csr[37:36]);

// *** Core Instance ***

top_drac sargantana_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .soft_rstn_i(soft_rstn_i),
    .reset_addr_i(reset_addr_i),

    // Debug ring
    .debug_halt_i(debug_halt_i),
    .IO_FETCH_PC_VALUE(IO_FETCH_PC_VALUE),
    .IO_FETCH_PC_UPDATE(IO_FETCH_PC_UPDATE),
    .IO_REG_READ(IO_REG_READ),
    .IO_REG_ADDR(IO_REG_ADDR),
    .IO_REG_WRITE(IO_REG_WRITE),
    .IO_REG_WRITE_DATA(IO_REG_WRITE_DATA),
    .IO_REG_PADDR(IO_REG_PADDR),
    .IO_REG_PREAD(IO_REG_PREAD),

    // iCache Interface
    .req_icache_ready_i(req_icache_ready),
    .req_cpu_icache_o(req_datapath_icache_interface),
    .en_translation_o(en_translation),
    .priv_lvl_o(priv_lvl),
    .resp_icache_cpu_i(resp_icache_interface_datapath),

    // dCache Interface
    .resp_dcache_cpu_i(resp_dcache_interface_datapath),
    .req_cpu_dcache_o(req_datapath_dcache_interface), 

    // MMU Interface
    .csr_ptw_comm_o(csr_ptw_comm),
    .dtlb_comm_o(core_dtlb_comm),
    .dtlb_comm_i(dtlb_core_comm),

    // Debug Module
    .IO_FETCH_PC(IO_FETCH_PC),
    .IO_DEC_PC(IO_DEC_PC),
    .IO_RR_PC(IO_RR_PC),
    .IO_EXE_PC(IO_EXE_PC),
    .IO_WB_PC(IO_WB_PC),
    .IO_WB_PC_VALID(IO_WB_PC_VALID),
    .IO_WB_ADDR(IO_WB_ADDR),
    .IO_WB_WE(IO_WB_WE),
    .IO_WB_BITS_ADDR(IO_WB_BITS_ADDR),
    .IO_REG_BACKEND_EMPTY(IO_REG_BACKEND_EMPTY),
    .IO_REG_LIST_PADDR(IO_REG_LIST_PADDR),
    .IO_REG_READ_DATA(IO_REG_READ_DATA),

    // PMU Interface
    .pmu_interface_i(pmu_interface),

    // Interrupts
    .time_irq_i(time_irq_i), // timer interrupt
    .irq_i(irq_i),      // external interrupt in
    .time_i(time_i),     // time passed since the core is reset

    // PCR
    .pcr_req_ready_i(pcr_req_ready_i),    // ready bit of the pcr
    .pcr_resp_valid_i(pcr_resp_valid_i),   // ready bit of the pcr
    .pcr_resp_data_i(pcr_resp_data_i),    // read data from performance counter module
    .pcr_resp_core_id_i(pcr_resp_core_id_i), // core id of the tile that the date is sended
    .pcr_req_valid_o(pcr_req_valid_o),    // valid bit to make a pcr request
    .pcr_req_addr_o(pcr_req_addr_o),     // read/write address to performance counter module (up to 29 aux counters possible in riscv encoding.h)h
    .pcr_req_data_o(pcr_req_data_o),     // write data to performance counter module
    .pcr_req_we_o(pcr_req_we_o),       // Cmd of the petition
    .pcr_req_core_id_o(pcr_req_core_id_o)   // core id of the tile

);

// *** iCache ***

icache_interface icache_interface_inst(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // Inputs ICache
    .icache_resp_datablock_i    ( icache_resp.data  ),
    .icache_resp_vaddr_i        ( icache_resp.vaddr ), 
    .icache_resp_valid_i        ( icache_resp.valid ),
    .icache_req_ready_i         ( icache_resp.ready ), 
    .tlb_resp_xcp_if_i          ( icache_resp.xcpt  ),
    .en_translation_i           ( en_translation ), 
    .csr_spi_config_i           ( csr_spi_config_i  ), 
   
    // Outputs ICache
    .icache_invalidate_o    ( iflush             ), 
    .icache_req_bits_idx_o  ( lagarto_ireq.idx   ), 
    .icache_req_kill_o      ( lagarto_ireq.kill  ), 
    .icache_req_valid_o     ( lagarto_ireq.valid ),
    .icache_req_bits_vpn_o  ( lagarto_ireq.vpn   ), 

    // Inputs Bootrom
    .brom_ready_i           ( brom_ready_i      ),
    .brom_resp_data_i       ( brom_resp_data_i  ), 
    .brom_resp_valid_i      ( brom_resp_valid_i ),

    // Outputs Bootrom
    .brom_req_address_o     ( brom_req_address_o ),
    .brom_req_valid_o       ( brom_req_valid_o   ),

    // Fetch stage interface - Request packet from fetch_stage
    .req_fetch_icache_i(req_datapath_icache_interface),
    
    // Fetch stage interface - Response packet icache to fetch
    .resp_icache_fetch_o(resp_icache_interface_datapath),
    .req_fetch_ready_o(req_icache_ready),
    //PMU
    .buffer_miss_o (buffer_miss )
);

sargantana_top_icache icache (
    .clk_i              ( clk_i           ) ,
    .rstn_i             ( rstn_i           ) ,
    .flush_i            ( iflush        ) , 
    .lagarto_ireq_i     ( lagarto_ireq  ) , //- From Lagarto.
    .icache_resp_o      ( icache_resp   ) , //- To Lagarto.
    .mmu_tresp_i        ( itlb_tresp    ) , //- From MMU.
    .icache_treq_o      ( itlb_treq     ) , //- To MMU.
    .ifill_resp_i       ( ifill_resp    ) , //- From upper levels.
    .icache_ifill_req_o ( ifill_req     ) ,  //- To upper levels. 
    .imiss_time_pmu_o    ( imiss_time_pmu ) ,
    .imiss_kill_pmu_o    ( imiss_kill_pmu )
);

// *** dCache ***

// Core-dCache Interface
logic          dcache_req_valid [HPDCACHE_NREQUESTERS-1:0];
logic          dcache_req_ready [HPDCACHE_NREQUESTERS-1:0];
hpdcache_req_t dcache_req       [HPDCACHE_NREQUESTERS-1:0];

logic          dcache_rsp_valid [HPDCACHE_NREQUESTERS-1:0];
hpdcache_rsp_t dcache_rsp       [HPDCACHE_NREQUESTERS-1:0];
logic wbuf_empty;

dcache_interface dcache_interface_inst(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .en_ld_st_translation_i(en_ld_st_translation),

    // CPU Interface
    .req_cpu_dcache_i(req_datapath_dcache_interface),
    .resp_dcache_cpu_o(resp_dcache_interface_datapath),

    // dCache Interface
    .dcache_ready_i(dcache_req_ready[1]),
    .dcache_valid_i(dcache_rsp_valid[1]),
    .core_req_valid_o(dcache_req_valid[1]),
    .req_dcache_o(dcache_req[1]),
    .rsp_dcache_i(dcache_rsp[1]),
    .wbuf_empty_i(wbuf_empty),

    // PMU
    .dmem_is_store_o ( pmu_interface.exe_store ),
    .dmem_is_load_o  ( pmu_interface.exe_load  )
);

hpdcache #(
    .NREQUESTERS            (HPDCACHE_NREQUESTERS),
    .HPDcacheMemIdWidth     (HPDCACHE_MEM_TID_WIDTH),
    .HPDcacheMemDataWidth   (HPDCACHE_MEM_DATA_WIDTH),
    .hpdcache_mem_req_t     (hpdcache_mem_req_t),
    .hpdcache_mem_req_w_t   (hpdcache_mem_req_w_t),
    .hpdcache_mem_resp_r_t  (hpdcache_mem_resp_r_t),
    .hpdcache_mem_resp_w_t  (hpdcache_mem_resp_w_t)
) dcache (
    .clk_i(clk_i),
    .rst_ni(rstn_i),

    // Core interface
    .core_req_valid_i(dcache_req_valid),
    .core_req_ready_o(dcache_req_ready),
    .core_req_i(dcache_req),
    .core_rsp_valid_o(dcache_rsp_valid),
    .core_rsp_o(dcache_rsp),

    // dMem miss-read interface
    .mem_req_miss_read_ready_i(mem_req_miss_read_ready_i),
    .mem_req_miss_read_valid_o(mem_req_miss_read_valid_o),
    .mem_req_miss_read_o(mem_req_miss_read_o),
    //.mem_req_miss_read_base_id_i(mem_req_miss_read_base_id_i),

    .mem_resp_miss_read_ready_o(mem_resp_miss_read_ready_o),
    .mem_resp_miss_read_valid_i(mem_resp_miss_read_valid_i),
    .mem_resp_miss_read_i(mem_resp_miss_read_i),

    // dMem writeback interface
    .mem_req_wbuf_write_ready_i(mem_req_wbuf_write_ready_i),
    .mem_req_wbuf_write_valid_o(mem_req_wbuf_write_valid_o),
    .mem_req_wbuf_write_o(mem_req_wbuf_write_o),
    //.mem_req_wbuf_write_base_id_i(mem_req_wbuf_write_base_id_i),

    .mem_req_wbuf_write_data_ready_i(mem_req_wbuf_write_data_ready_i),
    .mem_req_wbuf_write_data_valid_o(mem_req_wbuf_write_data_valid_o),
    .mem_req_wbuf_write_data_o(mem_req_wbuf_write_data_o),

    .mem_resp_wbuf_write_ready_o(mem_resp_wbuf_write_ready_o),
    .mem_resp_wbuf_write_valid_i(mem_resp_wbuf_write_valid_i),
    .mem_resp_wbuf_write_i(mem_resp_wbuf_write_i),

    // dMem uncacheable write interface
    .mem_req_uc_write_ready_i(mem_req_uc_write_ready_i),
    .mem_req_uc_write_valid_o(mem_req_uc_write_valid_o),
    .mem_req_uc_write_o(mem_req_uc_write_o),
    //.mem_req_uc_write_base_id_i(mem_req_uc_write_base_id_i),

    .mem_req_uc_write_data_ready_i(mem_req_uc_write_data_ready_i),
    .mem_req_uc_write_data_valid_o(mem_req_uc_write_data_valid_o),
    .mem_req_uc_write_data_o(mem_req_uc_write_data_o),

    .mem_resp_uc_write_ready_o(mem_resp_uc_write_ready_o),
    .mem_resp_uc_write_valid_i(mem_resp_uc_write_valid_i),
    .mem_resp_uc_write_i(mem_resp_uc_write_i),

    // dMem uncacheable read interface
    .mem_req_uc_read_ready_i(mem_req_uc_read_ready_i),
    .mem_req_uc_read_valid_o(mem_req_uc_read_valid_o),
    .mem_req_uc_read_o(mem_req_uc_read_o),
    //.mem_req_uc_read_base_id_i(mem_req_uc_read_base_id_i),

    .mem_resp_uc_read_ready_o(mem_resp_uc_read_ready_o),
    .mem_resp_uc_read_valid_i(mem_resp_uc_read_valid_i),
    .mem_resp_uc_read_i(mem_resp_uc_read_i),

    // misc
    .wbuf_empty_o(wbuf_empty),

    // PMU events
    .evt_stall_o(),
    .evt_stall_refill_o(),
    .evt_rtab_rollback_o(),
    .evt_req_on_hold_o(),
    .evt_prefetch_req_o(),
    .evt_read_req_o(),
    .evt_write_req_o(),
    .evt_cmo_req_o(),
    .evt_uncached_req_o(),
    .evt_cache_read_miss_o(),
    .evt_cache_write_miss_o(),

    // Unused
    .wbuf_flush_i(1'b0),

    // Config
    .cfg_enable_i(1'b1),
    .cfg_wbuf_threshold_i(4'd2),
    .cfg_wbuf_reset_timecnt_on_write_i(1'b1),
    .cfg_wbuf_sequential_waw_i(1'b0),
    .cfg_prefetch_updt_plru_i(1'b1),
    .cfg_error_on_cacheable_amo_i(1'b0),
    .cfg_rtab_single_entry_i(1'b0)
);

tlb itlb (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .cache_tlb_comm_i(icache_itlb_comm),
    .tlb_cache_comm_o(itlb_icache_comm),
    .ptw_tlb_comm_i(ptw_itlb_comm),
    .tlb_ptw_comm_o(itlb_ptw_comm),
    .pmu_tlb_access_o(pmu_itlb_access),
    .pmu_tlb_miss_o(pmu_itlb_miss)
);

tlb dtlb (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .cache_tlb_comm_i(core_dtlb_comm),
    .tlb_cache_comm_o(dtlb_core_comm),
    .ptw_tlb_comm_i(ptw_dtlb_comm),
    .tlb_ptw_comm_o(dtlb_ptw_comm),
    .pmu_tlb_access_o(pmu_dtlb_access),
    .pmu_tlb_miss_o(pmu_dtlb_miss)
);

ptw ptw_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // iTLB request-response
    .itlb_ptw_comm_i(itlb_ptw_comm), 
    .ptw_itlb_comm_o(ptw_itlb_comm),

    // dTLB request-response
    .dtlb_ptw_comm_i(dtlb_ptw_comm),
    .ptw_dtlb_comm_o(ptw_dtlb_comm),

    // dmem request-response
    .dmem_ptw_comm_i(dmem_ptw_comm),
    .ptw_dmem_comm_o(ptw_dmem_comm),

    // csr interface
    .csr_ptw_comm_i(csr_ptw_comm),

    // pmu interface
    .pmu_ptw_hit_o(pmu_ptw_hit),
    .pmu_ptw_miss_o(pmu_ptw_miss)
);

// Connect PTW to dcache
assign dcache_req_valid[0] = ptw_dmem_comm.req.valid;
assign dmem_ptw_comm.dmem_ready = dcache_req_ready[0];
assign dcache_req[0].addr = ptw_dmem_comm.req.addr;
assign dcache_req[0].wdata = ptw_dmem_comm.req.data;
assign dcache_req[0].op = ptw_dmem_comm.req.cmd == 5'b01010 ? HPDCACHE_REQ_AMO_OR : HPDCACHE_REQ_LOAD;
assign dcache_req[0].be = ptw_dmem_comm.req.cmd == 5'b01010 ? 8'hff : 8'h00;
assign dcache_req[0].size = ptw_dmem_comm.req.typ;
assign dcache_req[0].uncacheable = 1'b0;
assign dcache_req[0].sid = 0;
assign dcache_req[0].tid = 0;
assign dcache_req[0].need_rsp = 1'b1;

assign dmem_ptw_comm.resp.valid = dcache_rsp_valid[0];
assign dmem_ptw_comm.resp.data = dcache_rsp[0].rdata;

//PMU  
assign imiss_l2_hit = ifill_resp.ack & io_core_pmu_l2_hit_i; 


endmodule
