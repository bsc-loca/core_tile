package sargantana_hpdc_pkg;

import hpdcache_pkg::*;

parameter HPDCACHE_NREQUESTERS = 2; // Core + PTW
`ifdef PITON_ARIANE_HPDC
//parameter HPDCACHE_MEM_TID_WIDTH = 3; // Minimum for the HPDC with single channel to MM, OP can only support `L15_THREADID_WIDTH;
parameter HPDCACHE_MEM_TID_WIDTH = (`L15_THREADID_WIDTH >= 2) ? (`L15_THREADID_WIDTH) : 2; 
parameter HPDCACHE_MEM_WORDS = HPDCACHE_CL_WORDS;
parameter int unsigned HPDCACHE_MEM_DATA_WIDTH = HPDCACHE_MEM_WORDS*HPDCACHE_WORD_WIDTH; // 128 bit memory bus
`else
parameter HPDCACHE_MEM_TID_WIDTH = 8;
parameter HPDCACHE_MEM_WORDS = 8;
parameter int unsigned HPDCACHE_MEM_DATA_WIDTH = HPDCACHE_MEM_WORDS*HPDCACHE_WORD_WIDTH; // 512 bit memory bus
`endif

typedef logic [HPDCACHE_PA_WIDTH-1:0]           hpdcache_mem_addr_t;
typedef logic [HPDCACHE_MEM_TID_WIDTH-1:0]      hpdcache_mem_id_t;
typedef logic [HPDCACHE_MEM_DATA_WIDTH-1:0]     hpdcache_mem_data_t;
typedef logic [HPDCACHE_MEM_DATA_WIDTH/8-1:0]   hpdcache_mem_be_t;

`include "hpdcache_typedef.svh"
`HPDCACHE_TYPEDEF_MEM_REQ_T(hpdcache_mem_req_t, hpdcache_mem_addr_t, hpdcache_mem_id_t);
`HPDCACHE_TYPEDEF_MEM_RESP_R_T(hpdcache_mem_resp_r_t, hpdcache_mem_id_t, hpdcache_mem_data_t);
`HPDCACHE_TYPEDEF_MEM_REQ_W_T(hpdcache_mem_req_w_t, hpdcache_mem_data_t, hpdcache_mem_be_t);
`HPDCACHE_TYPEDEF_MEM_RESP_W_T(hpdcache_mem_resp_w_t, hpdcache_mem_id_t);

endpackage
