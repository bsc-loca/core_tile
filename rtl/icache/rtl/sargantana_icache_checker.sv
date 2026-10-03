/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : icache_checker.sv
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



module sargantana_icache_checker
#(
    parameter logic LINES_256   = 1'b0,

    parameter int unsigned ICACHE_N_WAY     = 4,
    parameter int unsigned TAG_WIDHT        = 20,
    parameter int unsigned WAY_WIDHT        = 32*8,
    parameter int unsigned FETCH_WIDHT      = 128,

    localparam int unsigned ICACHE_TAG_WIDTH = TAG_WIDHT



)
(
    input  logic    [ICACHE_TAG_WIDTH-1:0] cline_tag_d      , //- From mmu, paddr.
    input  logic        [ICACHE_N_WAY-1:0] way_valid_bits_i ,
    input  logic                   [ 1:0 ] fetch_idx_i      ,    
    output logic        [ICACHE_N_WAY-1:0] cline_hit_o      ,
    output logic         [FETCH_WIDHT-1:0] data_o           ,
    
    input  logic [ICACHE_N_WAY-1:0][TAG_WIDHT-1:0] read_tags_i,
    input  logic [ICACHE_N_WAY-1:0][WAY_WIDHT-1:0] data_rd_i    //- Cache lines read.

);

logic          [$clog2(ICACHE_N_WAY)-1:0] idx      ;
logic [ICACHE_N_WAY-1:0][FETCH_WIDHT-1:0] cline_sel;
    
genvar i;
generate
for (i=0;i<ICACHE_N_WAY;i++) begin : tag_cmp
    assign cline_hit_o[i]  = (read_tags_i[i] == cline_tag_d) & way_valid_bits_i[i];
    assign cline_sel[i]    = chunk_sel(data_rd_i[i],fetch_idx_i);
end
endgenerate

// find valid cache line
sargantana_icache_tzc_idx #(
  .ICACHE_N_WAY ( ICACHE_N_WAY )
) tzc_idx (
    .in_i  ( cline_hit_o  ),
    .way_o ( idx          )
);

function automatic logic [FETCH_WIDHT-1:0] chunk_sel(
    input logic [WAY_WIDHT-1:0] data,
    input logic [1:0] offset
  );
    logic [FETCH_WIDHT-1:0] out;
    if (LINES_256 == 1'b1) begin    // 256b fetch
`ifdef ICACHE_32B
        out = data[255 : 0];
`else
        unique case(offset)
          2'b00,2'b01: out = data[255 : 0];
          2'b10,2'b11: out = data[511 : 256];
          default: out = '0; 
        endcase 
`endif
    end
    else begin              // 128b fetch
`ifdef ICACHE_32B
        unique case(offset[0])
          1'b0:   out = {{128{1'b0}}, data[127 : 0]};
          1'b1:   out = {{128{1'b0}}, data[255 : 128]};
          default: out = '0; 
        endcase 
`else
        unique case(offset)
          2'b00:   out = {{128{1'b0}}, data[127 : 0]};
          2'b01:   out = {{128{1'b0}}, data[255 : 128]};
          2'b10:   out = {{128{1'b0}}, data[383 : 256]};
          2'b11:   out = {{128{1'b0}}, data[511 : 384]};
          default: out = '0; 
        endcase 
`endif
    end
    return out;
endfunction : chunk_sel


assign data_o = cline_hit_o[idx] ? cline_sel[idx] : '0 ;

                                 
endmodule
