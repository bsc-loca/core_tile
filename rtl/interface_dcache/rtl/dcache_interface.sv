/*
 * Copyright 2023 BSC*
 * *Barcelona Supercomputing Center (BSC)
 * 
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 * 
 * Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
 * may not use this file except in compliance with the License, or, at your
 * option, the Apache License version 2.0. You may obtain a copy of the
 * License at
 * 
 * https://solderpad.org/licenses/SHL-2.1/
 * 
 * Unless required by applicable law or agreed to in writing, any work
 * distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */

// Interface with Data Cache. Stores a Memory request until it finishes

module dcache_interface 
    import drac_pkg::*, hpdcache_pkg::*;
(
    input  wire         clk_i,               // Clock
    input  wire         rstn_i,              // Negative Reset Signal

    input logic         en_ld_st_translation_i, // Virtualization enable

    // CPU Interface
    input req_cpu_dcache_t req_cpu_dcache_i,
    output resp_dcache_cpu_t resp_dcache_cpu_o, // Dcache to CPU

    // dCache Interface
    input  logic dcache_ready_i,
    input  logic dcache_valid_i,
    output logic core_req_valid_o,
    output hpdcache_req_t req_dcache_o,
    input  hpdcache_rsp_t rsp_dcache_i,
    input logic wbuf_empty_i,

    // PMU
    output logic dmem_is_store_o,
    output logic dmem_is_load_o
);

logic io_address_space;

assign io_address_space = (req_dcache_o.addr[ADDR_SIZE-1:0] >= req_cpu_dcache_i.io_base_addr) && (req_dcache_o.addr[ADDR_SIZE-1:0] < 40'h80000000);

//-------------------------------------------------------------
// dCache Interface
//-------------------------------------------------------------

assign core_req_valid_o = req_cpu_dcache_i.valid; 

// Memory Operation
always_comb begin
    case(req_cpu_dcache_i.instr_type)
        AMO_LRW,AMO_LRD:     req_dcache_o.op = HPDCACHE_REQ_AMO_LR;
        AMO_SCW,AMO_SCD:     req_dcache_o.op = HPDCACHE_REQ_AMO_SC;
        AMO_SWAPW,AMO_SWAPD: req_dcache_o.op = HPDCACHE_REQ_AMO_SWAP;
        AMO_ADDW,AMO_ADDD:   req_dcache_o.op = HPDCACHE_REQ_AMO_ADD;
        AMO_XORW,AMO_XORD:   req_dcache_o.op = HPDCACHE_REQ_AMO_XOR;
        AMO_ANDW,AMO_ANDD:   req_dcache_o.op = HPDCACHE_REQ_AMO_AND;
        AMO_ORW,AMO_ORD:     req_dcache_o.op = HPDCACHE_REQ_AMO_OR;
        AMO_MINW,AMO_MIND:   req_dcache_o.op = HPDCACHE_REQ_AMO_MIN;
        AMO_MAXW,AMO_MAXD:   req_dcache_o.op = HPDCACHE_REQ_AMO_MAX;
        AMO_MINWU,AMO_MINDU: req_dcache_o.op = HPDCACHE_REQ_AMO_MINU;
        AMO_MAXWU,AMO_MAXDU: req_dcache_o.op = HPDCACHE_REQ_AMO_MAXU;
        LD,LW,LWU,LH,LHU,LB,LBU,FLD,FLW: req_dcache_o.op = HPDCACHE_REQ_LOAD;
        SD,SW,SH,SB,FSW,FSD: req_dcache_o.op = HPDCACHE_REQ_STORE;
        default: req_dcache_o.op = HPDCACHE_REQ_LOAD;
    endcase
end

// Byte-enable
always_comb begin
    if (req_dcache_o.op != HPDCACHE_REQ_LOAD) begin
        case(req_cpu_dcache_i.mem_size)
            4'b0000, 4'b0100: req_dcache_o.be = 8'b00000001 << req_cpu_dcache_i.data_rs1[2:0];
            4'b0001, 4'b0101: req_dcache_o.be = 8'b00000011 << {req_cpu_dcache_i.data_rs1[2:1], 1'b0};
            4'b0010, 4'b0110: req_dcache_o.be = 8'b00001111 << {req_cpu_dcache_i.data_rs1[2], 2'b0};
            default: req_dcache_o.be = 8'b11111111;
        endcase
    end else begin
        req_dcache_o.be = 8'b0;
    end
end 

// Data
always_comb begin
    if (req_dcache_o.op != HPDCACHE_REQ_LOAD) begin
        case(req_cpu_dcache_i.mem_size)
            4'b0000, 4'b0100: req_dcache_o.wdata[0] = req_cpu_dcache_i.data_rs2 << {req_cpu_dcache_i.data_rs1[2:0], 3'b0};
            4'b0001, 4'b0101: req_dcache_o.wdata[0] = req_cpu_dcache_i.data_rs2 << {req_cpu_dcache_i.data_rs1[2:1], 4'b0};
            4'b0010, 4'b0110: req_dcache_o.wdata[0] = req_cpu_dcache_i.data_rs2 << {req_cpu_dcache_i.data_rs1[2],   5'b0};
            4'b0011, 4'b0111: req_dcache_o.wdata[0] = req_cpu_dcache_i.data_rs2;
            default: req_dcache_o.wdata[0] = req_cpu_dcache_i.data_rs2;
        endcase
    end else begin
        req_dcache_o.wdata[0] = '0;
    end
end 

assign req_dcache_o.addr = req_cpu_dcache_i.data_rs1[48:0];
assign req_dcache_o.size = req_cpu_dcache_i.mem_size[2:0];
assign req_dcache_o.sid = 3'b001;
assign req_dcache_o.tid = req_cpu_dcache_i.rd;
assign req_dcache_o.need_rsp = 1'b1;
assign req_dcache_o.uncacheable = io_address_space;

//-------------------------------------------------------------
// CPU Interface
//-------------------------------------------------------------

// Dcache interface to CPU 
assign resp_dcache_cpu_o.valid = dcache_valid_i;
assign resp_dcache_cpu_o.ready = dcache_ready_i;
assign resp_dcache_cpu_o.io_address_space = io_address_space; // This should be done somewhere else...
assign resp_dcache_cpu_o.rd = rsp_dcache_i.tid;
assign resp_dcache_cpu_o.data = rsp_dcache_i.rdata;
assign resp_dcache_cpu_o.ordered = wbuf_empty_i;

//-PMU
assign dmem_is_store_o = (req_dcache_o.op == HPDCACHE_REQ_LOAD) && req_cpu_dcache_i.valid;
assign dmem_is_load_o  = (req_dcache_o.op == HPDCACHE_REQ_STORE) && req_cpu_dcache_i.valid;

endmodule
//`default_nettype wire

