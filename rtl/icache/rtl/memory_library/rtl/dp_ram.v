/* -----------------------------------------------
* File           : dp_ram.sv
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

// Toplevel for a dual port RAM
// Instantiates its simulation/FPGA model or 
// ASIC physical memories depending on INSTANTIATE_ASIC_MEMORY parameter
// It includes BIST signals for debugging operations for all cases (sim/FPGA/ASIC): 
// wr and rd from the JTAG through RTAP to any address.
// BIST can be disabled by setting BIST inputs to 0:
// rtap_srams_bist_command = {`BIST_OP_WIDTH{1'b0}}; rtap_srams_bist_data={`SRAM_WRAPPER_BUS_WIDTH{1'b0}}.
// INIT_MEMORY_ON_RESET=1: on reset memory is initialize to zero by writing in each 
// clock cycle to one address. This procedure requires a number of clk cycles that
// are determined by memory's depth: 2^ADDR_WIDTH

`include "bist_define.h"

module dp_ram
#(
    parameter ADDR_WIDTH=1, 
    parameter DATA_WIDTH=1,
    parameter INSTANTIATE_ASIC_MEMORY = 1,
    parameter INIT_MEMORY_ON_RESET = 0,
    parameter SRAM_CHUNK_ID = 8'h00
)(
    input wire [7:0] SR_ID,
    input wire clk,
    input wire rst_n,
    input wire rd_en,
    input wire wr_en,
    input wire  [ADDR_WIDTH-1  : 0]  rd_addr,
    input wire  [ADDR_WIDTH-1  : 0]  wr_addr,
    input wire  [DATA_WIDTH-1  : 0]  data_in,
    input wire  [DATA_WIDTH-1  : 0]  data_mask_in,
    output wire [DATA_WIDTH-1  : 0]  data_out,

    // sram interface
    output wire [`SRAM_WRAPPER_BUS_WIDTH-1:0] srams_rtap_data,
    input wire  [`BIST_OP_WIDTH-1:0] rtap_srams_bist_command,
    input wire  [`SRAM_WRAPPER_BUS_WIDTH-1:0] rtap_srams_bist_data
);

`ifdef PRINT_MEMORY_LIST
  initial begin
    // Print parameters at the start of the simulation
    $display("Instance: %m");
    $display("DP_RAM ADDR_WIDTH: %d", ADDR_WIDTH);
    $display("DP_RAM DATA_WIDTH: %d", DATA_WIDTH);
  end
`endif

reg [ADDR_WIDTH-1:0] mux_rd_addr;
reg [ADDR_WIDTH-1:0] mux_wr_addr;     
reg [DATA_WIDTH-1:0] mux_data_in;     
reg [DATA_WIDTH-1:0] mux_data_mask_in;
reg mux_wr_en;     
reg mux_rd_en;  

wire [DATA_WIDTH-1:0] SRAM_2_BIST_DATA;
wire [512-1:0] BIST_2_SRAM_DATA;
wire [15:0]ADDRESS;
wire BIST_RDWEN;
wire BIST_EN;

wire [`BIST_OP_WIDTH-1:0] BIST_COMMAND;
wire [`SRAM_WRAPPER_BUS_WIDTH-1:0] BIST_DIN;
wire [`SRAM_WRAPPER_BUS_WIDTH-1:0] BIST_DOUT;

assign SRAM_2_BIST_DATA = data_out;
assign BIST_COMMAND = rtap_srams_bist_command;
assign BIST_DIN = rtap_srams_bist_data;
assign srams_rtap_data = BIST_DOUT;

generate if (INSTANTIATE_ASIC_MEMORY == 1) begin
    dp_ram_asic #(
        .ADDR_WIDTH(ADDR_WIDTH), 
        .DATA_WIDTH(DATA_WIDTH)
    ) dp_ram(
       .rst_n (rst_n), // Required for write_bypass on read/write collisions to the same address
       .AA   (mux_rd_addr),
       .AB   (mux_wr_addr),
       .DB   (mux_data_in),
       .BWB  (mux_data_mask_in), 
       .CLKA (clk),
       .CEA  (mux_rd_en), // 1: read
       .CLKB (clk),
       .CEB  (mux_wr_en), // 1: write
       .QA   (data_out)       
    );  
end
else begin
    dp_ram_model #(
        .ADDR_WIDTH(ADDR_WIDTH), 
        .DATA_WIDTH(DATA_WIDTH),
        .BITMASK_WIDTH(DATA_WIDTH)
    ) dp_ram_model (
       .AA   (mux_rd_addr),
       .AB   (mux_wr_addr),
       .DB   (mux_data_in),
       .BWB  (mux_data_mask_in), 
       .CLKA (clk),
       .CEA  (mux_rd_en),
       .RDWENA (1'b1),  //read
       .CLKB (clk),
       .RDWENB (1'b0),  //write
       .CEB  (mux_wr_en),
       .QA   (data_out)        
    );   
end
endgenerate



/////////////////////BIST R/W logic//////////////////////

//registers
reg [3:0]ID_reg, ID_reg_next;      //SRAM ID is set to 4 bits
reg [7:0]BSEL_reg, BSEL_reg_next;  //bit select is set to 8 bits, not used 
reg [15:0]ADDR_reg, ADDR_reg_next; //address is fixed to 16 bits 
reg [`JTAG_DATA_REQ_WIDTH-1:0]DATA_reg;             //receiving data is 320 bits
reg [`JTAG_DATA_RES_WIDTH-1:0]DATA_OUT_reg;         //transmitting data is 384 bits
reg [512-1:0] DATA_reg_next, DATA_OUT_reg_next; //maximum width of an SRAM to resolve lint issues (differen SRAMS has different widths)

reg BIST_RDWEN_reg, BIST_RDWEN_next;
reg BIST_EN_reg, BIST_EN_next;
//wires
reg [3:0] BIST_DOUT_reg, BIST_DOUT_next; //4 bits BIST transmission
//counter variables
reg [6:0]count;
reg [7:0]count_next;

localparam [3:0] 
    IDLE = 4'd0,
    ID   = 4'd1,
    BSEL = 4'd2,
    ADDR = 4'd3,
    READ_WRITE_CHECK = 4'd4,
    READ_SRAM =  4'd5,
    SEND_DATA =  4'd6,
    RECV_DATA =  4'd7,
    WRITE_SRAM = 4'd8;

//state variables
reg [3:0] state, state_next;

always@(posedge clk) begin
   if(!rst_n) 
      state <= IDLE;
   else
      state <= state_next;
end

always@(*) begin
      state_next = state;
      count_next = count;
      BIST_RDWEN_next = BIST_RDWEN_reg; 
      BIST_EN_next    = BIST_EN_reg;
      DATA_reg_next   = DATA_reg; 
      DATA_OUT_reg_next = DATA_OUT_reg; 
      BSEL_reg_next   = BSEL_reg;
      ADDR_reg_next   = ADDR_reg;
      ID_reg_next     = ID_reg;
      BIST_DOUT_next  = BIST_DOUT_reg;
      case(state)
         IDLE: begin
            BIST_RDWEN_next = 0; //RD
            BIST_EN_next    = 0; //NOT EN
            DATA_reg_next   = 0;
            DATA_OUT_reg_next = 0;
            if(BIST_COMMAND == `BIST_OP_SHIFT_ID) begin
               state_next  = ID;
               ID_reg_next = BIST_DIN;
            end
            else begin
               state_next  = IDLE;
               ID_reg_next = 0;
            end
         end
         ID: begin
            if((BIST_COMMAND == `BIST_OP_SHIFT_ID) && ({ID_reg,BIST_DIN} == SR_ID)) //checking SRAM ID
               state_next  = BSEL;
            else
               state_next  = IDLE;
         end
         BSEL: begin
            if(BIST_COMMAND == `BIST_OP_SHIFT_BSEL) begin
               BSEL_reg_next = {BSEL_reg[3:0] , BIST_DIN};
               if(count == 1) begin
                  count_next = 0;
                  if({BSEL_reg[3:0] , BIST_DIN} == SRAM_CHUNK_ID) begin //checking chunk ID
                     state_next = ADDR;
                  end
                  else begin
                     state_next = IDLE;
                  end
               end
               else begin
                  state_next = BSEL;
                  count_next = count + 1'b1;
               end
            end
            else
               state_next = IDLE;
         end
         ADDR: begin
            ADDR_reg_next   = {ADDR_reg[11:0] , BIST_DIN}; //16 bit address collection
            if((count == 3) &&  (BIST_COMMAND == `BIST_OP_SHIFT_ADDRESS)) begin
               state_next   = READ_WRITE_CHECK;
               BIST_EN_next = 1;
               count_next   = 0;
            end
            else if((count < 3) &&  (BIST_COMMAND == `BIST_OP_SHIFT_ADDRESS)) begin
               state_next   = ADDR;
               count_next   = count + 1'b1;
            end
            else
               state_next = IDLE;
         end
         READ_WRITE_CHECK: begin
            if(BIST_COMMAND == `BIST_OP_READ) begin  //read request
               BIST_RDWEN_next = 0;
               state_next      = READ_SRAM;
               count_next      = 0;
            end 
            else if(BIST_COMMAND == `BIST_OP_SHIFT_DATA) begin //write request
               state_next      = RECV_DATA;
               count_next      = 1; //first packet is sampled on clock edge
               DATA_reg_next   = {DATA_reg[(`JTAG_DATA_REQ_WIDTH-4)-1:0],BIST_DIN};  //collecting data for write operation
            end 
            else
               state_next      = IDLE;
         end
         READ_SRAM: begin
            DATA_OUT_reg_next = SRAM_2_BIST_DATA[DATA_WIDTH-1:0]; 
            count_next    = 0;
            state_next     = SEND_DATA;
         end
         SEND_DATA: begin //sending data after reading SRAM to the JTAG (96*4 = 384 bits)
               if((BIST_COMMAND == `BIST_OP_SHIFT_DATA) && (count < 95)) begin
                  BIST_DOUT_next     = DATA_OUT_reg[`JTAG_DATA_RES_WIDTH-1: `JTAG_DATA_RES_WIDTH-4]; //383:380
                  DATA_OUT_reg_next  = {DATA_OUT_reg[(`JTAG_DATA_RES_WIDTH-4)-1:0], 4'b0};  //384 bits data format is used for transmission, 4 MSB bits are shifted out
                  count_next     = count + 1'b1;
                  state_next     = SEND_DATA;
               end 
               else begin
                  state_next     = IDLE;
                  count_next     = 0;
               end
         end
         RECV_DATA: begin
            DATA_reg_next = {DATA_reg[(`JTAG_DATA_REQ_WIDTH-4)-1:0],BIST_DIN};     //320 bits data fromat is used for receiving, 4 new bits at LSB
            if(BIST_COMMAND == `BIST_OP_SHIFT_DATA) begin
               if(count == 79) begin // // 4*80 = 320 bits 
                  state_next = WRITE_SRAM;
                  count_next = 0;
               end
               else begin
                  state_next    = RECV_DATA;
                  count_next    = count + 1'b1;
               end
            end
            else 
                state_next = IDLE;
         end
         WRITE_SRAM:begin
            BIST_RDWEN_next= 1;
            count_next     = 0;
            state_next     = IDLE;
         end
      endcase
end


always@(posedge clk) begin
   if(!rst_n) begin
      BSEL_reg     <= 0;
      ADDR_reg     <= 0;
      count        <= 0;
      BIST_EN_reg  <= 0;
      BIST_RDWEN_reg <= 0;
      BIST_DOUT_reg<= 0;  
      ID_reg       <= 0;
      DATA_reg     <= 0;
      DATA_OUT_reg <= 0;
   end
   else begin
      BSEL_reg       <= BSEL_reg_next;
      ADDR_reg       <= ADDR_reg_next;
      count          <= count_next[6:0];
      BIST_EN_reg    <= BIST_EN_next;
      BIST_RDWEN_reg <= BIST_RDWEN_next;
      BIST_DOUT_reg  <= BIST_DOUT_next;
      ID_reg         <= ID_reg_next;
      DATA_reg       <= DATA_reg_next[`JTAG_DATA_REQ_WIDTH-1:0];      //320 bits data fromat is used for receiving
      DATA_OUT_reg   <= DATA_OUT_reg_next[`JTAG_DATA_RES_WIDTH-1:0];  //384 bits data format is used for transmission
   end
end

assign BIST_DOUT = DATA_OUT_reg[`JTAG_DATA_RES_WIDTH-1: `JTAG_DATA_RES_WIDTH-4];  //383:380, only 4 MSB bits will be transfered at a time
assign BIST_2_SRAM_DATA   = {{320{1'b0}},DATA_reg[`JTAG_DATA_REQ_WIDTH-1:0]};     //making (192+320) = 512 bits (max width) to resolve lint issues
assign ADDRESS    = ADDR_reg;
assign BIST_RDWEN = BIST_RDWEN_reg;
assign BIST_EN    = BIST_EN_reg;



///////////////////MUX and initialization logic///////////////


reg [ADDR_WIDTH-1:0] bist_index;
reg [ADDR_WIDTH  :0] bist_index_next;
reg init_done;
reg init_done_next;

generate 
   if(INIT_MEMORY_ON_RESET == 1) begin
      always @ (posedge clk)
      begin
         if (!rst_n)
         begin
            bist_index <= 0;
            init_done <= 0;
         end
         else
         begin
            bist_index <= bist_index_next[ADDR_WIDTH-1:0];
            init_done <= init_done_next;
         end
      end

      always @ *
      begin
         bist_index_next = init_done ? bist_index : bist_index + 1;
         init_done_next = ((|(~bist_index)) == 0) | init_done;
      end
   end
   else begin
      always @ (posedge clk)
      begin
         bist_index <= 0;
         bist_index_next <= 0;
         init_done <= 1;
         init_done_next <= 0;
      end
   end
endgenerate

// MUX for Init and BIST(RW) Debug, Cache access
always @ *
begin
   if (!init_done)    begin
       mux_rd_addr      = 0;     
       mux_wr_addr      = bist_index;     
       mux_data_in      = {DATA_WIDTH{1'b0}};    
       mux_data_mask_in = {DATA_WIDTH{1'b1}};
       mux_wr_en        = 1'b1;
       mux_rd_en        = 1'b0;       
   end
   else if(BIST_EN) begin
       mux_rd_addr      = ADDRESS[ADDR_WIDTH-1:0];    
       mux_wr_addr      = ADDRESS[ADDR_WIDTH-1:0];    
       mux_data_in      = BIST_2_SRAM_DATA[DATA_WIDTH-1:0];     
       mux_data_mask_in = {DATA_WIDTH{1'b1}};  //BSEL_reg; 
       mux_wr_en        = BIST_RDWEN; 
       mux_rd_en        = ~BIST_RDWEN; 
   end else begin
       mux_rd_addr      = rd_addr;     
       mux_wr_addr      = wr_addr;     
       mux_data_in      = data_in;     
       mux_data_mask_in = data_mask_in;
       mux_wr_en        = wr_en;  
       mux_rd_en        = rd_en;  
   end
end

endmodule
