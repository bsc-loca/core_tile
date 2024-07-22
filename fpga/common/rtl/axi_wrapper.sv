/*
 *  Authors       : Arnau Bigas
 *  Creation Date : July, 2023
 *  Description   : This file provides an AXI wrapper of the core, exposing the
 *                  memory hierarchy as a single AXI4 bus. Atomic operations are
 *                  implemented within this wrapper and thus needn't be
 *                  implemented upstream. This, however, implies that this
 *                  wrapper can only be used in single core applications.
 *                  Additionally, it also includes a bootrom.
 *  History      :
 */

import fpga_pkg::*, hpdcache_pkg::*;

module axi_wrapper 
(
    input logic clk_i,
    input logic rstn_i,

    AXI_BUS.Master axi_o,

    input logic time_irq_i,
    input logic [63:0] time_i,

    // JTAG
    input logic tck,
    input logic tms,
    input logic tdi,
    input logic trstn,

    output  logic tdo,
    output  logic tdo_driven
);

    localparam drac_pkg::drac_cfg_t DRAC_CFG = drac_pkg::DracDefaultConfig;
    localparam NUM_HARTS = 1;

    // Bootrom wires
    logic [23:0] brom_req_address;
    logic brom_req_valid;
    logic brom_ready;
    logic [127:0] brom_resp_data;
    logic brom_resp_valid;

    // Debug Module Program Buffer
    logic [23:0] prog_buf_req_address;
    logic prog_buf_req_valid;
    logic prog_buf_ready;
    logic [127:0] prog_buf_resp_data, prog_buf_resp_data_q;
    logic prog_buf_resp_valid;
    logic prog_buf_resp_valid_q;

    // Uncacheable Fetch
    logic [23:0] uc_fetch_req_address;
    logic uc_fetch_req_valid;
    logic uc_fetch_ready;
    logic [127:0] uc_fetch_resp_data;
    logic uc_fetch_resp_valid;
    logic [1:0] uc_fetch_mux_sel; // 00 -> unconnected, 01 -> brom, 10 -> prog_buf

    always_comb begin
        if (range_check(DRAC_CFG.InitBROMBase, DRAC_CFG.InitBROMEnd, {{{64-drac_pkg::PHY_ADDR_SIZE}{1'b0}}, uc_fetch_req_address})) begin
            uc_fetch_mux_sel = 2'b01;
        end else if (range_check(DRAC_CFG.DebugProgramBufferBase, DRAC_CFG.DebugProgramBufferEnd, {{{64-drac_pkg::PHY_ADDR_SIZE}{1'b0}}, uc_fetch_req_address})) begin
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


    logic core_icache_request_valid;
    logic core_icache_response_valid;
    logic [drac_pkg::PHY_ADDR_SIZE-1:0] core_icache_request_paddr;
    logic [511:0] core_icache_response_data;
    logic [1:0] l2_response_seqnum;

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

    always_ff @(posedge clk_i, negedge sargantana_rstn) begin
        if (~sargantana_rstn) begin
            prog_buf_resp_valid_q <= 1'b0;
            prog_buf_resp_data_q <= '0;
        end else begin
            prog_buf_resp_valid_q <= uc_fetch_req_valid && uc_fetch_mux_sel == 2'b10;
            prog_buf_resp_data_q <= prog_buf_resp_data;
        end
    end

    assign core_icache_response_data = uc_fetch_resp_valid ? uc_fetch_resp_data : icache_l2_response_data;
    assign core_icache_response_valid = uc_fetch_resp_valid | icache_l2_response_valid;

    assign icache_l1_request_paddr = core_icache_request_paddr;
    assign icache_l1_request_valid = core_icache_request_valid;

    //      Miss read interface
    logic                           mem_req_miss_read_ready;
    logic                           mem_req_miss_read_valid;
    sargantana_hpdc_pkg::hpdcache_mem_req_t    mem_req_miss_read;

    logic                           mem_resp_miss_read_ready;
    logic                           mem_resp_miss_read_valid;
    sargantana_hpdc_pkg::hpdcache_mem_resp_r_t mem_resp_miss_read;

    //      Write-buffer write interface
    logic                           mem_req_wbuf_write_ready;
    logic                           mem_req_wbuf_write_valid;
    sargantana_hpdc_pkg::hpdcache_mem_req_t    mem_req_wbuf_write;

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


    // Debug Module Interface

    // DM -> Core
    logic                    sargantana_rstn;
    logic                    debug_reset;
    logic    [NUM_HARTS-1:0] debug_contr_halt_req;
    logic    [NUM_HARTS-1:0] debug_contr_resume_req;
    logic    [NUM_HARTS-1:0] debug_contr_progbuf_req;
    logic    [NUM_HARTS-1:0] debug_contr_halt_on_reset;

    logic    [NUM_HARTS-1:0] debug_reg_rnm_read_en;
    drac_pkg::reg_t    [NUM_HARTS-1:0] debug_reg_rnm_read_reg;
    logic    [NUM_HARTS-1:0] debug_reg_rf_en;
    drac_pkg::phreg_t  [NUM_HARTS-1:0] debug_reg_rf_preg;
    logic    [NUM_HARTS-1:0] debug_reg_rf_we;
    drac_pkg::bus64_t  [NUM_HARTS-1:0] debug_reg_rf_wdata;

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

    drac_pkg::phreg_t  [NUM_HARTS-1:0] debug_reg_rnm_read_resp;
    drac_pkg::bus64_t  [NUM_HARTS-1:0] debug_reg_rf_rdata;

    assign sargantana_rstn = rstn_i;

    top_tile core_inst (
        .clk_i(clk_i),
        .rstn_i(sargantana_rstn),
        .soft_rstn_i(~debug_reset),
        .reset_addr_i(40'h0000000100),

        // Bootrom ports
        .brom_req_address_o(uc_fetch_req_address),
        .brom_req_valid_o(uc_fetch_req_valid),

        // icache ports
        .io_mem_acquire_valid(core_icache_request_valid),
        .io_mem_acquire_bits_addr_block(core_icache_request_paddr),
        .io_mem_grant_valid(core_icache_response_valid),
        .io_mem_grant_bits_data(core_icache_response_data),
        .io_mem_grant_bits_addr_beat(l2_response_seqnum),
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

        // Debug module
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

        .time_irq_i(time_irq_i),
        .irq_i(1'b0),
        .soft_irq_i(1'b0),
        .time_i(time_i)
    );

    bootrom brom(
        .clk(clk_i),
        .rstn(sargantana_rstn),
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
        .rst_ni(sargantana_rstn),

        // *** iCache ***

        .icache_miss_valid_i(icache_l1_request_valid),
        .icache_miss_paddr_i(icache_l1_request_paddr),
        .icache_miss_id_i(1 << (sargantana_hpdc_pkg::HPDCACHE_MEM_TID_WIDTH - 1)),

        .icache_miss_resp_valid_o(icache_l2_response_valid),
        .icache_miss_resp_data_o(icache_l2_response_data),
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
        .rst_ni(sargantana_rstn),
        .mst(axi_o),
        .slv(axi_core_to_atomic)
    );


    // Debug Module / JTAG
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

    // Uncomment when the JTAG is ready
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

        .dst_rst_ni(rstn_i),
        .dst_clk_i(clk_i),
        .dst_clear_i(0),
        .dst_clear_pending_o(),
        .dst_data_o({req_addr_cdc, req_data_cdc, req_op_cdc}),
        .dst_valid_o(req_valid_cdc),
        .dst_ready_i(req_ready_cdc)
    );

    cdc_fifo_gray_clearable #(
        .WIDTH(riscv_dm_pkg::DMI_DATA_WIDTH+riscv_dm_pkg::DMI_OP_WIDTH)
    ) resp_cdc_fifo (
        .src_rst_ni(rstn_i),
        .src_clk_i(clk_i),
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

    // assign req_valid_cdc = '0;
    // assign resp_ready_cdc = '0;
    // assign req_addr_cdc = '0;
    // assign req_data_cdc = '0;
    // assign req_op_cdc = '0;

    logic halt_request, resume_request, halted, resumeack;

    riscv_dm #(
        .NUM_HARTS(NUM_HARTS)
    ) dm (
        .clk_i(clk_i),
        .rstn_i(rstn_i),

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


endmodule
