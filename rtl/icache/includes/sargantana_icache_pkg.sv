/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : sargantana_icache_pkg.sv
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

package sargantana_icache_pkg;

import drac_pkg::*;

//------------------------------------------------ Global Configuration

`ifdef ICACHE_32B
    localparam int unsigned ICACHE_MEM_BLOCK = 32 ; //32 Bytes
`else
    localparam int unsigned ICACHE_MEM_BLOCK = 64 ; //64 Bytes
`endif 
localparam int unsigned ICACHE_SIZE  = 16  ; // Total size in KB 
localparam int unsigned ASSOCIATIVE  = 4   ; // Associativity

//------------------------------------------------
localparam int unsigned SET_WIDHT    = ICACHE_MEM_BLOCK*8 ; //- Cache line
localparam int unsigned ICACHE_DEPTH = (((ICACHE_SIZE*1024)/ASSOCIATIVE)/ICACHE_MEM_BLOCK) ;

localparam int unsigned ICACHE_N_WAY = ASSOCIATIVE  ; //- Number of ways.
localparam int unsigned ICACHE_N_WAY_CLOG2 = $clog2( ICACHE_N_WAY );
localparam int unsigned TAG_DEPTH    = ICACHE_DEPTH            ; //- .
localparam int unsigned ADDR_WIDHT   = $clog2( ICACHE_DEPTH )  ; //- icache Addr vector
localparam int unsigned TAG_ADDR_WIDHT = $clog2( TAG_DEPTH )   ; //- 
localparam int unsigned WAY_WIDHT    = SET_WIDHT               ; //- 

localparam int unsigned ICACHE_OFFSET_WIDTH = $clog2(SET_WIDHT/8); // align to 64bytes
localparam int unsigned ICACHE_INDEX_WIDTH  = $clog2(ICACHE_DEPTH) + ICACHE_OFFSET_WIDTH;

localparam int unsigned PPN_BIT_SIZE    = drac_pkg::PHY_ADDR_SIZE - ICACHE_INDEX_WIDTH;
localparam int unsigned TAG_WIDHT       = drac_pkg::PHY_ADDR_SIZE - ICACHE_INDEX_WIDTH; //- Tag size.
localparam int unsigned VADDR_SIZE      = drac_pkg::VIRT_ADDR_SIZE; // TODO: check this

localparam int unsigned ICACHE_TAG_WIDTH    = TAG_WIDHT;
localparam int unsigned ICACHE_IDX_WIDTH    = ADDR_WIDHT;

`ifdef FETCH_ONE_INST
    localparam int unsigned FETCH_WIDHT = riscv_pkg::INST_SIZE;
`else
    localparam int unsigned FETCH_WIDHT = drac_pkg::ICACHELINE_SIZE;
`endif

//------------------------------------------------------- exception
typedef struct packed {
    logic [63:0] cause;  // cause of exception
    logic [63:0] tval ;  // additional information of causing exception 
                         // (e.g.: instruction causing it),
                         // address of LD/ST fault
    logic        valid;
} xcpt_t;


//--------------------------------------------------------- iCache

typedef struct packed {
    logic                    valid  ;   // we request a new word
    logic                    kill   ;   // kill the current request
    drac_pkg::icache_idx_t             idx;
    drac_pkg::icache_vpn_t             vpn;  
} ireq_i_t;

typedef struct packed {
    logic                    ready;  // icache is ready
    logic                    valid;  // signals a valid read
    logic [FETCH_WIDHT-1 :0] data ;  // 2+ cycle out: tag
    logic   [drac_pkg::PHY_VIRT_MAX_ADDR_SIZE-1:0] vaddr;  // virtual address out
    logic                    xcpt ;  // we've encountered an exception
} iresp_o_t;


typedef enum logic[2:0] {NO_REQ, 
                         READ, 
                         MISS, 
                         TLB_MISS, 
                         REPLAY, 
                         KILL,
                         REPLAY_TLB,
                         KILL_TLB
                     } ictrl_state_t;

//------------------------------------------------------
//------------------------------------------------- MMU
    typedef struct packed {    
        logic                    miss  ;
        logic                    ptw_v ;  // ptw response valid
        logic [PPN_BIT_SIZE-1:0] ppn   ;  // physical address in
        logic                    xcpt  ;  // exception occurred during fetch
    } tresp_i_t;

    typedef struct packed {
        logic                  valid ;       // address translation request
        drac_pkg::icache_vpn_t vpn   ;  
    } treq_o_t;


//------------------------------------------------------
//------------------------------------------------- IFILL
  
typedef struct packed {
    logic                          valid  ; //- valid invalidation and
    logic [ICACHE_INDEX_WIDTH-1:0] paddr  ; //- index to invalidate
} inv_t;
  
  typedef struct packed {
      logic                 valid ; // Valid response
      logic                 ack   ; // IFILL request was received
      logic [SET_WIDHT-1:0] data  ; // Full cache line
      inv_t                 inv   ;
  } ifill_resp_i_t;

  typedef struct packed {
      logic                               valid  ;  // valid request
      logic [drac_pkg::PHY_ADDR_SIZE-1:0] paddr  ;  // physical address
  } ifill_req_o_t;

endpackage

