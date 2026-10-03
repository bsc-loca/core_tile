`ifndef BIST_DEFINE_VH
`define BIST_DEFINE_VH

// Specific to OpenPiton, width of the BIST.
// Data width from tap to individual ram.
`define SRAM_WRAPPER_BUS_WIDTH 4

// data reg, specific to Cincoranch specs
`define JTAG_DATA_REQ_WIDTH 320
`define JTAG_DATA_RES_WIDTH 384

// generic BIST defines
`define BIST_OP_WIDTH 4
`define BIST_OP_READ 4'd1
`define BIST_OP_WRITE 4'd2
`define BIST_OP_WRITE_EFUSE 4'd3
`define BIST_OP_SHIFT_DATA 4'd4
`define BIST_OP_SHIFT_ADDRESS 4'd5
`define BIST_OP_SHIFT_ID 4'd6
`define BIST_OP_SHIFT_BSEL 4'd7

`endif