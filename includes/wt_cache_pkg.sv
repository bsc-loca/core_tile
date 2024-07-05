/* -----------------------------------------------
* Project Name   : DRAC
* File           : wt_cache_pkg.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : OScar Lostes Cazorla, Noelia Oliete Escuin
* Email(s)       : oscar.lostes@bsc.es, noelia.oliete@bsc.es
* References     :
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Oscar.LC   |        | Replacement for the original wt_cache_pkg.sv in CVA6
*  0.1        | Noelia OE  |        | Replacement for the original wt_cache_pkg.sv in CVA6
* -----------------------------------------------
*/

package wt_cache_pkg;

`include "l15.tmp.h"
//import sargantana_icache_pkg::*;

`ifndef CONFIG_L15_ASSOCIATIVITY
    `define CONFIG_L15_ASSOCIATIVITY 4
`endif

`ifndef L15_THREADID_WIDTH
    // this results in 8 pending tx slots in the writebuffer
    `define L15_THREADID_WIDTH 3
`endif

`ifndef TLB_CSM_WIDTH
    `define TLB_CSM_WIDTH 33
`endif
  localparam L1_MAX_DATA_PACKETS                = `L1_MAX_DATA_PACKETS;
  localparam L1_MAX_DATA_PACKETS_BITS_WIDTH     = `L1_MAX_DATA_PACKETS_BITS_WIDTH;
  localparam L15_SET_ASSOC                      = `CONFIG_L15_ASSOCIATIVITY;
  localparam L15_TID_WIDTH                      = `L15_THREADID_WIDTH;
  localparam L15_TLB_CSM_WIDTH                  = `TLB_CSM_WIDTH;
  localparam L15_WAY_WIDTH                      = $clog2(L15_SET_ASSOC);
  localparam DCACHE_SET_ASSOC                   = `CONFIG_L1D_ASSOCIATIVITY;
  localparam L1D_WAY_WIDTH                      = $clog2(DCACHE_SET_ASSOC);
  localparam L15_BYTE_MASK_WIDHT                = `L15_BYTE_MASK_WIDHT;
  localparam L15_PADDR_WIDTH                    = `L15_PADDR_WIDTH;

typedef enum logic [4:0] {
  L15_LOAD_RQ     = 5'b00000, // load request
  L15_IMISS_RQ    = 5'b10000, // instruction fill request
  L15_STORE_RQ    = 5'b00001, // store request
  L15_ATOMIC_RQ   = 5'b00110, // atomic op
  //L15_CAS1_RQ     = 5'b00010, // compare and swap1 packet (OpenSparc atomics)
  //L15_CAS2_RQ     = 5'b00011, // compare and swap2 packet (OpenSparc atomics)
  //L15_SWAP_RQ     = 5'b00110, // swap packet (OpenSparc atomics)
  L15_STRLOAD_RQ  = 5'b00100, // unused
  L15_STRST_RQ    = 5'b00101, // unused
  L15_STQ_RQ      = 5'b00111, // unused
  L15_INT_RQ      = 5'b01001, // interrupt request
  L15_FWD_RQ      = 5'b01101, // unused
  L15_FWD_RPY     = 5'b01110, // unused
  L15_RSVD_RQ     = 5'b11111  // unused
} l15_reqtypes_t;

// from l1.5 (only marked subset is used)
typedef enum logic [3:0] {
  L15_LOAD_RET               = 4'b0000, // load packet
  // L15_INV_RET                = 4'b0011, // invalidate packet, not unique...
  L15_ST_ACK                 = 4'b0100, // store ack packet
  //L15_AT_ACK                 = 4'b0011, // unused, not unique...
  L15_INT_RET                = 4'b0111, // interrupt packet
  L15_TEST_RET               = 4'b0101, // unused
  L15_FP_RET                 = 4'b1000, // unused
  L15_IFILL_RET              = 4'b0001, // instruction fill packet
  L15_EVICT_REQ              = 4'b0011, // eviction request
  L15_ERR_RET                = 4'b1100, // unused
  L15_STRLOAD_RET            = 4'b0010, // unused
  L15_STRST_ACK              = 4'b0110, // unused
  L15_FWD_RQ_RET             = 4'b1010, // unused
  L15_FWD_RPY_RET            = 4'b1011, // unused
  L15_RSVD_RET               = 4'b1111, // unused
  L15_CPX_RESTYPE_ATOMIC_RES = 4'b1110  // custom type for atomic responses
} l15_rtrntypes_t;

typedef struct packed {
    logic                              l15_val;                   // valid signal, asserted with request
    logic                              l15_req_ack;               // ack for response
    l15_reqtypes_t                     l15_rqtype;                // see below for encoding
    logic                              l15_nc;                    // non-cacheable bit
    logic [2:0]                        l15_size;                  // transaction size: 000=Byte 001=2Byte; 010=4Byte; 011=8Byte; 111=Cache line (16/32Byte)
    logic [L15_TID_WIDTH-1:0]          l15_threadid;              // currently 0 or 1
    logic                              l15_prefetch;              // unused in openpiton
    logic                              l15_invalidate_cacheline;  // unused by Ariane as L1 has no ECC at the moment
    logic                              l15_blockstore;            // unused in openpiton
    logic                              l15_blockinitstore;        // unused in openpiton
    logic [L1D_WAY_WIDTH-1:0]          l15_l1rplway;              // way to replace
    logic [39:0]                       l15_address;               // physical address
    logic [`L15_REQ_DATA_WIDTH-1:0]     l15_data;                  // word to write
    logic [63:0]                       l15_data_next_entry;       // unused in Ariane (only used for CAS atomic requests)
    logic [L15_TLB_CSM_WIDTH-1:0]      l15_csm_data;              // unused in Ariane
    logic [3:0]                        l15_amo_op;                // atomic operation type
    logic [L15_BYTE_MASK_WIDHT-1:0]    l15_be;                    // Byte mask
  } l15_req_t;

  typedef struct packed {
    logic                              l15_ack;                   // ack for request struct
    logic                              l15_header_ack;            // ack for request struct
    logic                              l15_val;                   // valid signal for return struct
    l15_rtrntypes_t                    l15_returntype;            // see below for encoding
    logic                              l15_l2miss;                // unused in Ariane
    logic [1:0]                        l15_error;                 // unused in openpiton
    logic                              l15_noncacheable;          // non-cacheable bit
    logic                              l15_atomic;                // asserted in load return and store ack packets of atomic tx
    logic [L15_TID_WIDTH-1:0]          l15_threadid;              // used as transaction ID
    logic                              l15_prefetch;              // unused in openpiton
    logic                              l15_f4b;                   // 4byte instruction fill from I/O space (nc).
    logic [L1_MAX_DATA_PACKETS_BITS_WIDTH-1:0] l15_data;          // data
    logic                              l15_inval_icache_all_way;  // invalidate all ways
    logic                              l15_inval_dcache_all_way;  // unused in openpiton
    logic [L15_PADDR_WIDTH-1:0]        l15_inval_address;         // invalidation address
    logic                              l15_cross_invalidate;      // unused in openpiton
    logic [L1D_WAY_WIDTH-1:0]          l15_cross_invalidate_way;  // unused in openpiton
    logic                              l15_inval_dcache_inval;    // invalidate selected cacheline and way
    logic                              l15_inval_icache_inval;    // unused in openpiton
    logic [L1D_WAY_WIDTH-1:0]          l15_inval_way;             // way to invalidate
    logic                              l15_blockinitstore;        // unused in openpiton
  } l15_rtrn_t;

  // --------------------
  // Atomics
  // --------------------
  typedef enum logic [3:0] {
      AMO_NONE =4'b0000,
      AMO_LR   =4'b0001,
      AMO_SC   =4'b0010,
      AMO_SWAP =4'b0011,
      AMO_ADD  =4'b0100,
      AMO_AND  =4'b0101,
      AMO_OR   =4'b0110,
      AMO_XOR  =4'b0111,
      AMO_MAX  =4'b1000,
      AMO_MAXU =4'b1001,
      AMO_MIN  =4'b1010,
      AMO_MINU =4'b1011,
      AMO_CAS1 =4'b1100, // unused, not part of riscv spec, but provided in OpenPiton
      AMO_CAS2 =4'b1101  // unused, not part of riscv spec, but provided in OpenPiton
  } amo_t;

  // swap endianess in a 64bit word
  function automatic logic[63:0] swendian64(input logic[63:0] in);
    automatic logic[63:0] out;
    for(int k=0; k<64;k+=8)begin
        out[k +: 8] = in[63-k -: 8];
    end
    return out;
  endfunction

  function automatic logic[5:0] trunc_sum_6bits(input [6:0] val_in);
    trunc_sum_6bits = val_in[5:0];
  endfunction

  function automatic logic [5:0] popcnt64 (
    input logic [63:0] in
  );
    logic [5:0] cnt= 0;
    foreach (in[k]) begin
      cnt = trunc_sum_6bits(cnt + 6'(in[k]));
    end
    return cnt;
  endfunction : popcnt64

  function automatic logic [7:0] to_byte_enable8(
    input logic [2:0] offset,
    input logic [1:0] size
  );
    logic [7:0] be;
    be = '0;
    unique case(size)
      2'b00:   be[offset]       = '1; // byte
      2'b01:   be[{offset[2:1], 1'b0} +:2 ]  = '1; // hword
      2'b10:   be[{offset[2], 2'b00} +:4 ]  = '1; // word
      default: be               = '1; // dword
    endcase // size
    return be;
  endfunction : to_byte_enable8

  function automatic logic [3:0] to_byte_enable4(
    input logic [1:0] offset,
    input logic [1:0] size
  );
    logic [3:0] be;
    be = '0;
    unique case(size)
      2'b00:   be[offset]       = '1; // byte
      2'b01:   be[{offset[1], 1'b0} +:2 ]  = '1; // hword
      default: be               = '1; // word
    endcase // size
    return be;
  endfunction : to_byte_enable4

  // openpiton requires the data to be replicated in case of smaller sizes than dwords
  function automatic logic [63:0] repData64(
    input logic [63:0] data,
    input logic [2:0]  offset,
    input logic [1:0]  size
  );
    logic [63:0] out;
    unique case(size)
      2'b00:   for(int k=0; k<8; k++) out[k*8  +: 8]    = data[offset[2:0]*8 +: 8];  // byte
      2'b01:   for(int k=0; k<4; k++) out[k*16 +: 16]   = data[offset[2:1]*8 +: 16]; // hword
      2'b10:   for(int k=0; k<2; k++) out[k*32 +: 32]   = data[offset[2]*8   +: 32]; // word
      default: out   = data; // dword
    endcase // size
    return out;
  endfunction : repData64

  function automatic logic [31:0] repData32(
    input logic [31:0] data,
    input logic [1:0]  offset,
    input logic [1:0]  size
  );
    logic [31:0] out;
    unique case(size)
      2'b00:   for(int k=0; k<4; k++) out[k*8  +: 8]    = data[offset*8 +: 8];  // byte
      2'b01:   for(int k=0; k<2; k++) out[k*16 +: 16]   = data[{offset[1], 1'b0}*8 +: 16]; // hword
      default: out   = data; // word
    endcase // size
    return out;
  endfunction : repData32

  // note: this is openpiton specific. cannot transmit unaligned words.
  // hence we default to individual bytes in that case, and they have to be transmitted
  // one after the other
  function automatic logic [1:0] toSize64(
    input logic  [7:0] be
  );
    logic [1:0] size;
    unique case(be)
      8'b1111_1111:                                           size = 2'b11;  // dword
      8'b0000_1111, 8'b1111_0000:                             size = 2'b10; // word
      8'b1100_0000, 8'b0011_0000, 8'b0000_1100, 8'b0000_0011: size = 2'b01; // hword
      default:                                                size = 2'b00; // individual bytes
    endcase // be
    return size;
  endfunction : toSize64


  function automatic logic [1:0] toSize32(
    input logic  [3:0] be
  );
    logic [1:0] size;
    unique case(be)
      4'b1111:                             size = 2'b10; // word
      4'b1100, 4'b0011:                    size = 2'b01; // hword
      default:                             size = 2'b00; // individual bytes
    endcase // be
    return size;
  endfunction : toSize32


endpackage : wt_cache_pkg
