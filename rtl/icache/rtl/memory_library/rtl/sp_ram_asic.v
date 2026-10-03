/* -----------------------------------------------
* File           : sp_ram_asic.v
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

// Single port RAM module that instantiates physical memories
// It supports the memories that have been generated for ongoing projects. 
// If a new memory is generated, please add its macro 

module sp_ram_asic #(
    parameter ADDR_WIDTH=1, 
    parameter DATA_WIDTH=1
) (
   input wire  [ADDR_WIDTH-1  : 0]  A,
   input wire  [DATA_WIDTH-1  : 0]  DI,
   input wire  [DATA_WIDTH-1  : 0]  BW,
   input wire  CLK,CE, RDWEN,  // RDWEN: 1=WR and 0=RD
   output wire [DATA_WIDTH-1  : 0]  DO
);   

localparam DEPTH = 2 ** ADDR_WIDTH;

`ifdef SIMULATION
ASIC_SP_RAM_UNDEF  #(.DEPTH(DEPTH), .DATA_WIDTH(DATA_WIDTH))  UNDEF_RAM ();
`endif

endmodule

`ifdef SIMULATION
module ASIC_SP_RAM_UNDEF #(parameter DEPTH = 256, parameter DATA_WIDTH = 32);
    initial begin
        $display("Instance Name: %m");  // Prints the hierarchical instance name
        $error("Parameters: DEPTH: %d, \tDATA_WIDTH: %d", DEPTH, DATA_WIDTH);  // Prints the parameters
        $finish;
    end
endmodule
`endif  // SIMULATION