
module sim_top #(
    parameter NUM_HARTS = 1
);
    import sargantana_hpdc_pkg::*, drac_pkg::*;

    logic tb_clk, tb_rstn;

    logic dut_rstn, debug_reset;

    // *** Clock & Reset drivers ***

    initial begin
        tb_clk = 1'b0;
        tb_rstn = 1'b0;
        #5 tb_rstn = 1'b1;
    end

    always #1 tb_clk = ~tb_clk;

    // *** DUT ***

    localparam drac_pkg::drac_cfg_t DRAC_CFG = drac_pkg::DracDefaultConfig;

    // Bootrom wires
    logic [39:0] brom_req_address;
    logic brom_req_valid;
    logic brom_ready;
    logic [63:0] brom_resp_data;
    logic brom_resp_valid;

    // Debug Module Program Buffer
    logic [39:0] prog_buf_req_address;
    logic prog_buf_req_valid;
    logic prog_buf_ready;
    logic [63:0] prog_buf_resp_data, prog_buf_resp_data_q;
    logic prog_buf_resp_valid;
    logic prog_buf_resp_valid_q;

    // Uncacheable Fetch
    logic [39:0] uc_fetch_req_address;
    logic uc_fetch_req_valid;
    logic uc_fetch_ready;
    logic [63:0] uc_fetch_resp_data;
    logic uc_fetch_resp_valid;
    logic [1:0] uc_fetch_mux_sel; // 00 -> unconnected, 01 -> brom, 10 -> prog_buf

    always_comb begin
        if (range_check(DRAC_CFG.InitBROMBase, DRAC_CFG.InitBROMEnd, {{{64-PHY_ADDR_SIZE}{1'b0}}, uc_fetch_req_address})) begin
            uc_fetch_mux_sel = 2'b01;
        end else if (range_check(DRAC_CFG.DebugProgramBufferBase, DRAC_CFG.DebugProgramBufferEnd, {{{64-PHY_ADDR_SIZE}{1'b0}}, uc_fetch_req_address})) begin
            uc_fetch_mux_sel = 2'b10;
        end else begin
            uc_fetch_mux_sel = 2'b00;
        end
    end

    // icache wires
    logic icache_l1_request_valid;
    logic icache_l2_response_valid;
    logic [drac_pkg::PHY_ADDR_SIZE-1:0] icache_l1_request_paddr;
    logic [sargantana_icache_pkg::FETCH_WIDHT-1:0] icache_l2_response_data;

    logic dut_icache_req_valid;
    logic [drac_pkg::PHY_ADDR_SIZE-1:0] dut_icache_request_paddr;
    logic [sargantana_icache_pkg::FETCH_WIDHT-1:0] dut_icache_response_data;

    // uncacheable fetch mux
    always_comb begin
        case(uc_fetch_mux_sel)
            2'b01: begin // Bootrom
                uc_fetch_resp_valid = brom_resp_valid;
                uc_fetch_resp_data = brom_resp_data;
                uc_fetch_ready = brom_ready;
            end
            2'b10: begin // Program Buffer
                uc_fetch_resp_valid = prog_buf_resp_valid;
                uc_fetch_resp_data = prog_buf_resp_data_q;
                uc_fetch_ready = prog_buf_ready;
            end
            default: begin // Unconnected
                uc_fetch_resp_valid = 1'b0;
                uc_fetch_resp_data = '0;
                uc_fetch_ready = '0;
            end
        endcase
    end

    assign brom_req_address = uc_fetch_req_address;
    assign brom_req_valid = uc_fetch_req_valid && uc_fetch_mux_sel == 2'b01;

    assign prog_buf_req_address = uc_fetch_req_address - DRAC_CFG.DebugProgramBufferBase;
    assign prog_buf_req_valid = uc_fetch_req_valid && uc_fetch_mux_sel == 2'b10;
    assign prog_buf_resp_valid = prog_buf_resp_valid_q; // Program buffer resp. is always valid

    always_ff @(posedge tb_clk, negedge dut_rstn) begin
        if (~dut_rstn) begin
            prog_buf_resp_valid_q <= 1'b0;
            prog_buf_resp_data_q <= '0;
        end else begin
            prog_buf_resp_valid_q <= uc_fetch_req_valid && uc_fetch_mux_sel == 2'b10;
            prog_buf_resp_data_q <= prog_buf_resp_data;
        end
    end

    assign icache_l1_request_paddr = dut_icache_request_paddr;
    assign icache_l1_request_valid = dut_icache_req_valid;

    assign dut_icache_response_data = uc_fetch_resp_valid ? uc_fetch_resp_data : icache_l2_response_data;
    assign dut_icache_response_valid = uc_fetch_resp_valid | icache_l2_response_valid;

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

    // Debug Module Interface

    // DM -> Core
    logic    [NUM_HARTS-1:0] debug_contr_halt_req;
    logic    [NUM_HARTS-1:0] debug_contr_resume_req;
    logic    [NUM_HARTS-1:0] debug_contr_progbuf_req;
    logic    [NUM_HARTS-1:0] debug_contr_halt_on_reset;

    logic    [NUM_HARTS-1:0] debug_reg_rnm_read_en;
    reg_t    [NUM_HARTS-1:0] debug_reg_rnm_read_reg;
    logic    [NUM_HARTS-1:0] debug_reg_rf_en;
    phreg_t  [NUM_HARTS-1:0] debug_reg_rf_preg;
    logic    [NUM_HARTS-1:0] debug_reg_rf_we;
    bus64_t  [NUM_HARTS-1:0] debug_reg_rf_wdata;

    // Core -> DM
    logic    [NUM_HARTS-1:0] debug_contr_halt_ack;
    logic    [NUM_HARTS-1:0] debug_contr_halted;
    logic    [NUM_HARTS-1:0] debug_contr_resume_ack;
    logic    [NUM_HARTS-1:0] debug_contr_running;
    logic    [NUM_HARTS-1:0] debug_contr_progbuf_ack;
    logic    [NUM_HARTS-1:0] debug_contr_parked;
    logic    [NUM_HARTS-1:0] debug_contr_unavail;
    logic    [NUM_HARTS-1:0] debug_contr_progbuf_xcpt;
    logic    [NUM_HARTS-1:0] debug_contr_havereset;

    phreg_t  [NUM_HARTS-1:0] debug_reg_rnm_read_resp;
    bus64_t  [NUM_HARTS-1:0] debug_reg_rf_rdata;

    assign dut_rstn = tb_rstn;

    top_tile #(.DracCfg(DRAC_CFG)) DUT (
        .clk_i(tb_clk),
        .rstn_i(dut_rstn),
        .soft_rstn_i(~debug_reset),
        .reset_addr_i({{{PHY_VIRT_MAX_ADDR_SIZE-16}{1'b0}}, 16'h0100}),
        .core_id_i(64'b0),

        // Bootrom ports
        .brom_req_address_o(uc_fetch_req_address),
        .brom_req_valid_o(uc_fetch_req_valid),

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
        
        .debug_contr_halt_req_i(debug_contr_halt_req[0]),
        .debug_contr_resume_req_i(debug_contr_resume_req[0]),
        .debug_contr_progbuf_req_i(debug_contr_progbuf_req[0]),
        .debug_contr_halt_on_reset_i(debug_contr_halt_on_reset[0]),

        .debug_reg_rnm_read_en_i(debug_reg_rnm_read_en[0]),
        .debug_reg_rnm_read_reg_i(debug_reg_rnm_read_reg[0]),
        .debug_reg_rf_en_i(debug_reg_rf_en[0]),
        .debug_reg_rf_preg_i(debug_reg_rf_preg[0]),
        .debug_reg_rf_we_i(debug_reg_rf_we[0]),
        .debug_reg_rf_wdata_i(debug_reg_rf_wdata[0]),

        .debug_contr_halt_ack_o(debug_contr_halt_ack[0]),
        .debug_contr_halted_o(debug_contr_halted[0]),
        .debug_contr_resume_ack_o(debug_contr_resume_ack[0]),
        .debug_contr_running_o(debug_contr_running[0]),
        .debug_contr_progbuf_ack_o(debug_contr_progbuf_ack[0]),
        .debug_contr_parked_o(debug_contr_parked[0]),
        .debug_contr_unavail_o(debug_contr_unavail[0]),
        .debug_contr_progbuf_xcpt_o(debug_contr_progbuf_xcpt[0]),
        .debug_contr_havereset_o(debug_contr_havereset[0]),

        .debug_reg_rnm_read_resp_o(debug_reg_rnm_read_resp[0]),
        .debug_reg_rf_rdata_o(debug_reg_rf_rdata[0]),

        .time_i(64'd0),
        .irq_i(1'b0),
        .soft_irq_i(1'b0),
        .time_irq_i(1'b0),
        .io_core_pmu_l2_hit_i()
    );

    // *** Bootrom ***

    bootrom_behav brom(
        .clk(tb_clk),
        .rstn(tb_rstn),
        .brom_req_address_i(brom_req_address),
        .brom_req_valid_i(brom_req_valid),
        .brom_ready_o(brom_ready),
        .brom_resp_data_o(brom_resp_data),
        .brom_resp_valid_o(brom_resp_valid)
    );

    // *** L2 / Main Memory ***

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

    // Debug Module / JTAG

    logic tck, tms, tdi, tdo, trstn, tdo_driven, jtag_enable;

    SimJTAG #(
        .TICK_DELAY(0)
    ) JTAG_DPI (
        .clock(tb_clk),
        .reset(~tb_rstn),

        .enable(jtag_enable),
        .init_done(1),

        .jtag_TCK(tck),
        .jtag_TMS(tms),
        .jtag_TDI(tdi),
        .jtag_TRSTn(trstn),

        .jtag_TDO_data(tdo),
        .jtag_TDO_driven(tdo_driven),

        .exit()
    );

    logic                                       req_valid;
    logic                                       req_ready;
    logic [riscv_dm_pkg::DMI_ADDR_WIDTH-1:0]    req_addr;
    logic [riscv_dm_pkg::DMI_DATA_WIDTH-1:0]    req_data;
    logic [riscv_dm_pkg::DMI_OP_WIDTH-1:0]      req_op;
    logic                                       req_valid_cdc;
    logic                                       req_ready_cdc;
    logic [riscv_dm_pkg::DMI_ADDR_WIDTH-1:0]    req_addr_cdc;
    logic [riscv_dm_pkg::DMI_DATA_WIDTH-1:0]    req_data_cdc;
    logic [riscv_dm_pkg::DMI_OP_WIDTH-1:0]      req_op_cdc;

    logic                                       resp_valid;
    logic                                       resp_ready;
    logic [riscv_dm_pkg::DMI_DATA_WIDTH-1:0]    resp_data;
    logic [riscv_dm_pkg::DMI_OP_WIDTH-1:0]      resp_op;
    logic                                       resp_valid_cdc;
    logic                                       resp_ready_cdc;
    logic [riscv_dm_pkg::DMI_DATA_WIDTH-1:0]    resp_data_cdc;
    logic [riscv_dm_pkg::DMI_OP_WIDTH-1:0]      resp_op_cdc;

    riscv_dtm dtm(
        .tms_i(tms),
        .tck_i(tck),
        .trst_i(~trstn),
        .tdi_i(tdi),
        .tdo_o(tdo),
        .tdo_driven_o(tdo_driven),
        .idcode_i(32'h149511c3),

        .req_valid_o(req_valid),
        .req_ready_i(req_ready),
        .req_addr_o(req_addr),
        .req_data_o(req_data),
        .req_op_o(req_op),

        .resp_valid_i(resp_valid_cdc),
        .resp_ready_o(resp_ready_cdc),
        .resp_data_i(resp_data_cdc),
        .resp_op_i(resp_op_cdc)
    );

    cdc_fifo_gray_clearable #(
        .WIDTH(riscv_dm_pkg::DMI_ADDR_WIDTH+riscv_dm_pkg::DMI_DATA_WIDTH+riscv_dm_pkg::DMI_OP_WIDTH)
    ) req_cdc_fifo (
        .src_rst_ni(trstn),
        .src_clk_i(tck),
        .src_clear_i(0),
        .src_clear_pending_o(),
        .src_data_i({req_addr, req_data, req_op}),
        .src_valid_i(req_valid),
        .src_ready_o(req_ready),

        .dst_rst_ni(tb_rstn),
        .dst_clk_i(tb_clk),
        .dst_clear_i(0),
        .dst_clear_pending_o(),
        .dst_data_o({req_addr_cdc, req_data_cdc, req_op_cdc}),
        .dst_valid_o(req_valid_cdc),
        .dst_ready_i(req_ready_cdc)
    );

    cdc_fifo_gray_clearable #(
        .WIDTH(riscv_dm_pkg::DMI_DATA_WIDTH+riscv_dm_pkg::DMI_OP_WIDTH)
    ) resp_cdc_fifo (
        .src_rst_ni(tb_rstn),
        .src_clk_i(tb_clk),
        .src_clear_i(0),
        .src_clear_pending_o(),
        .src_data_i({resp_data, resp_op}),
        .src_valid_i(resp_valid),
        .src_ready_o(resp_ready),

        .dst_rst_ni(trstn),
        .dst_clk_i(tck),
        .dst_clear_i(0),
        .dst_clear_pending_o(),
        .dst_data_o({resp_data_cdc, resp_op_cdc}),
        .dst_valid_o(resp_valid_cdc),
        .dst_ready_i(resp_ready_cdc)
    );

    logic halt_request, resume_request, halted, resumeack;

    riscv_dm #(
        .NUM_HARTS(NUM_HARTS)
    ) dm (
        .clk_i(tb_clk),
        .rstn_i(tb_rstn),

        .req_valid_i(req_valid_cdc),
        .req_ready_o(req_ready_cdc),
        .req_addr_i(req_addr_cdc),
        .req_data_i(req_data_cdc),
        .req_op_i(req_op_cdc),

        .resp_valid_o(resp_valid),
        .resp_ready_i(resp_ready),
        .resp_data_o(resp_data),
        .resp_op_o(resp_op),

        .resume_request_o(debug_contr_resume_req),
        .halt_request_o(debug_contr_halt_req),
        .halt_on_reset_o(debug_contr_halt_on_reset),
        .progbuf_run_req_o(debug_contr_progbuf_req),
        .hart_reset_o(debug_reset),

        .resume_ack_i(debug_contr_resume_ack),
        .halted_i(debug_contr_halted),
        .running_i(debug_contr_running),
        .unavail_i(debug_contr_unavail),
        .progbuf_run_ack_i(debug_contr_progbuf_ack),
        .parked_i(debug_contr_parked),
        .progbuf_xcpt_i(debug_contr_progbuf_xcpt),
        .havereset_i(debug_contr_havereset),

        .rnm_read_en_o(debug_reg_rnm_read_en),       // Request reading the rename table
        .rnm_read_reg_o(debug_reg_rnm_read_reg),     // Logical register for which the mapping is read
        .rnm_read_resp_i(debug_reg_rnm_read_resp),   // Physical register mapped to the requested logical register

        .rf_en_o(debug_reg_rf_en),                   // Read enable for the register file
        .rf_preg_o(debug_reg_rf_preg),               // Target physical register in the register file
        .rf_rdata_i(debug_reg_rf_rdata),             // Data read from the register file

        .rf_we_o(debug_reg_rf_we),                   // Write enable for the register file
        .rf_wdata_o(debug_reg_rf_wdata),             // Data to write to the register file
        //! @end


        // SRI interface for program buffer
        //! @virtualbus sri @dir in
        .sri_addr_i(prog_buf_req_address),     //! register interface address
        .sri_en_i(prog_buf_req_valid),         //! register interface enable
        .sri_wdata_i('0),                      //! register interface data to write
        .sri_we_i('0),                         //! register interface write enable
        .sri_be_i('0),                         //! register interface byte enable
        .sri_rdata_o(prog_buf_resp_data),      //! register interface read data
        .sri_error_o()                         //! register interface error
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

    initial begin
        if ($test$plusargs("jtag")) begin
            jtag_enable = 1'b1;
        end else begin
            jtag_enable = 1'b0;
        end
    end

endmodule // veri_top
