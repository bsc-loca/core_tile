/* -------------------------------------------------------
* File           : sp_ram_model.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Junaid Ahmed; Xabier Abancens
* Email(s)       : {author}@bsc.es
* References     : Openpiton 
* https://github.com/PrincetonUniversity/openpiton 
* --------------------------------------------------------
* Revision History
*  Revision   | Author          |  Description
*  0.1        | Junaid Ahmed;   | 
*             | Xabier Abancens | 
*  0.2        | Xabier Abancens | Enable byte_wide write
* --------------------------------------------------------
*/

// Single port RAM model for simulation and FPGA. 
// The memory is mapped to BRAMs for FPGA.

module sp_ram_model #(
    parameter ADDR_WIDTH=1,
    parameter COL_WIDTH = 1,  // Byte-wide write width. Required to map to BRAMs
    parameter DATA_WIDTH=1,
    localparam NUM_COL=DATA_WIDTH/COL_WIDTH
) (
   input wire  [ADDR_WIDTH-1  : 0]  A,
   input wire  [DATA_WIDTH-1  : 0]  DI,
   input wire  [NUM_COL-1     : 0]  BW,
   input wire  CLK,CE, RDWEN,
   output wire [DATA_WIDTH-1  : 0]  DO
);   

  // ----------------------------------------------------------------
  // - DATA_WIDTH must be divisible by COL_WIDTH
  // ----------------------------------------------------------------
  initial begin
    if ((DATA_WIDTH % COL_WIDTH) != 0) begin
       $fatal (1, "Error: DATA_WIDTH must be divisible by COL_WIDTH.");
    end
  end
    
  localparam DEPTH = 2 ** ADDR_WIDTH;
    
  //RDWEN = 1 means write, 0 means read
    
  // SRAM
  reg [DATA_WIDTH-1:0] ram [DEPTH-1:0];
  reg [DATA_WIDTH-1:0] DATA_OUT;

generate
genvar itr_bw;
  for (itr_bw = 0; itr_bw < NUM_COL; itr_bw = itr_bw + 1) begin : BYTE_WIDE_WRITE
    always @(posedge CLK) begin
      if(CE) begin
        if(RDWEN) begin
          if (BW[itr_bw]) begin
            ram[A][itr_bw*COL_WIDTH +: COL_WIDTH] <= DI[itr_bw*COL_WIDTH +: COL_WIDTH];
          end
        end
      end
    end
  end
endgenerate

  always@(posedge CLK) begin
    if(CE) begin
      if(!RDWEN) begin
        DATA_OUT <= ram[A];
      end
    end
  end
    
  assign DO = DATA_OUT;

endmodule