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
 
module bootrom
   (
    input  logic clk, rstn,
    input  logic [23:0] brom_req_address_i,
    input  logic brom_req_valid_i,
    output logic brom_ready_o,
    output logic [31:0] brom_resp_data_o,
    output logic brom_resp_valid_o
    );

    localparam MEM_DATA_WIDTH = 128;
    localparam BRAM_ADDR_WIDTH = 19; // 64 KB
    localparam BRAM_LINE = 2 ** BRAM_ADDR_WIDTH  * 8 / MEM_DATA_WIDTH;
    localparam BRAM_LINE_OFFSET = $clog2(MEM_DATA_WIDTH/8);

    (* ram_style = "block" *) reg [MEM_DATA_WIDTH-1:0] boot_ram [0 : BRAM_LINE-1];
    initial $readmemh("bootrom.hex", boot_ram);

    logic [MEM_DATA_WIDTH-1:0] brom_resp_data_block;
    logic [23:0] brom_req_address_d;
    logic [7:0] brom_count;
    logic req_active;

    always_ff @(posedge clk, negedge rstn) begin
        if (~rstn) begin
            brom_count <= 'b0;
            req_active  <= 'b0;
            brom_resp_valid_o <= 'b0;
        end else begin
            if(brom_req_valid_i) begin
                req_active  <= 'b1;
                brom_req_address_d <= brom_req_address_i;
            end 

            if(~req_active) begin
                brom_count <= 'b0;
            end else begin
                brom_count <= brom_count +1;
            end

            if(brom_count == 3) begin
                req_active <= 'b0;
                brom_resp_valid_o <= 'b1;
            end else begin
                brom_resp_valid_o <= 'b0;
            end
        end
    end

    logic ram_clk, ram_rst, ram_en;
    logic [MEM_DATA_WIDTH/8-1:0] ram_we;
    logic [MEM_DATA_WIDTH-1:0] ram_wrdata, ram_rddata;

    always_ff @(posedge clk) begin
        brom_resp_data_block = boot_ram[brom_req_address_d[BRAM_ADDR_WIDTH-1:BRAM_LINE_OFFSET]];
        foreach (ram_we[i])
            if(ram_we[i])
                boot_ram[brom_req_address_d[BRAM_ADDR_WIDTH-1:BRAM_LINE_OFFSET]][i*8 +:8] <= ram_wrdata[i*8 +: 8];
    end

    always_comb begin
        case(brom_req_address_d[3:2])
            2'b00: brom_resp_data_o = brom_resp_data_block[31:0];
            2'b01: brom_resp_data_o = brom_resp_data_block[63:32];
            2'b10: brom_resp_data_o = brom_resp_data_block[95:64];
            2'b11: brom_resp_data_o = brom_resp_data_block[127:96];
            default: brom_resp_data_o = 32'h0;
        endcase
    end

    assign brom_ready_o = ~req_active & rstn;

endmodule // bootrom
