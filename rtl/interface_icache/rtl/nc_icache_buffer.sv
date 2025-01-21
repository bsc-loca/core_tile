/* -----------------------------------------------
 * Project Name   : OpenPiton + Lagarto
 * File           : nc_icache_buffer.sv
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


module nc_icache_buffer
    import drac_pkg::*, sargantana_icache_pkg::*;
#(
    parameter drac_pkg::drac_cfg_t DRAC_CFG     = drac_pkg::DracDefaultConfig,
    parameter int unsigned L2_DATA_WIDTH = 512,
    parameter int unsigned L2_NC_DATA_WIDTH = 64,
    parameter int unsigned CORE_DATA_WIDTH = 512
) (
    input  logic                              clk_i, rstn_i,

    // Core Request
    input  logic                              en_translation_i,
    input  logic                              core_req_valid_i,
    input  logic [PHY_VIRT_MAX_ADDR_SIZE-1:0] core_req_addr_i,
    input  logic                              core_req_invalidate_i,
    input  logic                              core_req_kill_i,

    // Core Response
    output logic                              core_rsp_nc_busy_o, // Indicates NC request in flight and a new request shouldn't be done
    output logic                              core_rsp_valid_o,   // Output from NC Buffer module is valid
    output logic [CORE_DATA_WIDTH-1:0]        core_rsp_data_o,

    // iCache Request
    output logic                              icache_req_valid_o,

    // L2 Request (L1 Bypass)
    output logic                              req_nc_valid_o,
    output logic  [39:0]                      req_nc_vaddr_o,

    // L2 Response
    input  logic                              l2_grant_valid_i,
    input  logic [L2_DATA_WIDTH-1:0]          l2_resp_data_i
);

localparam int unsigned CORE_TO_NCLINE_WIDTH_RATIO = CORE_DATA_WIDTH/L2_NC_DATA_WIDTH;

logic addr_is_nc            ;
logic req_icache_valid      ;
logic same_addr_req         ;
logic waiting               ;
logic is_in_buffer          ;

logic [39:0] buffer_paddr_d  , buffer_paddr_q  ;
logic [39:0] paddr_infly_d   , paddr_infly_q   ;
logic [L2_NC_DATA_WIDTH-1:0] icache_ncline_d , icache_ncline_q ;

logic req_nc_valid_d , req_nc_valid_q ;
logic nc_kill_d      , nc_kill_q      ;
logic nc_rsp_valid_d , nc_rsp_valid_q ;

logic [31:0] nc_resp_data    ;

typedef enum logic [1:0]{
    idle_nc   = 2'b01,
    wait_nc   = 2'b10,
    kill_nc   = 2'b11
} nc_state_t;

nc_state_t state_nc, next_state_nc;

// --------------------------------------
// Non-Cacheable instruction cache bypass
// --------------------------------------
//For OpenPiton, first we need to verify if the address is inside of a cacheable region
//For non-cacheable regions, we implement a bypaass directly to the NoC.
//In the L1 instruction cache we don't save data from non-cacheable regions.

//------------------------------------------
// Stage 1
//------------------------------------------
assign addr_is_nc = is_inside_IO_sections(DRAC_CFG, {{{64-drac_pkg::PHY_ADDR_SIZE}{1'b0}},core_req_addr_i})
                  | range_check(DRAC_CFG.InitBROMBase, DRAC_CFG.InitBROMEnd, {{{64-PHY_ADDR_SIZE}{1'b0}},core_req_addr_i})
                  | range_check(DRAC_CFG.DebugProgramBufferBase, DRAC_CFG.DebugProgramBufferEnd, {{{64-PHY_ADDR_SIZE}{1'b0}},core_req_addr_i});

// request to the instruccion cache with a cachable address.
assign req_icache_valid = (addr_is_nc & (~en_translation_i)) ? 1'b0 : core_req_valid_i ;

// request of a non-cachable address.
assign req_nc_valid_d = (((addr_is_nc & (~en_translation_i)) & is_inside_mapped_sections(DRAC_CFG, {{{64-drac_pkg::PHY_ADDR_SIZE}{1'b0}},core_req_addr_i})) & (~nc_kill_d)) ? core_req_valid_i : 1'b0 ;

// nc addr in-fly register buffer
assign paddr_infly_d = req_nc_valid_d ? core_req_addr_i : paddr_infly_q ;

// invalidate and kill requests
assign nc_kill_d = core_req_kill_i | core_req_invalidate_i ;

//------------------------------------------
// Stage 2
//------------------------------------------

// the instruction is in the buffer
assign same_addr_req  = paddr_infly_q[39:3] == buffer_paddr_q[39:3] ;
assign is_in_buffer   = req_nc_valid_q & same_addr_req ;

// non-cachable register buffer
assign icache_ncline_d = nc_rsp_valid_d ? l2_resp_data_i[L2_NC_DATA_WIDTH-1:0] : icache_ncline_q;
assign buffer_paddr_d  = nc_kill_q ? '0 : nc_rsp_valid_d ? paddr_infly_q : buffer_paddr_q;

// FSM control
always_comb begin
    case (state_nc)
        idle_nc: begin //01
            req_nc_valid_o = req_nc_valid_q &~ same_addr_req    ;
            next_state_nc  = (req_nc_valid_q & (~same_addr_req)) ? wait_nc : idle_nc ;
            waiting        = req_nc_valid_q &~ same_addr_req    ;
            nc_rsp_valid_d = 1'b0                               ;
        end
        wait_nc: begin //10
            req_nc_valid_o = 1'b0                                   ;
            next_state_nc  = l2_grant_valid_i ? idle_nc : nc_kill_q ? kill_nc : wait_nc   ;
            waiting        = 1'b1                                   ;
            nc_rsp_valid_d = !nc_kill_q && l2_grant_valid_i         ;
        end
        kill_nc: begin //11
            req_nc_valid_o = 1'b0                                   ;
            next_state_nc  = l2_grant_valid_i ? idle_nc : kill_nc   ;
            waiting        = 1'b1                                   ;
            nc_rsp_valid_d = 1'b0                                   ;
        end
        default: begin
            req_nc_valid_o = 1'b0       ;
            next_state_nc  = idle_nc    ;
            waiting        = 1'b0       ;
            nc_rsp_valid_d = 1'b0       ;
        end
    endcase;
end


// non-cacheable request valid to L2
assign req_nc_vaddr_o  = {paddr_infly_q[39:3],3'b0};

// req cached to the instruction cache
assign icache_req_valid_o            = req_icache_valid                 ;

// response nc/cached to the datapath
assign core_rsp_valid_o            = nc_rsp_valid_q | is_in_buffer;
assign core_rsp_nc_busy_o = waiting;
assign core_rsp_data_o = {CORE_TO_NCLINE_WIDTH_RATIO{icache_ncline_q}};

// register
always_ff @(posedge clk_i or negedge rstn_i) begin
    if(~rstn_i) begin
        state_nc        <= idle_nc  ;
        icache_ncline_q <= '0       ;
        buffer_paddr_q  <= '0       ;
        paddr_infly_q   <= '0       ;
        nc_rsp_valid_q  <= '0       ;
        req_nc_valid_q  <= '0       ;
        nc_kill_q       <= '0       ;
    end
    else begin
        state_nc        <= next_state_nc          ;
        icache_ncline_q <= icache_ncline_d        ;
        buffer_paddr_q  <= buffer_paddr_d         ;
        paddr_infly_q   <= paddr_infly_d          ;
        nc_rsp_valid_q  <= nc_rsp_valid_d         ;
        req_nc_valid_q  <= req_nc_valid_d         ;
        nc_kill_q       <= nc_kill_d              ;
    end
end

endmodule
