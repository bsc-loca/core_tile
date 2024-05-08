
module sim_top;
    import sargantana_hpdc_pkg::*, drac_pkg::*;

    logic tb_clk, tb_rstn;

    // *** Clock & Reset drivers ***

    initial begin
        tb_clk = 1'b0;
        tb_rstn = 1'b0;
        #5 tb_rstn = 1'b1;
    end

    always #1 tb_clk = ~tb_clk;

    // *** DUT ***


    // Bootrom wires
    logic [23:0] brom_req_address;
    logic brom_req_valid;
    logic brom_ready;
    logic [127:0] brom_resp_data;
    logic brom_resp_valid;

    // icache wires
    logic icache_l1_request_valid;
    logic icache_l2_response_valid;
    logic [drac_pkg::PHY_ADDR_SIZE-1:0] icache_l1_request_paddr;
    logic [sargantana_icache_pkg::FETCH_WIDHT-1:0] icache_l2_response_data;

    logic dut_icache_req_valid;
    logic dut_icache_resp_valid;
    logic [drac_pkg::PHY_ADDR_SIZE-1:0] dut_icache_request_paddr;
    logic [sargantana_icache_pkg::FETCH_WIDHT-1:0] dut_icache_response_data;

    assign dut_icache_response_data = brom_resp_valid ? brom_resp_data : icache_l2_response_data;
    assign dut_icache_response_valid = brom_resp_valid | icache_l2_response_valid;
    assign icache_l1_request_paddr = dut_icache_request_paddr;
    assign icache_l1_request_valid = dut_icache_req_valid;

    //      Miss read interface
    logic                          mem_req_miss_read_ready;
    logic                          mem_req_miss_read_valid;
    hpdcache_mem_req_t             mem_req_miss_read;

    logic                          mem_resp_miss_read_ready;
    logic                          mem_resp_miss_read_valid;
    hpdcache_mem_resp_r_t          mem_resp_miss_read;

    //      Write-buffer write interface
    logic                          mem_req_wbuf_write_ready;
    logic                          mem_req_wbuf_write_valid;
    hpdcache_mem_req_t             mem_req_wbuf_write;

    logic                          mem_req_wbuf_write_data_ready;
    logic                          mem_req_wbuf_write_data_valid;
    hpdcache_mem_req_w_t           mem_req_wbuf_write_data;

    logic                          mem_resp_wbuf_write_ready;
    logic                          mem_resp_wbuf_write_valid;
    hpdcache_mem_resp_w_t          mem_resp_wbuf_write;

    //      Uncached read interface
    logic                          mem_req_uc_read_ready;
    logic                          mem_req_uc_read_valid;
    hpdcache_mem_req_t             mem_req_uc_read;

    logic                          mem_resp_uc_read_ready;
    logic                          mem_resp_uc_read_valid;
    hpdcache_mem_resp_r_t          mem_resp_uc_read;

    //      Uncached write interface
    logic                          mem_req_uc_write_ready;
    logic                          mem_req_uc_write_valid;
    hpdcache_mem_req_t             mem_req_uc_write;

    logic                          mem_req_uc_write_data_ready;
    logic                          mem_req_uc_write_data_valid;
    hpdcache_mem_req_w_t           mem_req_uc_write_data;

    logic                          mem_resp_uc_write_ready;
    logic                          mem_resp_uc_write_valid;
    hpdcache_mem_resp_w_t          mem_resp_uc_write;

    top_tile DUT(
        .clk_i(tb_clk),
        .rstn_i(tb_rstn),
        .soft_rstn_i(tb_rstn),
        .debug_halt_i(0),
        .reset_addr_i({{{PHY_VIRT_MAX_ADDR_SIZE-16}{1'b0}}, 16'h0100}),
        .core_id_i(64'b0),


        // Bootrom ports
        .brom_req_address_o(brom_req_address),
        .brom_req_valid_o(brom_req_valid),

        // icache ports
        .io_mem_acquire_valid(dut_icache_req_valid),               
        .io_mem_acquire_bits_addr_block(dut_icache_request_paddr),   
        .io_mem_grant_valid(dut_icache_response_valid),         
        .io_mem_grant_bits_data(dut_icache_response_data),
        .io_mem_grant_inval(0),
        .io_mem_grant_inval_addr(0),

        // dmem ports

        // dMem miss-read interface
        .mem_req_miss_read_ready_i(mem_req_miss_read_ready),
        .mem_req_miss_read_valid_o(mem_req_miss_read_valid),
        .mem_req_miss_read_o(mem_req_miss_read),

        .mem_resp_miss_read_ready_o(mem_resp_miss_read_ready),
        .mem_resp_miss_read_valid_i(mem_resp_miss_read_valid),
        .mem_resp_miss_read_i(mem_resp_miss_read),

        // dMem writeback interface
        .mem_req_wbuf_write_ready_i(mem_req_wbuf_write_ready),
        .mem_req_wbuf_write_valid_o(mem_req_wbuf_write_valid),
        .mem_req_wbuf_write_o(mem_req_wbuf_write),

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

        .mem_resp_uc_read_ready_o(mem_resp_uc_read_ready),
        .mem_resp_uc_read_valid_i(mem_resp_uc_read_valid),
        .mem_resp_uc_read_i(mem_resp_uc_read),

        // Unused ports
        .debug_pc_addr_i(0),
        .debug_pc_valid_i(0),
        .debug_reg_read_valid_i(0),
        .debug_reg_read_addr_i(0),
        .debug_preg_write_valid_i(0),
        .debug_preg_write_data_i(0),
        .debug_preg_addr_i(0),
        .debug_preg_read_valid_i(0),
        .debug_fetch_pc_o(),
        .debug_decode_pc_o(),
        .debug_register_read_pc_o(),
        .debug_execute_pc_o(),
        .debug_writeback_pc_o(),
        .debug_writeback_pc_valid_o(),
        .debug_writeback_addr_o(),
        .debug_writeback_we_o(),
        .debug_mem_addr_o(),
        .debug_backend_empty_o(),
        .debug_preg_addr_o(),
        .debug_preg_data_o(),
        .debug_intel_i('0),
        .debug_intel_o(),

        .time_i(64'd0),
        .irq_i(1'b0),
        .soft_irq_i(1'b0),
        .time_irq_i(1'b0),
        .io_core_pmu_l2_hit_i()
    );

    bootrom_behav brom(
        .clk(tb_clk),
        .rstn(tb_rstn),
        .brom_req_address_i(brom_req_address),
        .brom_req_valid_i(brom_req_valid),
        .brom_ready_o(brom_ready),
        .brom_resp_data_o(brom_resp_data),
        .brom_resp_valid_o(brom_resp_valid)
    );

    l2_behav #(
        .DATA_CACHE_LINE_SIZE(drac_pkg::DCACHE_BUS_WIDTH),
        .INST_CACHE_LINE_SIZE(sargantana_icache_pkg::SET_WIDHT)
    ) l2_inst (
        .clk_i(tb_clk),
        .rstn_i(tb_rstn),

        // *** Instruction Cache Interface ***

        .ic_addr_i(icache_l1_request_paddr),
        .ic_valid_i(icache_l1_request_valid),
        .ic_valid_o(icache_l2_response_valid),
        .ic_line_o(icache_l2_response_data),
	    .ic_seq_num_o(),

        // *** dCache Miss Read Interface ***

        .dc_mr_addr_i(mem_req_miss_read.mem_req_addr),
        .dc_mr_valid_i(mem_req_miss_read_valid),
        .dc_mr_ready_i(mem_resp_miss_read_ready),
        .dc_mr_tag_i(mem_req_miss_read.mem_req_id),
        .dc_mr_word_size_i(mem_req_miss_read.mem_req_size),
        .dc_mr_data_o(mem_resp_miss_read.mem_resp_r_data),
        .dc_mr_ready_o(mem_req_miss_read_ready),
        .dc_mr_valid_o(mem_resp_miss_read_valid),
        .dc_mr_tag_o(mem_resp_miss_read.mem_resp_r_id),
        .dc_mr_last_o(mem_resp_miss_read.mem_resp_r_last),

        // *** dCache Writeback Interface ***
        .dc_wb_req_ready_o(mem_req_wbuf_write_ready),
        .dc_wb_req_valid_i(mem_req_wbuf_write_valid),
        .dc_wb_req_addr_i(mem_req_wbuf_write.mem_req_addr),
        .dc_wb_req_len_i(mem_req_wbuf_write.mem_req_len),
        .dc_wb_req_size_i(mem_req_wbuf_write.mem_req_size),
        .dc_wb_req_id_i(mem_req_wbuf_write.mem_req_id),

        .dc_wb_req_data_ready_o(mem_req_wbuf_write_data_ready),
        .dc_wb_req_data_valid_i(mem_req_wbuf_write_data_valid),
        .dc_wb_req_data_i(mem_req_wbuf_write_data.mem_req_w_data),
        .dc_wb_req_be_i(mem_req_wbuf_write_data.mem_req_w_be),
        .dc_wb_req_last_i(mem_req_wbuf_write_data.mem_req_w_last),

        .dc_wb_resp_ready_i(mem_resp_wbuf_write_ready),
        .dc_wb_resp_valid_o(mem_resp_wbuf_write_valid),
        .dc_wb_resp_error_o(mem_resp_wbuf_write.mem_resp_w_error),
        .dc_wb_resp_id_o(mem_resp_wbuf_write.mem_resp_w_id),

        // *** dCache Uncacheable Writes Interface ***
        .dc_uc_wr_req_ready_o(mem_req_uc_write_ready),
        .dc_uc_wr_req_valid_i(mem_req_uc_write_valid),
        .dc_uc_wr_req_addr_i(mem_req_uc_write.mem_req_addr),
        .dc_uc_wr_req_len_i(mem_req_uc_write.mem_req_len),
        .dc_uc_wr_req_size_i(mem_req_uc_write.mem_req_size),
        .dc_uc_wr_req_id_i(mem_req_uc_write.mem_req_id),
        .dc_uc_wr_req_command_i(mem_req_uc_write.mem_req_command),
        .dc_uc_wr_req_atomic_i(mem_req_uc_write.mem_req_atomic),

        .dc_uc_wr_req_data_ready_o(mem_req_uc_write_data_ready),
        .dc_uc_wr_req_data_valid_i(mem_req_uc_write_data_valid),
        .dc_uc_wr_req_data_i(mem_req_uc_write_data.mem_req_w_data),
        .dc_uc_wr_req_be_i(mem_req_uc_write_data.mem_req_w_be),
        .dc_uc_wr_req_last_i(mem_req_uc_write_data.mem_req_w_last),

        .dc_uc_wr_resp_ready_i(mem_resp_uc_write_ready),
        .dc_uc_wr_resp_valid_o(mem_resp_uc_write_valid),
        .dc_uc_wr_resp_is_atomic_o(mem_resp_uc_write.mem_resp_w_is_atomic),
        .dc_uc_wr_resp_error_o(mem_resp_uc_write.mem_resp_w_error),
        .dc_uc_wr_resp_id_o(mem_resp_uc_write.mem_resp_w_id),

        // *** dCache Uncacheable Reads Interface ***
        .dc_uc_rd_req_ready_o(mem_req_uc_read_ready),
        .dc_uc_rd_req_valid_i(mem_req_uc_read_valid),
        .dc_uc_rd_req_addr_i(mem_req_uc_read.mem_req_addr),
        .dc_uc_rd_req_len_i(mem_req_uc_read.mem_req_len),
        .dc_uc_rd_req_size_i(mem_req_uc_read.mem_req_size),
        .dc_uc_rd_req_id_i(mem_req_uc_read.mem_req_id),
        .dc_uc_rd_req_command_i(mem_req_uc_read.mem_req_command),
        .dc_uc_rd_req_atomic_i(mem_req_uc_read.mem_req_atomic),

        .dc_uc_rd_valid_o(mem_resp_uc_read_valid),
        .dc_uc_rd_error_o(mem_resp_uc_read_error),
        .dc_uc_rd_id_o(mem_resp_uc_read.mem_resp_r_id),
        .dc_uc_rd_data_o(mem_resp_uc_read.mem_resp_r_data),
        .dc_uc_rd_last_o(mem_resp_uc_read.mem_resp_r_last),
        .dc_uc_rd_ready_i(mem_resp_uc_read_ready)
    );

    // *** Testbench monitors ***

    logic [63:0] cycles, max_cycles, start_cycles;

    always @(posedge tb_clk, negedge tb_rstn) begin
        if (~tb_rstn) cycles <= 0;
        else cycles <= cycles + 1;
    end

    initial begin
        string dumpfile;
        start_cycles = 0;
        if ($test$plusargs("vcd")) begin
            $dumpfile("dump_file.vcd");
            if (!$value$plusargs("start-vcd-cycles=%d", start_cycles)) begin
                $dumpvars();
            end
        end
        if (!$value$plusargs("max-cycles=%d", max_cycles)) max_cycles = 0;
    end

    always @(posedge tb_clk) begin
        if (start_cycles > 0 && cycles == start_cycles) begin
            $dumpvars();
        end
    end

    always @(posedge tb_clk) begin
        if (max_cycles > 0 && cycles == max_cycles) begin
            $error("Test timeout");
            $finish;
        end
    end

endmodule // veri_top
