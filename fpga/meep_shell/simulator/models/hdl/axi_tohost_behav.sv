import fpga_pkg::*;

module axi_tohost_behav (
    input logic                     clk_i,
    input logic                     rstn_i,

    AXI_BUS.Slave axi
);

    import "DPI-C" function void memory_symbol_addr(input string symbol, output bit [63:0] addr);
    import "DPI-C" function int  tohost(input bit [63:0] data);

    // Memory DPI

    logic [63:0] tohost_addr;

    // Tohost Valid bits

    logic last_write_addr_valid, last_write_valid, int_valid;

    // AW Channel

    assign axi.aw_ready = ~last_write_addr_valid;

    logic [63:0] last_write_addr;

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            last_write_addr <= 0;
            last_write_addr_valid <= 1'b0;
        end else begin
            if (axi.aw_valid && axi.aw_ready) begin
                last_write_addr <= axi.aw_addr;
                last_write_addr_valid <= 1'b1;
            end else if (int_valid) begin
                last_write_addr <= 0;
                last_write_addr_valid <= 1'b0;
            end
        end
    end

    // W Channel

    assign axi.w_ready = ~last_write_valid;
    logic [511:0] last_write_data;

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            last_write_data <= 0;
            last_write_valid <= 1'b0;
        end else begin
            if (axi.w_valid && axi.w_ready) begin
                last_write_data <= axi.w_valid;
                last_write_valid <= 1'b1;
            end else if (int_valid) begin
                last_write_data <= 0;
                last_write_valid <= 1'b0;
            end
        end
    end

    // AR & R Channels

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            axi.r_valid <= 1'b0;
            axi.r_data <= '0;
            axi.ar_ready <= 1'b1;
            axi.r_id <= '0;
        end else begin
            if (axi.ar_valid && axi.ar_ready) begin
                axi.r_valid <= 1'b1;
                axi.r_data <= '0;
                axi.ar_ready <= 1'b0;
                axi.r_id <= axi.ar_id;
            end else if (axi.r_valid && axi.r_ready) begin
                axi.r_valid <= 1'b0;
                axi.r_data <= '0;
                axi.ar_ready <= 1'b1;
                axi.r_id <= '0;
            end
        end
    end

    // Internal logic

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            int_valid <= 1'b0;
        end else begin
            if (last_write_valid && last_write_addr_valid) begin
                int_valid <= 1'b1;
                memory_symbol_addr("tohost", tohost_addr);
            end else begin
                int_valid <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk_i) begin
        logic [14:0] exit_code;
        if (int_valid && last_write_addr == tohost_addr) begin
            if (tohost(last_write_data[63:0])) begin
                exit_code = last_write_data[15:1];

                if (exit_code == 0) begin
                    $write("%c[1;32m", 27);
                    $write("Run finished correctly");
                    $write("%c[0m\n", 27);
                    $finish;
                end else begin
                    $write("%c[1;31m", 27);
                    $write("Simulation ended with error code %d", exit_code);
                    $write("%c[0m\n", 27);
                    `ifdef VERILATOR // Use $error because Verilator doesn't support exit codes in $finish
                        $error;
                    `else
                        $finish(exit_code);
                    `endif
                end
            end
        end
    end

endmodule
