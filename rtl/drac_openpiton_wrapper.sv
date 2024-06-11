/*
 *  Authors       : Oscar Lostes Cazorla, Noelia Oliete Escuin
 *  Creation Date : July, 2023
 *  Description   : Sargantana Wrapper to be used in OpenPiton
 *  History      :
 */

 module drac_openpiton_wrapper
 import drac_pkg::*; import hpdcache_pkg::*; import wt_cache_pkg::*; import sargantana_hpdc_pkg::*;
 #(
    // IO addresses
    parameter int unsigned               NIOSections           =  1,
    parameter logic [NrMaxRules*64-1:0]  InitIOBase            = 64'h00C0000000,
    parameter logic [NrMaxRules*64-1:0]  InitIOEnd             = 64'hFFFFFFFFFF,
    // Mapped addresses (IO and cached)
    parameter int unsigned               NMappedSections       =  1,
    parameter logic [NrMaxRules*64-1:0]  InitMappedBase        = 64'h00C0000000,
    parameter logic [NrMaxRules*64-1:0]  InitMappedEnd         = 64'hFFFFFFFFFF,
    // BROM address
    parameter logic [64-1:0]             InitBROMBase          = 64'h00C0000000,
    parameter logic [64-1:0]             InitBROMEnd           = 64'hFFFFFFFFFF,
    // HPDC Write coalescing
    parameter logic                      WriteCoalescingEn     =  0,
    parameter int unsigned               WriteCoalescingTh     =  0

) (
 input   logic                   clk_i,
 input   logic                   reset_l,     // This is an openpiton-specific name, do not change (hier. paths in TB use this)
 output  logic                   spc_grst_l,  // This is an openpiton-specific name, do not change (hier. paths in TB use this)
 input   logic [63:0]            hart_id_i,
 `ifdef PITON_CINCORANCH
 input   logic [1:0]             boot_main_id_i,
 `endif  // Custom for CincoRanch
 input logic   [63:0]            boot_addr_i,
 `ifdef EXTERNAL_HPM_EVENT_NUM
 input logic [`EXTERNAL_HPM_EVENT_NUM-1: 0]  external_hpm_i,
 `endif
 
 
 output  logic [$size(l15_req_t)-1:0]  l15_req_o,
 input   logic [$size(l15_rtrn_t)-1:0] l15_rtrn_i,

 input logic time_irq_i,
 input logic [63:0] time_i,
 input logic irq_i,
 input logic soft_irq_i,

 // Debug ring interface

    input  logic                debug_halt_i,
    input debug_intel_in_t      debug_intel_i,


    input  addr_t               debug_pc_addr_i,
    input  logic                debug_pc_valid_i,
    
    input  logic                debug_reg_read_valid_i,
    input  logic [4:0]          debug_reg_read_addr_i,
    input  logic                debug_preg_write_valid_i,
    input  bus64_t              debug_preg_write_data_i,
    input  logic [5:0]	        debug_preg_addr_i,
    input  logic                debug_preg_read_valid_i,

    output addr_t               debug_fetch_pc_o,
    output addr_t               debug_decode_pc_o,
    output addr_t               debug_register_read_pc_o,
    output addr_t               debug_execute_pc_o,
    output addr_t               debug_writeback_pc_o,

    output logic                debug_writeback_pc_valid_o,
    output logic  [4:0]         debug_writeback_addr_o,
    output logic                debug_writeback_we_o,
    output bus64_t              debug_mem_addr_o,

    output logic		        debug_backend_empty_o,
    output logic  [5:0]		    debug_preg_addr_o,
    output bus64_t              debug_preg_data_o,
    output debug_intel_out_t    debug_intel_o,

    output visa_signals_t       visa_o
);

// Bootrom wires
logic   [39:0]  brom_req_address;
logic           brom_req_valid;

// icache wires
logic                     l1_request_valid;
logic                     l2_response_valid;
logic [PHY_ADDR_SIZE-1:0] l1_request_paddr;
logic [511:0]             l2_response_data; // TODO: LOCALPARAMETERS or PKG definition
logic [1:0]               l2_response_seqnum;
logic                     l2_inval_request;
logic [39:0]              l2_inval_addr;
assign l2_response_seqnum = '0;

//      Miss read interface
logic                           mem_req_miss_read_ready;
logic                           mem_req_miss_read_valid;
hpdcache_mem_req_t              mem_req_miss_read;

logic                           mem_resp_miss_read_ready;
logic                           mem_resp_miss_read_valid;
hpdcache_mem_resp_r_t           mem_resp_miss_read;

//      Write-buffer write interface
logic                           mem_req_wbuf_write_ready;
logic                           mem_req_wbuf_write_valid;
hpdcache_mem_req_t              mem_req_wbuf_write;

logic                           mem_req_wbuf_write_data_ready;
logic                           mem_req_wbuf_write_data_valid;
hpdcache_mem_req_w_t            mem_req_wbuf_write_data;

logic                           mem_resp_wbuf_write_ready;
logic                           mem_resp_wbuf_write_valid;
hpdcache_mem_resp_w_t           mem_resp_wbuf_write;

//      Uncached read interface
logic                           mem_req_uc_read_ready;
logic                           mem_req_uc_read_valid;
hpdcache_mem_req_t              mem_req_uc_read;

logic                           mem_resp_uc_read_ready;
logic                           mem_resp_uc_read_valid;
hpdcache_mem_resp_r_t           mem_resp_uc_read;

//      Uncached write interface
logic                           mem_req_uc_write_ready;
logic                           mem_req_uc_write_valid;
hpdcache_mem_req_t              mem_req_uc_write;

logic                           mem_req_uc_write_data_ready;
logic                           mem_req_uc_write_data_valid;
hpdcache_mem_req_w_t            mem_req_uc_write_data;

logic                           mem_resp_uc_write_ready;
logic                           mem_resp_uc_write_valid;
hpdcache_mem_resp_w_t           mem_resp_uc_write;

logic                           mem_inval_valid;
hpdcache_pkg::hpdcache_nline_t  mem_inval;

logic [15:0] wake_up_cnt_d, wake_up_cnt_q;
logic rst_n;

assign wake_up_cnt_d = (wake_up_cnt_q[$high(wake_up_cnt_q)]) ? wake_up_cnt_q : wake_up_cnt_q + 1;

always_ff @(posedge clk_i or negedge reset_l) begin : p_regs
 if(~reset_l) begin
     wake_up_cnt_q <= 0;
 end else begin
     wake_up_cnt_q <= wake_up_cnt_d;
 end
end

always_ff @(posedge clk_i) begin
 spc_grst_l <= reset_l;
end

// reset gate this
assign rst_n = wake_up_cnt_q[$high(wake_up_cnt_q)] & reset_l;

localparam drac_cfg_t DracOpenPitonCfg = '{
    NIOSections: NIOSections, // number of IO space sections
    InitIOBase:  InitIOBase, // IO base 0 address after reset
    InitIOEnd:   InitIOEnd, // IO end 0 address after reset

    NMappedSections: NMappedSections, // number of Memory space sections
    InitMappedBase:  InitMappedBase, // Memory base address after reset
    InitMappedEnd:   InitMappedEnd, // Memory end 0 address after reset

    InitBROMBase: InitBROMBase,
    InitBROMEnd: InitBROMEnd
};

top_tile #(
  .DracCfg(DracOpenPitonCfg),
  .WriteCoalescingEn(WriteCoalescingEn),
  .WriteCoalescingTh(WriteCoalescingTh)
) core_inst (
 .clk_i(clk_i),
 .rstn_i(rst_n),
 .soft_rstn_i(rst_n),
 .core_id_i(hart_id_i),
 `ifdef PITON_CINCORANCH
 .boot_main_id_i(boot_main_id_i),
 `endif  // Custom for CincoRanch
`ifdef EXTERNAL_HPM_EVENT_NUM
 .external_hpm_i(external_hpm_i),
 `endif
 
 .reset_addr_i(boot_addr_i), //'h00000100

 // Bootrom ports
 .brom_req_address_o(brom_req_address),
 .brom_req_valid_o(brom_req_valid),

 // icache ports
 .io_mem_acquire_valid(l1_request_valid),
 .io_mem_acquire_bits_addr_block(l1_request_paddr),
 .io_mem_grant_valid(l2_response_valid),
 .io_mem_grant_bits_data(l2_response_data),
 .io_mem_grant_bits_addr_beat(l2_response_seqnum),
 .io_mem_grant_inval(l2_inval_request),
 .io_mem_grant_inval_addr(l2_inval_addr[15:4]),

 // dmem ports

 // dMem miss-read interface
 .mem_req_miss_read_ready_i(mem_req_miss_read_ready),
 .mem_req_miss_read_valid_o(mem_req_miss_read_valid),
 .mem_req_miss_read_o(mem_req_miss_read),

 .mem_resp_miss_read_ready_o(mem_resp_miss_read_ready),
 .mem_resp_miss_read_valid_i(mem_resp_miss_read_valid),
 .mem_resp_miss_read_i(mem_resp_miss_read),

 // dMem writeback interface
 .mem_req_wbuf_write_ready_i(mem_req_wbuf_write_ready),
 .mem_req_wbuf_write_valid_o(mem_req_wbuf_write_valid),
 .mem_req_wbuf_write_o(mem_req_wbuf_write),

 .mem_req_wbuf_write_data_ready_i(mem_req_wbuf_write_data_ready),
 .mem_req_wbuf_write_data_valid_o(mem_req_wbuf_write_data_valid),
 .mem_req_wbuf_write_data_o(mem_req_wbuf_write_data),

 .mem_resp_wbuf_write_ready_o(mem_resp_wbuf_write_ready),
 .mem_resp_wbuf_write_valid_i(mem_resp_wbuf_write_valid),
 .mem_resp_wbuf_write_i(mem_resp_wbuf_write),

 // dMem uncacheable write interface
 .mem_req_uc_write_ready_i(mem_req_uc_write_ready),
 .mem_req_uc_write_valid_o(mem_req_uc_write_valid),
 .mem_req_uc_write_o(mem_req_uc_write),

 .mem_req_uc_write_data_ready_i(mem_req_uc_write_data_ready),
 .mem_req_uc_write_data_valid_o(mem_req_uc_write_data_valid),
 .mem_req_uc_write_data_o(mem_req_uc_write_data),

 .mem_resp_uc_write_ready_o(mem_resp_uc_write_ready),
 .mem_resp_uc_write_valid_i(mem_resp_uc_write_valid),
 .mem_resp_uc_write_i(mem_resp_uc_write),

 // dMem uncacheable read interface
 .mem_req_uc_read_ready_i(mem_req_uc_read_ready),
 .mem_req_uc_read_valid_o(mem_req_uc_read_valid),
 .mem_req_uc_read_o(mem_req_uc_read),

 .mem_resp_uc_read_ready_o(mem_resp_uc_read_ready),
 .mem_resp_uc_read_valid_i(mem_resp_uc_read_valid),
 .mem_resp_uc_read_i(mem_resp_uc_read),

 // Invalidation interface
 .mem_inval_valid_i(mem_inval_valid),
 .mem_inval_i(mem_inval),

 .time_irq_i(time_irq_i),
 .irq_i(irq_i),
 .soft_irq_i(soft_irq_i),
 .time_i(time_i),

 .debug_halt_i(debug_halt_i),
 .debug_intel_i(debug_intel_i),
 .debug_intel_o(debug_intel_o),

 .debug_pc_addr_i(debug_pc_addr_i),
 .debug_pc_valid_i(debug_pc_valid_i),

 .debug_reg_read_valid_i(debug_reg_read_valid_i),
 .debug_reg_read_addr_i(debug_reg_read_addr_i),
 .debug_preg_write_valid_i(debug_preg_write_valid_i),
 .debug_preg_write_data_i(debug_preg_write_data_i),
 .debug_preg_addr_i(debug_preg_addr_i),
 .debug_preg_read_valid_i(debug_preg_read_valid_i),

 .debug_fetch_pc_o(debug_fetch_pc_o),
 .debug_decode_pc_o(debug_decode_pc_o),
 .debug_register_read_pc_o(debug_register_read_pc_o),
 .debug_execute_pc_o(debug_execute_pc_o),
 .debug_writeback_pc_o(debug_writeback_pc_o),
 .debug_writeback_pc_valid_o(debug_writeback_pc_valid_o),
 
 .debug_writeback_addr_o(debug_writeback_addr_o),
 .debug_writeback_we_o(debug_writeback_we_o),
 .debug_mem_addr_o(debug_mem_addr_o),

 .debug_backend_empty_o(debug_backend_empty_o),
 .debug_preg_addr_o(debug_preg_addr_o),
 .debug_preg_data_o(debug_preg_data_o),

 .visa_o(visa_o),

 // PMU
 .io_core_pmu_l2_hit_i(1'b0) 
);

localparam NUM_PORTS_ADAPTER = 6;
localparam NUM_PORTS_ADAPTER_WIDTH = $clog2(NUM_PORTS_ADAPTER);
// Adapter HPDC-L1.5 Request Ports type
// 0: Maximum priority 
// NUM_PORTS_ADAPTER - 1 : Less priority 
localparam [NUM_PORTS_ADAPTER_WIDTH-1:0] ICACHE_PORT            = 0;
localparam [NUM_PORTS_ADAPTER_WIDTH-1:0] DCACHE_PORT            = 1;
localparam [NUM_PORTS_ADAPTER_WIDTH-1:0] DCACHE_WBUF_PORT       = 2;
localparam [NUM_PORTS_ADAPTER_WIDTH-1:0] DCACHE_UNC_READ_PORT   = 3;
localparam [NUM_PORTS_ADAPTER_WIDTH-1:0] DCACHE_UNC_WRITE_PORT  = 4;
localparam [NUM_PORTS_ADAPTER_WIDTH-1:0] DCACHE_AMO_PORT        = 5;

typedef logic [NUM_PORTS_ADAPTER_WIDTH-1:0] req_portid_t;

cinco_ranch_hpdcache_subsystem_l15_adapter #(
 .SwapEndianess          (1),
 .NumPorts               (NUM_PORTS_ADAPTER),
 .IcachePort             (ICACHE_PORT),
 .DcachePort             (DCACHE_PORT),
 .DcacheWbufPort         (DCACHE_WBUF_PORT),
 .DcacheUncReadPort      (DCACHE_UNC_READ_PORT),
 .DcacheUncWritePort     (DCACHE_UNC_WRITE_PORT),
 .DcacheAmoPort          (DCACHE_AMO_PORT),
 .IcacheMemDataWidth     (512), //L1I cacheline
 .IcacheAddrWidth        (40),
 .HPDcacheMemDataWidth   (hpdcache_pkg::HPDCACHE_CL_WIDTH), //L1D cacheline
 .IcacheNoCachableSize   (`MSG_DATA_SIZE_8B), // 8B
 .WriteCoalescingEn      (WriteCoalescingEn),
 .hpdcache_mem_req_t     (hpdcache_mem_req_t),
 .hpdcache_mem_req_w_t   (hpdcache_mem_req_w_t),
 .hpdcache_mem_resp_r_t  (hpdcache_mem_resp_r_t),
 .hpdcache_mem_resp_w_t  (hpdcache_mem_resp_w_t),
 .hpdcache_mem_id_t      (hpdcache_mem_id_t),
 .hpdcache_mem_addr_t    (hpdcache_mem_addr_t),
 .req_portid_t           (req_portid_t)
) l15_adapter_inst(

 .clk_i(clk_i),
 .rst_ni(reset_l),

 //  Interfaces from/to I$
 // {{{
 .icache_miss_valid_i(l1_request_valid),
 .icache_miss_ready_o (/*unused*/),
 .icache_miss_paddr_i(l1_request_paddr),

 .icache_miss_resp_valid_o(l2_response_valid),
 .icache_miss_resp_data_o(l2_response_data),
 .icache_inval_valid_o(l2_inval_request),
 .icache_inval_addr_o(l2_inval_addr),
 
 .brom_req_valid_i(brom_req_valid),
 .brom_req_address_i(brom_req_address),
 // }}}

 //  Interfaces from/to D$
 // {{{
 //      Miss-read interface
 .dcache_miss_ready_o(mem_req_miss_read_ready),
 .dcache_miss_valid_i(mem_req_miss_read_valid),
 .dcache_miss_i(mem_req_miss_read),

 .dcache_miss_resp_ready_i(mem_resp_miss_read_ready),
 .dcache_miss_resp_valid_o(mem_resp_miss_read_valid),
 .dcache_miss_resp_o(mem_resp_miss_read),
  // Invalidation interface
 .dcache_inval_valid_o(mem_inval_valid),
 .dcache_inval_o(mem_inval),

 //      Write-buffer write interface
 .dcache_wbuf_ready_o(mem_req_wbuf_write_ready),
 .dcache_wbuf_valid_i(mem_req_wbuf_write_valid),
 .dcache_wbuf_i(mem_req_wbuf_write),

 .dcache_wbuf_data_ready_o(mem_req_wbuf_write_data_ready),
 .dcache_wbuf_data_valid_i(mem_req_wbuf_write_data_valid),
 .dcache_wbuf_data_i(mem_req_wbuf_write_data),

 .dcache_wbuf_resp_ready_i(mem_resp_wbuf_write_ready),
 .dcache_wbuf_resp_valid_o(mem_resp_wbuf_write_valid),
 .dcache_wbuf_resp_o(mem_resp_wbuf_write),

 //      Uncached read interface
 .dcache_uc_read_ready_o(mem_req_uc_read_ready),
 .dcache_uc_read_valid_i(mem_req_uc_read_valid),
 .dcache_uc_read_i(mem_req_uc_read),

 .dcache_uc_read_resp_ready_i(mem_resp_uc_read_ready),
 .dcache_uc_read_resp_valid_o(mem_resp_uc_read_valid),
 .dcache_uc_read_resp_o(mem_resp_uc_read),

 //      Uncached write interface
 .dcache_uc_write_ready_o(mem_req_uc_write_ready),
 .dcache_uc_write_valid_i(mem_req_uc_write_valid),
 .dcache_uc_write_i(mem_req_uc_write),
 
 .dcache_uc_write_data_ready_o(mem_req_uc_write_data_ready),
 .dcache_uc_write_data_valid_i(mem_req_uc_write_data_valid),
 .dcache_uc_write_data_i(mem_req_uc_write_data),

 .dcache_uc_write_resp_ready_i(mem_resp_uc_write_ready),
 .dcache_uc_write_resp_valid_o(mem_resp_uc_write_valid),
 .dcache_uc_write_resp_o(mem_resp_uc_write),
 // }}}

 //    Ports to/from L1.5
 // {{{
 .l15_req_o(l15_req_o),
 .l15_rtrn_i(l15_rtrn_i)
 // }}}
);

endmodule : drac_openpiton_wrapper
