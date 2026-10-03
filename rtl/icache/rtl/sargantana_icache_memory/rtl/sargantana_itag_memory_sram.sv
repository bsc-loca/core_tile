/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : itag_memory.sv
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


module sargantana_itag_memory_sram
#(
    parameter int unsigned ICACHE_N_WAY     = 4,
    parameter int unsigned TAG_DEPTH        = 64,
    parameter int unsigned TAG_ADDR_WIDHT   = $clog2( TAG_DEPTH ),
    parameter int unsigned TAG_WIDHT        = 20
)
(
    `ifdef INTEL_PHYSICAL_MEM_CTRL
    input  wire [27:0]                             hduspsr_mem_ctrl,
    `endif
    input  logic                                   clk_i      ,
    input  logic                                   rstn_i     ,
    input  logic                [ICACHE_N_WAY-1:0] req_i      ,
    input  logic                                   we_i       ,
    input  logic                                   vbit_i     ,
    input  logic                                   flush_i    ,
    input  logic                   [TAG_WIDHT-1:0] data_i     ,
    input  logic              [TAG_ADDR_WIDHT-1:0] addr_i     ,
    output logic [ICACHE_N_WAY-1:0][TAG_WIDHT-1:0] tag_way_o  , //- one for each way.
    output logic                [ICACHE_N_WAY-1:0] vbit_o       
);

//- To build a memory of tags for each path.

//Valid bit wires
logic [TAG_DEPTH-1:0] vbit_vec [ICACHE_N_WAY-1:0];

//--VALID bit vector
genvar i;
generate
for ( i=0; i<ICACHE_N_WAY; i++ )begin
    always_ff @(posedge clk_i) begin
        if(!rstn_i || flush_i) begin
            vbit_vec[i] <= '0; 
            vbit_o[i] <= '0;
        end else if(req_i[i]) begin
            if(we_i) vbit_vec[i][addr_i] <= vbit_i;
            else vbit_o[i] <= vbit_vec[i][addr_i];
        end
    end
end
endgenerate

    logic [ICACHE_N_WAY-1:0][TAG_WIDHT-1:0] mask;
    logic chip_enable;

    assign chip_enable = |req_i;

    generate
        for (genvar gv_mask = 0; gv_mask < ICACHE_N_WAY; gv_mask++) begin
            assign mask[gv_mask] = {TAG_WIDHT{req_i[gv_mask] & we_i}};
        end
    endgenerate

    sp_ram #(
        .ADDR_WIDTH(TAG_ADDR_WIDHT),
        .DATA_WIDTH(ICACHE_N_WAY * TAG_WIDHT),
        `ifdef SRAM_IP
        .INSTANTIATE_ASIC_MEMORY(1'b1),
        `else
        .INSTANTIATE_ASIC_MEMORY(1'b0),
        `endif
        .INIT_MEMORY_ON_RESET('0) // tag SRAM doesn't need initialization
    ) sram (
        `ifdef INTEL_PHYSICAL_MEM_CTRL
        .INTEL_MEM_CTRL(hduspsr_mem_ctrl),
        `endif
        .SR_ID('0),
        .clk(clk_i),
        .rst_n(rstn_i),
        .clk_en(chip_enable),
        .rdw_en(we_i),
        .addr(addr_i),
        .data_in({ICACHE_N_WAY{data_i}}),
        .data_mask_in(mask),
        .data_out(tag_way_o),
        .srams_rtap_data( /* Unconnected */ ),
        .rtap_srams_bist_command('0),
        .rtap_srams_bist_data('0)
    );

endmodule
