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

import drac_pkg::*;

// Module used to dump information comming from writeback stage
module commit_log_behav
(
// General input
input	clk, rst,
input logic commit_valid_i [1:0],
input commit_data_t commit_data_i [1:0]
);

    // DPI calls definition
    import "DPI-C" function void commit_log (input commit_data_t commit_data);
    import "DPI-C" function void commit_log_init(input string logfile);

    logic dump_enabled;

// we create the behav model to control it
initial begin
    string logfile;
    if($test$plusargs("commit_log")) begin
        dump_enabled = 1'b1;
        if (!$value$plusargs("commit_log=%s", logfile)) logfile = "signature.txt";
        commit_log_init(logfile);
    end else begin
        dump_enabled = 1'b0;
    end
end

// Main always
always @(posedge clk) begin
    if (dump_enabled) begin
        for (int i = 0; i < 2; i++) begin
            if (commit_valid_i[i]) begin
                commit_log(commit_data_i[i]);
            end
        end
    end
end

endmodule
