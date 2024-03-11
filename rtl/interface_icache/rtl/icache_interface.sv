/* -----------------------------------------------
* Project Name   : DRAC
* File           : tb_icache_interface.v
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Guillem Lopez Paradis
* Email(s)       : guillem.lopez@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Guillem.LP | 
* -----------------------------------------------
*/

module icache_interface
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input logic              clk_i,
    input logic              rstn_i,

    // Fetch stage interface - Request packet from fetch_stage
    input req_cpu_icache_t   req_fetch_icache_i,

    // Request input signals from ICache
    input icache_line_t      icache_resp_datablock_i , // ICACHE_RESP_BITS_DATABLOCK
    input logic              icache_resp_valid_i     , // ICACHE_RESP_VALID,
    input logic              icache_req_ready_i      , // ICACHE_REQ_READY,
    input logic              tlb_resp_xcp_if_i       , // TLB_RESP_XCPT_IF,
    input logic              en_translation_i        ,
    // Request output signals to Icache                      
    output logic             icache_invalidate_o     , // ICACHE_INVALIDATE
    output icache_idx_t      icache_req_bits_idx_o   , // ICACHE_REQ_BITS_IDX,
    output logic             icache_req_kill_o       , // ICACHE_REQ_BITS_KILL,
    output reg               icache_req_valid_o      , // ICACHE_REQ_VALID,
    output icache_vpn_t      icache_req_bits_vpn_o   , // ICACHE_REQ_BITS_VPN,
    
    // Fetch stage interface - Request packet icache to fetch
    output resp_icache_cpu_t  resp_icache_fetch_o,
    output logic              req_fetch_ready_o        
    
);


// wire that says if we need to access icache
logic icache_access_needed_int;

// this signal codifies if a new request must be done
// to the icache
logic do_icache_request_int;

reg_addr_t old_pc_req_d, old_pc_req_q;

logic resp_icache_fetch_valid;

// Icache_interface can do request to icache
assign do_icache_request_int = req_fetch_icache_i.valid                &
                               ~req_fetch_icache_i.invalidate_buffer   &
                               icache_req_ready_i                      ;


assign icache_req_bits_vpn_o = req_fetch_icache_i.vaddr[drac_pkg::PHY_VIRT_MAX_ADDR_SIZE-1:12];
assign icache_req_bits_idx_o = req_fetch_icache_i.vaddr[11:0];


assign icache_req_kill_o = req_fetch_icache_i.inval_fetch; // TODO: disabled when is_brom_access??

assign icache_req_valid_o = do_icache_request_int;


assign icache_access_needed_int = req_fetch_icache_i.valid;

// Icache output connections
// when we want to send invalidation of request?
assign icache_invalidate_o = req_fetch_icache_i.invalidate_icache;

// Manage the pc_int_register
always_ff @(posedge clk_i, negedge rstn_i) begin
    if (!rstn_i) begin
        old_pc_req_q <= {PHY_VIRT_MAX_ADDR_SIZE{1'b0}};
    end else begin
        old_pc_req_q <= old_pc_req_d;
    end
end
// old pc is the pc of the last cycle
assign old_pc_req_d = (do_icache_request_int) ? req_fetch_icache_i.vaddr : old_pc_req_q;   



// return the datablock asked
always_comb begin
    if(tlb_resp_xcp_if_i) begin
        resp_icache_fetch_o.data = 32'h0;
    end else begin
        case(old_pc_req_q[3:2])
            2'b00: begin
                resp_icache_fetch_o.data = icache_resp_datablock_i[31:0];
            end
            2'b01: begin
                resp_icache_fetch_o.data = icache_resp_datablock_i[63:32]; 
            end
            2'b10: begin
                resp_icache_fetch_o.data = icache_resp_datablock_i[95:64]; 
            end
            2'b11: begin
                resp_icache_fetch_o.data = icache_resp_datablock_i[127:96]; 
            end
            default: begin
                resp_icache_fetch_o.data = 32'h0;
            end
        endcase
    end
end

assign resp_icache_fetch_valid = (tlb_resp_xcp_if_i) | icache_resp_valid_i;
assign resp_icache_fetch_o.valid =  resp_icache_fetch_valid;
assign resp_icache_fetch_o.instr_page_fault = tlb_resp_xcp_if_i; 
assign req_fetch_ready_o = icache_req_ready_i; 

endmodule
