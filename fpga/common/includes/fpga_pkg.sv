/*
 * Copyright 2025 BSC*
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

`ifndef FPGA_PKG
`define FPGA_PKG

`include "axi/assign.svh"
`include "defines.svh"
`include "axi/typedef.svh"

package fpga_pkg;

typedef logic [7:0]                         id_core_t;
typedef logic [`AXI_XBAR_PERI_ID_WIDTH-1:0] id_peri_t;
typedef logic [`MEM_ID_WIDTH-1:0]           id_mem_t;
typedef logic [63:0]                        addr_t;
typedef axi_pkg::xbar_rule_64_t             rule_t;
typedef logic [511:0]                       data512_t;
typedef logic [31:0]                        data32_t;
typedef logic [63:0]                        strb512_t;
typedef logic [3:0]                         strb32_t;
typedef logic [10:0]                        user_t;


typedef logic [12:0]  lite_addr_t;

`AXI_TYPEDEF_ALL(core_axi, addr_t, id_core_t, data512_t, strb512_t, user_t)
`AXI_TYPEDEF_ALL(peri_axi, addr_t, id_peri_t, data512_t, strb512_t, user_t)
`AXI_TYPEDEF_ALL(mem_axi, addr_t, id_mem_t, data512_t, strb512_t, user_t)
`AXI_TYPEDEF_ALL(axi32, addr_t, id_peri_t, data32_t, strb32_t, user_t)
`AXI_LITE_TYPEDEF_ALL(axi_lite, lite_addr_t, data32_t, strb32_t)

endpackage

`endif