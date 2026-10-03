/* -----------------------------------------------
* File           : dp_ram_asic.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Junaid Ahmed; Xabier Abancens
* Email(s)       : {author}@bsc.es
* References     : Openpiton 
* https://github.com/PrincetonUniversity/openpiton 
* -----------------------------------------------
* Revision History
*  Revision   | Author          |  Description
*  0.1        | Junaid Ahmed;   | 
*             | Xabier Abancens | 
* -----------------------------------------------
*/

// Dual port RAM module that instantiates physical memories
// It supports the memories that have been generated for ongoing projects. 
// If a new memory is generated, please add its macro 

module dp_ram_asic #(
    parameter ADDR_WIDTH=1, 
    parameter DATA_WIDTH=1
) (
   input wire rst_n,
   input wire [ADDR_WIDTH-1  : 0]  AA,AB,
   input wire [DATA_WIDTH-1  : 0]  DB,
   input wire [DATA_WIDTH-1  : 0]  BWB,  // Bit enable, 1: write bit enable
   input wire CLKA,CEA,  // 1: read
   input wire CLKB,CEB,  // 1: write
   output wire [DATA_WIDTH-1  : 0]  QA
);   

// ----------------------------------------------------------------------------
// write_bypass on read/write collisions to the same address
// ----------------------------------------------------------------------------
wire                  read_write_collision;
reg                   read_write_collision_r;
reg  [DATA_WIDTH-1:0] mux_data_in_r;
reg  [DATA_WIDTH-1:0] mux_data_mask_in_r;
wire [DATA_WIDTH-1:0] tmp_QA;

// write_bypass on read/write collisions to the same address
//NOTE: keep bypassed data constant until a new read operation arrives!
always_ff @(posedge CLKA) begin
    if(!rst_n) begin
        read_write_collision_r <= 1'b0;
    end else begin
        if (read_write_collision) begin
            read_write_collision_r <= 1'b1;
            mux_data_in_r          <= DB;
            mux_data_mask_in_r     <= BWB;
        end else if (CEA) begin
            read_write_collision_r <= 1'b0;
        end
    end
end


// detect a read/write collision
// assign read_write_collision = (mux_rd_en && mux_wr_en && (mux_rd_addr == mux_wr_addr));
assign read_write_collision = (CEA && CEB && (AA == AB));

// generate the correct output in case of collision
//NOTE: assumes that tmp_QA (read data) is correct for the bits that are not being written
// assign data_out = read_write_collision_r ? ((QA & ~mux_data_mask_in_r) | (mux_data_in_r & mux_data_mask_in_r)) : QA;
assign QA = read_write_collision_r ? ((tmp_QA & ~mux_data_mask_in_r) | (mux_data_in_r & mux_data_mask_in_r)) : tmp_QA;
// ----------------------------------------------------------------------------

localparam DEPTH = 2 ** ADDR_WIDTH;

`ifdef SIMULATION
ASIC_2P_RAM_UNDEF  #(.DEPTH(DEPTH), .DATA_WIDTH(DATA_WIDTH))  UNDEF_RAM();
`endif

endmodule

`ifdef SIMULATION
module ASIC_2P_RAM_UNDEF #(parameter DEPTH = 256, parameter DATA_WIDTH = 32);
    initial begin
        $display("Instance Name: %m");  // Prints the hierarchical instance name
        $error("Parameters: DEPTH: %d, \tDATA_WIDTH: %d", DEPTH, DATA_WIDTH);  // Prints the parameters
        $finish;
    end
endmodule
`endif  // SIMULATION
