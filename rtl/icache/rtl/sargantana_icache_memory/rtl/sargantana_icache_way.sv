/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : icache_way.sv
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


module sargantana_icache_way 
#(
    parameter int unsigned SET_WIDHT    = 32*8,
    parameter int unsigned ADDR_WIDHT   = 6
)
(
    `ifdef INTEL_PHYSICAL_MEM_CTRL
    input  wire [27:0]            hduspsr_mem_ctrl,
    `endif
    input  logic                  clk_i      ,
    input  logic                  rstn_i     ,
    input  logic                  req_i      ,
    input  logic                  we_i       ,
    input  logic  [SET_WIDHT-1:0] data_i     ,
    input  logic [ADDR_WIDHT-1:0] addr_i     ,
    output logic  [SET_WIDHT-1:0] data_o     
);

    sp_ram #(
        .ADDR_WIDTH(ADDR_WIDHT),
        .DATA_WIDTH(SET_WIDHT),
        `ifdef SRAM_IP
        .INSTANTIATE_ASIC_MEMORY(1'b1),
        `else
        .INSTANTIATE_ASIC_MEMORY(1'b0),
        `endif
        .INIT_MEMORY_ON_RESET('0) // data SRAM doesn't need initialization
    ) sram (
        `ifdef INTEL_PHYSICAL_MEM_CTRL
        .INTEL_MEM_CTRL(hduspsr_mem_ctrl),
        `endif
        .SR_ID('0),
        .clk(clk_i),
        .rst_n(rstn_i),
        .clk_en(req_i),
        .rdw_en(we_i),
        .addr(addr_i),
        .data_in(data_i),
        .data_mask_in({SET_WIDHT{we_i}}),
        .data_out(data_o),
        .srams_rtap_data( /* Unconnected */ ),
        .rtap_srams_bist_command('0),
        .rtap_srams_bist_data('0)
    );

endmodule
