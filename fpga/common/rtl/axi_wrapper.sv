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

import fpga_pkg::*, hpdcache_pkg::*;

module axi_wrapper (
    input logic clk_i,
    input logic rstn_i,

    AXI_BUS.Master axi_o,

    input logic time_irq_i,
    input logic [63:0] time_i
);

    // Bootrom wires
    logic [23:0] brom_req_address;
    logic brom_req_valid;
    logic brom_ready;
    logic [31:0] brom_resp_data;
    logic brom_resp_valid;

    // icache wires
    logic l1_request_valid;
    logic l2_response_valid;
    logic [25:0] l1_request_paddr;
    logic [511:0] l2_response_data;
    logic [1:0] l2_response_seqnum;

    //      Miss read interface
    logic                           mem_req_miss_read_ready;
    logic                           mem_req_miss_read_valid;
    sargantana_hpdc_pkg::hpdcache_mem_req_t    mem_req_miss_read;
    sargantana_hpdc_pkg::hpdcache_mem_id_t     mem_req_miss_read_base_id;

    logic                           mem_resp_miss_read_ready;
    logic                           mem_resp_miss_read_valid;
    sargantana_hpdc_pkg::hpdcache_mem_resp_r_t mem_resp_miss_read;

    //      Write-buffer write interface
    logic                           mem_req_wbuf_write_ready;
    logic                           mem_req_wbuf_write_valid;
    sargantana_hpdc_pkg::hpdcache_mem_req_t    mem_req_wbuf_write;
    sargantana_hpdc_pkg::hpdcache_mem_id_t     mem_req_wbuf_write_base_id;

    logic                           mem_req_wbuf_write_data_ready;
    logic                           mem_req_wbuf_write_data_valid;
    sargantana_hpdc_pkg::hpdcache_mem_req_w_t  mem_req_wbuf_write_data;

    logic                           mem_resp_wbuf_write_ready;
    logic                           mem_resp_wbuf_write_valid;
    sargantana_hpdc_pkg::hpdcache_mem_resp_w_t mem_resp_wbuf_write;

    //      Uncached read interface
    logic                           mem_req_uc_read_ready;
    logic                           mem_req_uc_read_valid;
    sargantana_hpdc_pkg::hpdcache_mem_req_t    mem_req_uc_read;
    sargantana_hpdc_pkg::hpdcache_mem_id_t     mem_req_uc_read_base_id;

    logic                           mem_resp_uc_read_ready;
    logic                           mem_resp_uc_read_valid;
    sargantana_hpdc_pkg::hpdcache_mem_resp_r_t mem_resp_uc_read;

    //      Uncached write interface
    logic                           mem_req_uc_write_ready;
    logic                           mem_req_uc_write_valid;
    sargantana_hpdc_pkg::hpdcache_mem_req_t    mem_req_uc_write;
    sargantana_hpdc_pkg::hpdcache_mem_id_t     mem_req_uc_write_base_id;

    logic                           mem_req_uc_write_data_ready;
    logic                           mem_req_uc_write_data_valid;
    sargantana_hpdc_pkg::hpdcache_mem_req_w_t  mem_req_uc_write_data;

    logic                           mem_resp_uc_write_ready;
    logic                           mem_resp_uc_write_valid;
    sargantana_hpdc_pkg::hpdcache_mem_resp_w_t mem_resp_uc_write;

    top_tile core_inst (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .soft_rstn_i(rstn_i),
        .debug_halt_i(0),
        .reset_addr_i('h00000100),

        // Bootrom ports
        .brom_ready_i(brom_ready),
        .brom_resp_data_i(brom_resp_data),
        .brom_resp_valid_i(brom_resp_valid),
        .brom_req_address_o(brom_req_address),
        .brom_req_valid_o(brom_req_valid),

        // icache ports
        .io_mem_acquire_valid(l1_request_valid),
        .io_mem_acquire_bits_addr_block(l1_request_paddr),
        .io_mem_grant_valid(l2_response_valid),
        .io_mem_grant_bits_data(l2_response_data),
        .io_mem_grant_bits_addr_beat(l2_response_seqnum),

        // dmem ports

        // dMem miss-read interface
        .mem_req_miss_read_ready_i(mem_req_miss_read_ready),
        .mem_req_miss_read_valid_o(mem_req_miss_read_valid),
        .mem_req_miss_read_o(mem_req_miss_read),
        .mem_req_miss_read_base_id_i(mem_req_miss_read_base_id),

        .mem_resp_miss_read_ready_o(mem_resp_miss_read_ready),
        .mem_resp_miss_read_valid_i(mem_resp_miss_read_valid),
        .mem_resp_miss_read_i(mem_resp_miss_read),

        // dMem writeback interface
        .mem_req_wbuf_write_ready_i(mem_req_wbuf_write_ready),
        .mem_req_wbuf_write_valid_o(mem_req_wbuf_write_valid),
        .mem_req_wbuf_write_o(mem_req_wbuf_write),
        .mem_req_wbuf_write_base_id_i(mem_req_wbuf_write_base_id),

        .mem_req_wbuf_write_data_ready_i(mem_req_wbuf_write_data_ready),
        .mem_req_wbuf_write_data_valid_o(mem_req_wbuf_write_data_valid),
        .mem_req_wbuf_write_data_o(mem_req_wbuf_write_data),

        .mem_resp_wbuf_write_ready_o(mem_resp_wbuf_write_ready),
        .mem_resp_wbuf_write_valid_i(mem_resp_wbuf_write_valid),
        .mem_resp_wbuf_write_i(mem_resp_wbuf_write),

        // dMem uncacheable write interface
        .mem_req_uc_write_ready_i(mem_req_uc_write_ready),
        .mem_req_uc_write_valid_o(mem_req_uc_write_valid),
        .mem_req_uc_write_o(mem_req_uc_write),
        .mem_req_uc_write_base_id_i(mem_req_uc_write_base_id),

        .mem_req_uc_write_data_ready_i(mem_req_uc_write_data_ready),
        .mem_req_uc_write_data_valid_o(mem_req_uc_write_data_valid),
        .mem_req_uc_write_data_o(mem_req_uc_write_data),

        .mem_resp_uc_write_ready_o(mem_resp_uc_write_ready),
        .mem_resp_uc_write_valid_i(mem_resp_uc_write_valid),
        .mem_resp_uc_write_i(mem_resp_uc_write),

        // dMem uncacheable read interface
        .mem_req_uc_read_ready_i(mem_req_uc_read_ready),
        .mem_req_uc_read_valid_o(mem_req_uc_read_valid),
        .mem_req_uc_read_o(mem_req_uc_read),
        .mem_req_uc_read_base_id_i(mem_req_uc_read_base_id),

        .mem_resp_uc_read_ready_o(mem_resp_uc_read_ready),
        .mem_resp_uc_read_valid_i(mem_resp_uc_read_valid),
        .mem_resp_uc_read_i(mem_resp_uc_read),

        .time_irq_i(time_irq_i),
        .irq_i(1'b0),
        .time_i(time_i)
    );

    bootrom brom(
        .clk(clk_i),
        .rstn(rstn_i),
        .brom_req_address_i(brom_req_address),
        .brom_req_valid_i(brom_req_valid),
        .brom_ready_o(brom_ready),
        .brom_resp_data_o(brom_resp_data),
        .brom_resp_valid_o(brom_resp_valid)
    );

    fpga_pkg::core_axi_req_t axi_req;
    fpga_pkg::core_axi_resp_t axi_resp;

    // Ojo! This breaks if hpdcache_pkg::HPDCACHE_MEM_TID_WIDTH <= (clog2(num_sets) + clog2(num_ways))!!!!
    assign mem_req_uc_read_base_id = '1;
    assign mem_req_uc_write_base_id = '1;

    axi_arbiter axi_arbiter_inst(
        .clk_i(clk_i),
        .rst_ni(rstn_i),

        // *** iCache ***

        .icache_miss_valid_i(l1_request_valid),
        .icache_miss_paddr_i(l1_request_paddr),
        .icache_miss_id_i(1 << (sargantana_hpdc_pkg::HPDCACHE_MEM_TID_WIDTH - 1)),

        .icache_miss_resp_valid_o(l2_response_valid),
        .icache_miss_resp_data_o(l2_response_data),
        .icache_miss_resp_beat_o(l2_response_seqnum),

        // *** dCache ***

        //      Miss-read interface
        .dcache_miss_ready_o(mem_req_miss_read_ready),
        .dcache_miss_valid_i(mem_req_miss_read_valid),
        .dcache_miss_i(mem_req_miss_read),

        .dcache_miss_resp_ready_i(mem_resp_miss_read_ready),
        .dcache_miss_resp_valid_o(mem_resp_miss_read_valid),
        .dcache_miss_resp_o(mem_resp_miss_read),

        //      Write-buffer write interface
        .dcache_wbuf_ready_o(mem_req_wbuf_write_ready),
        .dcache_wbuf_valid_i(mem_req_wbuf_write_valid),
        .dcache_wbuf_i(mem_req_wbuf_write),

        .dcache_wbuf_data_ready_o(mem_req_wbuf_write_data_ready),
        .dcache_wbuf_data_valid_i(mem_req_wbuf_write_data_valid),
        .dcache_wbuf_data_i(mem_req_wbuf_write_data),

        .dcache_wbuf_resp_ready_i(mem_resp_wbuf_write_ready),
        .dcache_wbuf_resp_valid_o(mem_resp_wbuf_write_valid),
        .dcache_wbuf_resp_o(mem_resp_wbuf_write),

        //      Uncached read interface
        .dcache_uc_read_ready_o(mem_req_uc_read_ready),
        .dcache_uc_read_valid_i(mem_req_uc_read_valid),
        .dcache_uc_read_i(mem_req_uc_read),
        .dcache_uc_read_id_i(mem_req_uc_read_base_id),

        .dcache_uc_read_resp_ready_i(mem_resp_uc_read_ready),
        .dcache_uc_read_resp_valid_o(mem_resp_uc_read_valid),
        .dcache_uc_read_resp_o(mem_resp_uc_read),

        //      Uncached write interface
        .dcache_uc_write_ready_o(mem_req_uc_write_ready),
        .dcache_uc_write_valid_i(mem_req_uc_write_valid),
        .dcache_uc_write_i(mem_req_uc_write),
        .dcache_uc_write_id_i(mem_req_uc_write_base_id),

        .dcache_uc_write_data_ready_o(mem_req_uc_write_data_ready),
        .dcache_uc_write_data_valid_i(mem_req_uc_write_data_valid),
        .dcache_uc_write_data_i(mem_req_uc_write_data),

        .dcache_uc_write_resp_ready_i(mem_resp_uc_write_ready),
        .dcache_uc_write_resp_valid_o(mem_resp_uc_write_valid),
        .dcache_uc_write_resp_o(mem_resp_uc_write),

        //  AXI port to upstream memory/peripherals
        .axi_req_o(axi_req),
        .axi_resp_i(axi_resp)
    );

    AXI_BUS #(
        .AXI_ADDR_WIDTH (64),
        .AXI_DATA_WIDTH (sargantana_hpdc_pkg::HPDCACHE_MEM_DATA_WIDTH),
        .AXI_ID_WIDTH   (sargantana_hpdc_pkg::HPDCACHE_MEM_TID_WIDTH),
        .AXI_USER_WIDTH (11)
    ) axi_core_to_atomic();

    `AXI_ASSIGN_FROM_REQ(axi_core_to_atomic, axi_req)
    `AXI_ASSIGN_TO_RESP(axi_resp, axi_core_to_atomic)

    AXI_BUS #(
        .AXI_ADDR_WIDTH (64),
        .AXI_DATA_WIDTH (sargantana_hpdc_pkg::HPDCACHE_MEM_DATA_WIDTH),
        .AXI_ID_WIDTH   (sargantana_hpdc_pkg::HPDCACHE_MEM_TID_WIDTH),
        .AXI_USER_WIDTH (11)
    ) axi_atomic_to_fpga();

    axi_riscv_atomics_wrap #(
        .AXI_ADDR_WIDTH(64),
        .AXI_DATA_WIDTH(sargantana_hpdc_pkg::HPDCACHE_MEM_DATA_WIDTH),
        .AXI_ID_WIDTH(sargantana_hpdc_pkg::HPDCACHE_MEM_TID_WIDTH),
        .AXI_USER_WIDTH(11),
        .AXI_MAX_READ_TXNS(1),
        .AXI_MAX_WRITE_TXNS(1),
        .RISCV_WORD_WIDTH(64)
    ) atomics_processor (
        .clk_i(clk_i),
        .rst_ni(rstn_i),
        .mst(axi_o),
        .slv(axi_core_to_atomic)
    );

endmodule
