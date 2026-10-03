import drac_pkg::*;

// Module used to dump information comming from writeback stage
module konata_dump_behav
(
// General input
input	clk, rst,
// Control Input
input	if1_valid,
input	if2_valid,
input id_valid,
input rr_valid,
input exe_valid,
input wb_valid,

input if1_stall,
input if2_stall,
input id_stall,
input rr_stall,
input exe_stall,

input if1_flush,
input if2_flush,
input id_flush,
input rr_flush,
input exe_flush,

input [63:0] if1_id,
input [63:0] if2_id,
input [63:0] id_id,
input [63:0] rr_id,
input [63:0] exe_id,
input [63:0] wb_id,

// Data Input
input [63:0] id_pc,
input [31:0] id_inst,

input functional_unit_t exe_unit,
input functional_unit_t wb_unit

);

// DPI calls definition
import "DPI-C" function
  void konata_dump (input longint unsigned if1_valid,
                    input longint unsigned if2_valid,
                    input longint unsigned id_valid,
                    input longint unsigned rr_valid,
                    input longint unsigned exe_valid,
                    input longint unsigned wb_valid,,
                    input longint unsigned if1_stall,
                    input longint unsigned if2_stall,
                    input longint unsigned id_stall,
                    input longint unsigned rr_stall,
                    input longint unsigned exe_stall,
                    input longint unsigned if1_flush,
                    input longint unsigned if2_flush,
                    input longint unsigned id_flush,
                    input longint unsigned rr_flush,
                    input longint unsigned exe_flush, 
                    input longint unsigned id_pc,
                    input longint unsigned id_inst,
                    input longint unsigned if1_id,
                    input longint unsigned if2_id,
                    input longint unsigned id_id,
                    input longint unsigned rr_id,
                    input longint unsigned exe_id,
                    input longint unsigned exe_unit,
                    input longint unsigned wb_id,
                    input longint unsigned wb_unit);
                     
                    
import "DPI-C" function void konata_signature_init(input string dumpfile);

    logic dump_enabled;

// we create the behav model to control it
initial begin
    string dumpfile;
    if($test$plusargs("konata_dump")) begin
        dump_enabled = 1'b1;
        if (!$value$plusargs("konata_dump=%s", dumpfile)) dumpfile = "konata.txt";
        konata_signature_init(dumpfile);
    end else begin
        dump_enabled = 1'b0;
    end
end

// Main always
always @(posedge clk) begin
    if (dump_enabled) begin
        konata_dump(if1_valid, if2_valid, id_valid, rr_valid, exe_valid, 
                    wb_valid, if1_stall, if2_stall, id_stall,
                    rr_stall, exe_stall, if1_flush, if2_flush, id_flush, rr_flush, exe_flush, id_pc,
                    id_inst, if1_id, if2_id, id_id, rr_id, exe_id, exe_unit, wb_id, wb_unit);
    end
end

endmodule
