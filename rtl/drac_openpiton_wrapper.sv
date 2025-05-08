/*
 *  Authors       : Oscar Lostes Cazorla, Noelia Oliete Escuin
 *  Creation Date : July, 2023
 *  Description   : Sargantana Wrapper to be used in OpenPiton
 *  History      :
 */

 module drac_openpiton_wrapper
 import drac_pkg::*; import hpdcache_pkg::*; import wt_cache_pkg::*;
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
    // DebugModule address
    parameter logic [64-1:0]             InitDMBase            = 64'h00C0000000,
    parameter logic [64-1:0]             InitDMEnd             = 64'hFFFFFFFFFF,
    // HPDC Write coalescing
    parameter logic                      WriteCoalescingEn     =  0,
    parameter int unsigned               WriteCoalescingTh     =  2

) (
 `ifdef INTEL_PHYSICAL_MEM_CTRL
 input wire [27:0] hduspsr_mem_ctrl,
 input wire [27:0] uhdusplr_mem_ctrl,
 `endif
 input   logic                   clk_i,
 input   logic                   reset_l,     // This is an openpiton-specific name, do not change (hier. paths in TB use this)
 input   logic                   soft_rstn_i, // This is a soft reset used by the DM
 output  logic                   spc_grst_l,  // This is an openpiton-specific name, do not change (hier. paths in TB use this)
 input   logic [63:0]            hart_id_i,
 `ifdef PITON_CINCORANCH
 input   logic [1:0]             boot_main_id_i,
 `endif  // Custom for CincoRanch
 input addr_t                    boot_addr_i,
 `ifdef EXTERNAL_HPM_EVENT_NUM
 input logic [`EXTERNAL_HPM_EVENT_NUM-1: 0]  external_hpm_i,
 `endif
 
 `ifdef INTEL_FSCAN_CTECH
 input logic                             fscan_rstbypen,//AK
 `endif
 output  logic [$size(l15_req_t)-1:0]  l15_req_o,
 input   logic [$size(l15_rtrn_t)-1:0] l15_rtrn_i,

 input logic time_irq_i,
 input logic [63:0] time_i,
 input logic [1:0]  irq_i,
 input logic soft_irq_i,

 // Debug interface
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

 output visa_signals_t       visa_o
);

// Instantiate core configuration

localparam int unsigned L1D_MSHR_WAYS = 2;

localparam drac_cfg_t DracOpenPitonCfg = '{
    NIOSections: NIOSections, // number of IO space sections
    InitIOBase:  InitIOBase, // IO base 0 address after reset
    InitIOEnd:   InitIOEnd, // IO end 0 address after reset

    NMappedSections: NMappedSections, // number of Memory space sections
    InitMappedBase:  InitMappedBase, // Memory base address after reset
    InitMappedEnd:   InitMappedEnd, // Memory end 0 address after reset

    InitBROMBase: InitBROMBase,
    InitBROMEnd: InitBROMEnd,

    DebugProgramBufferBase: InitDMBase,
    DebugProgramBufferEnd: InitDMEnd,

    // DCache Config
    DCacheNumSets: (`CONFIG_L1D_SIZE/`CONFIG_L1D_ASSOCIATIVITY)/(`CONFIG_L1D_CACHELINE_WIDTH/8),
    DCacheNumWays: `CONFIG_L1D_ASSOCIATIVITY,
    DCacheLineWidth: `CONFIG_L1D_CACHELINE_WIDTH,
    DCacheMSHRSets: `L15_NUM_THREADS/L1D_MSHR_WAYS,
    DCacheMSHRWays: L1D_MSHR_WAYS,
    DCacheWBUFSize: 16,
    DCacheWTNotWB: 1,
    DCacheCoalescing: WriteCoalescingEn,
    DCacheWBUFTh: WriteCoalescingTh,
    DCacheRefillFIFODepth: `L15_NUM_THREADS + 32'd10,

    // Memory Interface Config
    MemAddrWidth: 40,
    MemDataWidth: 512,
    MemIDWidth: 8
};

// Declare types for HPDCache memory interface
parameter type hpdcache_mem_addr_t = logic [DracOpenPitonCfg.MemAddrWidth-1:0];
parameter type hpdcache_mem_id_t = logic [DracOpenPitonCfg.MemIDWidth-1:0];
parameter type hpdcache_mem_data_t = logic [DracOpenPitonCfg.MemDataWidth-1:0];
parameter type hpdcache_mem_be_t = logic [DracOpenPitonCfg.MemDataWidth/8-1:0];
parameter type hpdcache_mem_req_t =
    `HPDCACHE_DECL_MEM_REQ_T(hpdcache_mem_addr_t, hpdcache_mem_id_t);
parameter type hpdcache_mem_resp_r_t =
    `HPDCACHE_DECL_MEM_RESP_R_T(hpdcache_mem_id_t, hpdcache_mem_data_t);
parameter type hpdcache_mem_req_w_t =
    `HPDCACHE_DECL_MEM_REQ_W_T(hpdcache_mem_data_t, hpdcache_mem_be_t);
parameter type hpdcache_mem_resp_w_t =
    `HPDCACHE_DECL_MEM_RESP_W_T(hpdcache_mem_id_t);

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
logic                           mem_req_read_ready;
logic                           mem_req_read_valid;
hpdcache_mem_req_t              mem_req_read;

logic                           mem_resp_read_ready;
logic                           mem_resp_read_valid;
hpdcache_mem_resp_r_t           mem_resp_read;

//      Write-buffer write interface
logic                           mem_req_write_ready;
logic                           mem_req_write_valid;
hpdcache_mem_req_t              mem_req_write;

logic                           mem_req_write_data_ready;
logic                           mem_req_write_data_valid;
hpdcache_mem_req_w_t            mem_req_write_data;

logic                           mem_resp_write_ready;
logic                           mem_resp_write_valid;
hpdcache_mem_resp_w_t           mem_resp_write;

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

typedef logic [PHY_ADDR_SIZE-$clog2(DracOpenPitonCfg.DCacheLineWidth / 8)-1:0] hpdcache_nline_t;
hpdcache_nline_t  mem_inval;

function [15:0] trunc_sum_16bits(input [16:0] val_in);
  trunc_sum_16bits = val_in[15:0];
endfunction

logic [15:0] wake_up_cnt_d, wake_up_cnt_q;
logic rst_n;

assign wake_up_cnt_d = (wake_up_cnt_q[$high(wake_up_cnt_q)]) ? wake_up_cnt_q : trunc_sum_16bits(wake_up_cnt_q + 1);

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
`ifdef INTEL_FSCAN_CTECH
wire drac_openpiton_mux_rst_n;
assign drac_openpiton_mux_rst_n = wake_up_cnt_q[$high(wake_up_cnt_q)] & reset_l;
ctech_lib_mux_2to1 drac_openpiton_wrapper_reset_mux (.d1(reset_l),.d2(drac_openpiton_mux_rst_n),.s(fscan_rstbypen),.o(rst_n));
`else
assign rst_n = wake_up_cnt_q[$high(wake_up_cnt_q)] & reset_l;
`endif // INTEL_FSCAN_CTECH

top_tile #(
  .DracCfg(DracOpenPitonCfg)
) core_inst (
 `ifdef INTEL_PHYSICAL_MEM_CTRL
 .hduspsr_mem_ctrl   (hduspsr_mem_ctrl),
 .uhdusplr_mem_ctrl  (uhdusplr_mem_ctrl),
 `endif
 .clk_i(clk_i),
 .rstn_i(rst_n),
 .soft_rstn_i(soft_rstn_i),
 `ifdef INTEL_FSCAN_CTECH
 .fscan_rstbypen(fscan_rstbypen),//AK
 `endif // INTEL_FSCAN_CTECH
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
 .mem_req_read_ready_i(mem_req_read_ready),
 .mem_req_read_valid_o(mem_req_read_valid),
 .mem_req_read_o(mem_req_read),

 .mem_resp_read_ready_o(mem_resp_read_ready),
 .mem_resp_read_valid_i(mem_resp_read_valid),
 .mem_resp_read_i(mem_resp_read),

 // dMem writeback interface
 .mem_req_write_ready_i(mem_req_write_ready),
 .mem_req_write_valid_o(mem_req_write_valid),
 .mem_req_write_o(mem_req_write),

 .mem_req_write_data_ready_i(mem_req_write_data_ready),
 .mem_req_write_data_valid_o(mem_req_write_data_valid),
 .mem_req_write_data_o(mem_req_write_data),

 .mem_resp_write_ready_o(mem_resp_write_ready),
 .mem_resp_write_valid_i(mem_resp_write_valid),
 .mem_resp_write_i(mem_resp_write),

 // Invalidation interface
 .mem_inval_valid_i(mem_inval_valid),
 .mem_inval_i(mem_inval),

 .time_irq_i(time_irq_i),
 .irq_i(irq_i),
 .soft_irq_i(soft_irq_i),
 .time_i(time_i),

 // Debug donnections
 .debug_contr_halt_req_i(debug_contr_halt_req_i),
 .debug_contr_resume_req_i(debug_contr_resume_req_i),
 .debug_contr_progbuf_req_i(debug_contr_progbuf_req_i),
 .debug_contr_halt_on_reset_i(debug_contr_halt_on_reset_i),

 .debug_reg_rnm_read_en_i(debug_reg_rnm_read_en_i),
 .debug_reg_rnm_read_reg_i(debug_reg_rnm_read_reg_i),
 .debug_reg_rf_en_i(debug_reg_rf_en_i),
 .debug_reg_rf_preg_i(debug_reg_rf_preg_i),
 .debug_reg_rf_we_i(debug_reg_rf_we_i),
 .debug_reg_rf_wdata_i(debug_reg_rf_wdata_i),

 .debug_contr_halt_ack_o(debug_contr_halt_ack_o),
 .debug_contr_halted_o(debug_contr_halted_o),
 .debug_contr_resume_ack_o(debug_contr_resume_ack_o),
 .debug_contr_running_o(debug_contr_running_o),
 .debug_contr_progbuf_ack_o(debug_contr_progbuf_ack_o),
 .debug_contr_parked_o(debug_contr_parked_o),
 .debug_contr_unavail_o(debug_contr_unavail_o),
 .debug_contr_progbuf_xcpt_o(debug_contr_progbuf_xcpt_o),
 .debug_contr_havereset_o(debug_contr_havereset_o),

 .debug_reg_rnm_read_resp_o(debug_reg_rnm_read_resp_o),
 .debug_reg_rf_rdata_o(debug_reg_rf_rdata_o),

 .visa_o(visa_o),

 // PMU
 .io_core_pmu_l2_hit_i(1'b0) 
);

localparam int unsigned NUM_PORTS_ADAPTER = 4; // iCache + dCache reads + dCache writes + AMOs
localparam int unsigned NUM_PORTS_ADAPTER_WIDTH = $clog2(NUM_PORTS_ADAPTER);
// Adapter HPDC-L1.5 Request Ports type
// 0: Maximum priority
// NUM_PORTS_ADAPTER - 1 : Less priority
localparam [NUM_PORTS_ADAPTER_WIDTH-1:0] ICACHE_PORT       = 0;
localparam [NUM_PORTS_ADAPTER_WIDTH-1:0] DCACHE_READ_PORT  = 1;
localparam [NUM_PORTS_ADAPTER_WIDTH-1:0] DCACHE_WRITE_PORT = 2;
localparam [NUM_PORTS_ADAPTER_WIDTH-1:0] DCACHE_AMO_PORT   = 3;

typedef logic [NUM_PORTS_ADAPTER_WIDTH-1:0] req_portid_t;

cinco_ranch_hpdcache_subsystem_l15_adapter #(
 .SwapEndianess          (1),
 .NumPorts               (NUM_PORTS_ADAPTER),
 .IcachePort             (ICACHE_PORT),
 .DcacheReadPort         (DCACHE_READ_PORT),
 .DcacheWritePort        (DCACHE_WRITE_PORT),
 .DcacheAmoPort          (DCACHE_AMO_PORT),
 .IcacheMemDataWidth     (512), //L1I cacheline
 .IcacheAddrWidth        (40),
 .HPDcacheMemDataWidth   (DracOpenPitonCfg.MemDataWidth), //L1D cacheline
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
 .dcache_read_ready_o(mem_req_read_ready),
 .dcache_read_valid_i(mem_req_read_valid),
 .dcache_read_i(mem_req_read),

 .dcache_read_resp_ready_i(mem_resp_read_ready),
 .dcache_read_resp_valid_o(mem_resp_read_valid),
 .dcache_read_resp_o(mem_resp_read),
  // Invalidation interface
 .dcache_inval_valid_o(mem_inval_valid),
 .dcache_inval_o(mem_inval),

 //      Write-buffer write interface
 .dcache_write_ready_o(mem_req_write_ready),
 .dcache_write_valid_i(mem_req_write_valid),
 .dcache_write_i(mem_req_write),

 .dcache_write_data_ready_o(mem_req_write_data_ready),
 .dcache_write_data_valid_i(mem_req_write_data_valid),
 .dcache_write_data_i(mem_req_write_data),

 .dcache_write_resp_ready_i(mem_resp_write_ready),
 .dcache_write_resp_valid_o(mem_resp_write_valid),
 .dcache_write_resp_o(mem_resp_write),
 // }}}

 //    Ports to/from L1.5
 // {{{
 .l15_req_o(l15_req_o),
 .l15_rtrn_i(l15_rtrn_i)
 // }}}
);

endmodule : drac_openpiton_wrapper
