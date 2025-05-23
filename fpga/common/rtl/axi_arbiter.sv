/*
 *  Copyright 2023 CEA*
 *  *Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
 *
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 *  Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
 *  may not use this file except in compliance with the License, or, at your
 *  option, the Apache License version 2.0. You may obtain a copy of the
 *  License at
 *
 *  https://solderpad.org/licenses/SHL-2.1/
 *
 *  Unless required by applicable law or agreed to in writing, any work
 *  distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
 *  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 *  License for the specific language governing permissions and limitations
 *  under the License.
 */
/*
 *  Authors      : Cesar Fuguet, Arnau Bigas
 *  Creation Date: June, 2022
 *  Description  : AXI arbiter for the CVA6 cache subsystem integrating standard
 *                 CVA6's instruction cache and the Core-V High-Performance
*                  L1 Dcache (CV-HPDcache).
 *  History      : July, 2023. Modified for use with Sargantana instead of CVA6.
 *  History      : November, 2024. Modified for use with HPDC v5.0.0, parametrized.
 */

`include "defines.svh"
`include "hpdcache_typedef.svh"

import fpga_pkg::*;

module axi_arbiter
#(
    parameter drac_pkg::drac_cfg_t DracCfg     = drac_pkg::DracDefaultConfig,

    // HPDC Memory Interface Parameters
    parameter type hpdcache_mem_addr_t = logic [DracCfg.MemAddrWidth-1:0],
    parameter type hpdcache_mem_id_t = logic [DracCfg.MemIDWidth-1:0],
    parameter type hpdcache_mem_data_t = logic [DracCfg.MemDataWidth-1:0],
    parameter type hpdcache_mem_be_t = logic [DracCfg.MemDataWidth/8-1:0],
    parameter type hpdcache_mem_req_t =
        `HPDCACHE_DECL_MEM_REQ_T(hpdcache_mem_addr_t, hpdcache_mem_id_t),
    parameter type hpdcache_mem_resp_r_t =
        `HPDCACHE_DECL_MEM_RESP_R_T(hpdcache_mem_id_t, hpdcache_mem_data_t),
    parameter type hpdcache_mem_req_w_t =
        `HPDCACHE_DECL_MEM_REQ_W_T(hpdcache_mem_data_t, hpdcache_mem_be_t),
    parameter type hpdcache_mem_resp_w_t =
        `HPDCACHE_DECL_MEM_RESP_W_T(hpdcache_mem_id_t)
)
(
  input  wire logic                               clk_i,
  input  wire logic                               rst_ni,

  // *** iCache interface ***
  input  wire logic                               icache_miss_valid_i,
  output wire logic                               icache_miss_ready_o,
  input  wire logic [drac_pkg::PHY_ADDR_SIZE-1:0]           icache_miss_paddr_i,
  input  wire hpdcache_mem_id_t         icache_miss_id_i,
  output wire logic                               icache_miss_resp_valid_o,
  output wire logic [511:0]                       icache_miss_resp_data_o,
  output wire logic [1:0]                         icache_miss_resp_beat_o,
  
  // *** dCache interface ***
  output wire logic                               dcache_read_ready_o,
  input  wire logic                               dcache_read_valid_i,
  input  wire hpdcache_mem_req_t        dcache_read_i,

  input  wire logic                               dcache_read_resp_ready_i,
  output wire logic                               dcache_read_resp_valid_o,
  output wire hpdcache_mem_resp_r_t     dcache_read_resp_o,

  //      Write-buffer write interface
  output wire logic                               dcache_write_ready_o,
  input  wire logic                               dcache_write_valid_i,
  input  wire hpdcache_mem_req_t        dcache_write_i,

  output wire logic                               dcache_write_data_ready_o,
  input  wire logic                               dcache_write_data_valid_i,
  input  wire hpdcache_mem_req_w_t      dcache_write_data_i,

  input  wire logic                               dcache_write_resp_ready_i,
  output wire logic                               dcache_write_resp_valid_o,
  output wire hpdcache_mem_resp_w_t     dcache_write_resp_o,

  // *** AXI interface ***
  output fpga_pkg::core_axi_req_t                                axi_req_o,
  input  fpga_pkg::core_axi_resp_t                               axi_resp_i
);

  localparam AxiCacheStrbWidth = DracCfg.MemDataWidth / 8;
  localparam IFILL_WIDTH = 512;

  typedef logic [DracCfg.MemDataWidth-1:0] axi_cache_data_t;
  typedef logic [AxiCacheStrbWidth-1:0] axi_cache_strb_t;
  typedef logic [7:0]    axi_cache_id_t;
  typedef logic [10:0]  axi_cache_user_t;
  typedef logic [63:0]  axi_cache_addr_t;

  `AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, axi_cache_addr_t, axi_cache_id_t, axi_cache_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(ar_chan_t, axi_cache_addr_t, axi_cache_id_t, axi_cache_user_t)
  `AXI_TYPEDEF_B_CHAN_T(b_chan_t, axi_cache_id_t, axi_cache_user_t)

  typedef struct packed {
      axi_cache_data_t      data;
      axi_cache_strb_t      strb;
      logic                 last;
      axi_cache_user_t      user;
  } axi_cache_w_chan_t;

  typedef struct packed {
      axi_cache_id_t        id;
      axi_cache_data_t      data;
      axi_pkg::resp_t       resp;
      logic                 last;
      axi_cache_user_t      user;
  } axi_cache_r_chan_t;

  typedef struct packed {
      aw_chan_t             aw;
      logic                 aw_valid;
      axi_cache_w_chan_t    w;
      logic                 w_valid;
      logic                 b_ready;
      ar_chan_t             ar;
      logic                 ar_valid;
      logic                 r_ready;
  } axi_cache_req_t;

  typedef struct packed {
      logic                 aw_ready;
      logic                 ar_ready;
      logic                 w_ready;
      logic                 b_valid;
      b_chan_t  b;
      logic                 r_valid;
      axi_cache_r_chan_t    r;
  } axi_cache_resp_t;

  localparam int MEM_RESP_RT_DEPTH = (1 << DracCfg.MemIDWidth);
  typedef hpdcache_mem_id_t [MEM_RESP_RT_DEPTH-1:0]  mem_resp_rt_t;
  typedef logic [IFILL_WIDTH-1:0]  icache_resp_data_t;


  localparam int ICACHE_CL_SIZE         = $clog2(IFILL_WIDTH/8);
  localparam int ICACHE_MEM_REQ_CL_LEN  =
    (IFILL_WIDTH + DracCfg.MemDataWidth - 1)/
    DracCfg.MemDataWidth;
  localparam int ICACHE_MEM_REQ_CL_SIZE =
    (DracCfg.MemDataWidth <= IFILL_WIDTH) ?
      $clog2(DracCfg.MemDataWidth/8) :
      ICACHE_CL_SIZE;

  //    I$ request
  hpdcache_mem_req_t  icache_miss_req_wdata;
  logic  icache_miss_req_w, icache_miss_req_wok;

  hpdcache_mem_req_t  icache_miss_req_rdata;
  logic  icache_miss_req_r, icache_miss_req_rok;

  //  This FIFO has two functionnalities:
  //  -  Stabilize the ready-valid protocol. The ICACHE can abort a valid
  //     transaction without receiving the corresponding ready signal. This
  //     behavior is not supported by AXI.
  //  -  Cut a possible long timing path.
  hpdcache_fifo_reg #(
      .FIFO_DEPTH  (1),
      .fifo_data_t (hpdcache_mem_req_t)
  ) i_icache_miss_req_fifo (
      .clk_i,
      .rst_ni,

      .w_i    (icache_miss_req_w),
      .wok_o  (icache_miss_req_wok),
      .wdata_i(icache_miss_req_wdata),

      .r_i    (icache_miss_req_r),
      .rok_o  (icache_miss_req_rok),
      .rdata_o(icache_miss_req_rdata)
  );

  assign icache_miss_req_w   = icache_miss_valid_i,
         icache_miss_ready_o = icache_miss_req_wok;

  assign icache_miss_req_wdata.mem_req_addr      = icache_miss_paddr_i,
         icache_miss_req_wdata.mem_req_len       = 4'h0,
         icache_miss_req_wdata.mem_req_size      = 3'h6,
         icache_miss_req_wdata.mem_req_id        = icache_miss_id_i,
         icache_miss_req_wdata.mem_req_command   = hpdcache_pkg::HPDCACHE_MEM_READ,
         icache_miss_req_wdata.mem_req_atomic    = hpdcache_pkg::hpdcache_mem_atomic_e'(0),
         icache_miss_req_wdata.mem_req_cacheable = 1'b1;


  //    I$ response
  logic                                icache_miss_resp_w, icache_miss_resp_wok;
  hpdcache_mem_resp_r_t      icache_miss_resp_wdata;

  logic                                icache_miss_resp_data_w, icache_miss_resp_data_wok;
  logic                                icache_miss_resp_data_r, icache_miss_resp_data_rok;
  icache_resp_data_t                   icache_miss_resp_data_rdata;

  logic                                icache_miss_resp_meta_w, icache_miss_resp_meta_wok;
  logic                                icache_miss_resp_meta_r, icache_miss_resp_meta_rok;
  hpdcache_mem_id_t          icache_miss_resp_meta_id;

  assign icache_miss_resp_valid_o = icache_miss_resp_data_rok;
  assign icache_miss_resp_data_o = icache_miss_resp_data_rdata;

  generate
   if (DracCfg.MemDataWidth < IFILL_WIDTH) begin
      hpdcache_fifo_reg #(
          .FIFO_DEPTH  (1),
          .fifo_data_t (hpdcache_mem_id_t)
      ) i_icache_refill_meta_fifo (
          .clk_i,
          .rst_ni,

          .w_i    (icache_miss_resp_meta_w),
          .wok_o  (icache_miss_resp_meta_wok),
          .wdata_i(icache_miss_resp_wdata.mem_resp_r_id),

          .r_i    (icache_miss_resp_meta_r),
          .rok_o  (icache_miss_resp_meta_rok),
          .rdata_o(icache_miss_resp_meta_id)
      );

      hpdcache_data_upsize #(
          .WR_WIDTH(DracCfg.MemDataWidth),
          .RD_WIDTH(IFILL_WIDTH),
          .DEPTH(1)
      ) i_icache_hpdcache_data_upsize (
          .clk_i,
          .rst_ni,

          .w_i     (icache_miss_resp_data_w),
          .wlast_i (icache_miss_resp_wdata.mem_resp_r_last),
          .wok_o   (icache_miss_resp_data_wok),
          .wdata_i (icache_miss_resp_wdata.mem_resp_r_data),

          .r_i     (icache_miss_resp_data_r),
          .rok_o   (icache_miss_resp_data_rok),
          .rdata_o (icache_miss_resp_data_rdata)
      );

      assign icache_miss_resp_meta_r = 1'b1,
             icache_miss_resp_data_r = 1'b1;

      assign icache_miss_resp_meta_w = icache_miss_resp_w &
               icache_miss_resp_wdata.mem_resp_r_last;

      assign icache_miss_resp_data_w = icache_miss_resp_w;

      assign icache_miss_resp_wok = icache_miss_resp_data_wok & (
               icache_miss_resp_meta_wok | ~icache_miss_resp_wdata.mem_resp_r_last);

    end else if (DracCfg.MemDataWidth > IFILL_WIDTH) begin

      hpdcache_fifo_reg #(
          .FIFO_DEPTH  (1),
          .fifo_data_t (hpdcache_mem_id_t)
      ) i_icache_refill_meta_fifo (
          .clk_i,
          .rst_ni,

          .w_i    (icache_miss_resp_meta_w),
          .wok_o  (icache_miss_resp_meta_wok),
          .wdata_i(icache_miss_resp_wdata.mem_resp_r_id),

          .r_i    (icache_miss_resp_meta_r),
          .rok_o  (icache_miss_resp_meta_rok),
          .rdata_o(icache_miss_resp_meta_id)
      );

      hpdcache_data_downsize #(
          .WR_WIDTH(DracCfg.MemDataWidth),
          .RD_WIDTH(IFILL_WIDTH),
          .DEPTH(1)
      ) i_icache_hpdcache_data_downsize (
          .clk_i,
          .rst_ni,

          .w_i     (icache_miss_resp_data_w),
          .wok_o   (icache_miss_resp_data_wok),
          .wdata_i (icache_miss_resp_wdata.mem_resp_r_data),

          .r_i     (icache_miss_resp_data_r),
          .rok_o   (icache_miss_resp_data_rok),
          .rdata_o (icache_miss_resp_data_rdata)
      );

      assign icache_miss_resp_meta_r = 1'b1,
             icache_miss_resp_data_r = 1'b1;

      assign icache_miss_resp_meta_w = icache_miss_resp_w &
             icache_miss_resp_wdata.mem_resp_r_last;

      assign icache_miss_resp_data_w = icache_miss_resp_w;

      assign icache_miss_resp_wok = icache_miss_resp_data_wok & (
             icache_miss_resp_meta_wok | ~icache_miss_resp_wdata.mem_resp_r_last);

      logic [1:0] icache_beat;
      assign icache_miss_resp_beat_o = icache_beat;

      always_ff @(posedge clk_i) begin
        if (~rst_ni) begin
          icache_beat <= 0;
        end else begin
          icache_beat <= icache_miss_resp_data_rok ? icache_beat + 2'b01 : 0;
        end
      end

    end else begin
      assign icache_miss_resp_data_rok = icache_miss_resp_w;
      assign icache_miss_resp_meta_rok = icache_miss_resp_w;
      assign icache_miss_resp_wok = 1'b1;
      assign icache_miss_resp_meta_id = icache_miss_resp_wdata.mem_resp_r_id;
      assign icache_miss_resp_data_rdata = icache_miss_resp_wdata.mem_resp_r_data[icache_miss_req_wdata.mem_req_addr[5]*256 +: IFILL_WIDTH];
    end
  endgenerate

  //  Read request arbiter
  logic [1:0]              mem_req_read_ready;
  logic [1:0]              mem_req_read_valid;
  hpdcache_mem_req_t [1:0] mem_req_read;

  logic                    mem_req_read_ready_arb;
  logic                    mem_req_read_valid_arb;
  hpdcache_mem_req_t       mem_req_read_arb;

  assign icache_miss_req_r      = mem_req_read_ready[0],
         mem_req_read_valid[0]  = icache_miss_req_rok,
         mem_req_read[0]        = icache_miss_req_rdata;

  assign dcache_read_ready_o    = mem_req_read_ready[1],
         mem_req_read_valid[1]  = dcache_read_valid_i,
         mem_req_read[1]        = dcache_read_i;

  hpdcache_mem_req_read_arbiter #(
    .N(2),
    .hpdcache_mem_req_t (hpdcache_mem_req_t)
  ) i_mem_req_read_arbiter (
    .clk_i,
    .rst_ni,

    .mem_req_read_ready_o (mem_req_read_ready),
    .mem_req_read_valid_i (mem_req_read_valid),
    .mem_req_read_i       (mem_req_read),

    .mem_req_read_ready_i (mem_req_read_ready_arb),
    .mem_req_read_valid_o (mem_req_read_valid_arb),
    .mem_req_read_o       (mem_req_read_arb)
  );

  //  Read response demultiplexor
  logic                                mem_resp_read_ready;
  logic                                mem_resp_read_valid;
  hpdcache_mem_resp_r_t      mem_resp_read;

  logic                                mem_resp_read_ready_arb [1:0];
  logic                                mem_resp_read_valid_arb [1:0];
  hpdcache_mem_resp_r_t      mem_resp_read_arb       [1:0];

  mem_resp_rt_t mem_resp_read_rt;

  always_comb
  begin
    for (int i = 0; i < MEM_RESP_RT_DEPTH; i++) begin
      mem_resp_read_rt[i] = (i == int'(   icache_miss_id_i)) ? 0 : 1;
    end
  end

  hpdcache_mem_resp_demux #(
    .N                  (2),
    .resp_t             (hpdcache_mem_resp_r_t),
    .resp_id_t          (hpdcache_mem_id_t)
  ) i_mem_resp_read_demux (
    .clk_i,
    .rst_ni,

    .mem_resp_ready_o   (mem_resp_read_ready),
    .mem_resp_valid_i   (mem_resp_read_valid),
    .mem_resp_id_i      (mem_resp_read.mem_resp_r_id),
    .mem_resp_i         (mem_resp_read),

    .mem_resp_ready_i   (mem_resp_read_ready_arb),
    .mem_resp_valid_o   (mem_resp_read_valid_arb),
    .mem_resp_o         (mem_resp_read_arb),

    .mem_resp_rt_i      (mem_resp_read_rt)
  );

  assign icache_miss_resp_w          = mem_resp_read_valid_arb[0],
         icache_miss_resp_wdata      = mem_resp_read_arb[0],
         mem_resp_read_ready_arb[0]  = icache_miss_resp_wok;

  assign dcache_read_resp_valid_o    = mem_resp_read_valid_arb[1],
         dcache_read_resp_o          = mem_resp_read_arb[1],
         mem_resp_read_ready_arb[1]  = dcache_read_resp_ready_i;

  //  AXI adapters
  axi_cache_req_t       axi_req;
  axi_cache_resp_t      axi_resp;

  hpdcache_mem_to_axi_write #(
      .aw_chan_t          (aw_chan_t),
      .w_chan_t           (axi_cache_w_chan_t),
      .b_chan_t           (b_chan_t),
      .hpdcache_mem_req_t     (hpdcache_mem_req_t),
      .hpdcache_mem_req_w_t   (hpdcache_mem_req_w_t),
      .hpdcache_mem_resp_w_t  (hpdcache_mem_resp_w_t)
  ) i_hpdcache_mem_to_axi_write (
      .req_ready_o        (dcache_write_ready_o),
      .req_valid_i        (dcache_write_valid_i),
      .req_i              (dcache_write_i),

      .req_data_ready_o   (dcache_write_data_ready_o),
      .req_data_valid_i   (dcache_write_data_valid_i),
      .req_data_i         (dcache_write_data_i),

      .resp_ready_i       (dcache_write_resp_ready_i),
      .resp_valid_o       (dcache_write_resp_valid_o),
      .resp_o             (dcache_write_resp_o),

      .axi_aw_valid_o     (axi_req.aw_valid),
      .axi_aw_o           (axi_req.aw),
      .axi_aw_ready_i     (axi_resp.aw_ready),

      .axi_w_valid_o      (axi_req.w_valid),
      .axi_w_o            (axi_req.w),
      .axi_w_ready_i      (axi_resp.w_ready),

      .axi_b_valid_i      (axi_resp.b_valid),
      .axi_b_i            (axi_resp.b),
      .axi_b_ready_o      (axi_req.b_ready)
  );

  hpdcache_mem_to_axi_read #(
    .ar_chan_t            (ar_chan_t),
    .r_chan_t             (axi_cache_r_chan_t),
    .hpdcache_mem_req_t     (hpdcache_mem_req_t),
    .hpdcache_mem_resp_r_t  (hpdcache_mem_resp_r_t)
  ) i_hpdcache_mem_to_axi_read (
    .req_ready_o          (mem_req_read_ready_arb),
    .req_valid_i          (mem_req_read_valid_arb),
    .req_i                (mem_req_read_arb),

    .resp_ready_i         (mem_resp_read_ready),
    .resp_valid_o         (mem_resp_read_valid),
    .resp_o               (mem_resp_read),

    .axi_ar_valid_o       (axi_req.ar_valid),
    .axi_ar_o             (axi_req.ar),
    .axi_ar_ready_i       (axi_resp.ar_ready),

    .axi_r_valid_i        (axi_resp.r_valid),
    .axi_r_i              (axi_resp.r),
    .axi_r_ready_o        (axi_req.r_ready)
  );

  assign axi_req_o = axi_req;
  assign axi_resp  = axi_resp_i;

endmodule
