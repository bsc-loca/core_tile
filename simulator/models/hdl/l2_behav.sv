/*
* L2 / Main Memory Behavioral Model
* Author: Arnau Bigas (arnau.bigas@bsc.es)
*
* Description:
*
* This module models de behavior of the rest of the memory hierarchy and is
* designed to be connected to the BSC Tiles composed of the cores and the L1
* caches (the BSC's instruction_cache and CEA's HPDCache). It is composed of
* 3 channels:
*   1. icache refills
*   2. dCache reads
*   3. dCache writes
*
* For its inner workings, it uses a C++ DPI which loads an elf program, and
* provides a 512 bit interface to access the memory. Currently this behavioral
* model only works when the memory bus width of both the iCache and the HPDCache
* is equal to these 512 bits.
*
* This behavioural model only depends on the hpdcache_pkg.
*/

`define DPI_DATA_SIZE 512
`define DPI_BYTE_ENABLE_SIZE (`DPI_DATA_SIZE/8)

import "DPI-C" function void memory_init (input string path);
import "DPI-C" function void memory_read (input bit [31:0] addr, output bit [`DPI_DATA_SIZE-1:0] data);
import "DPI-C" function void memory_write (input bit [31:0] addr, input bit [`DPI_BYTE_ENABLE_SIZE-1:0] byte_enable, input bit [`DPI_DATA_SIZE-1:0] data);
import "DPI-C" function void memory_amo (input bit [31:0] addr, input bit [3:0] size, input bit [3:0] amo_op, input bit [`DPI_DATA_SIZE-1:0] data, output bit [`DPI_DATA_SIZE-1:0] result);
import "DPI-C" function void memory_symbol_addr(input string symbol, output bit [63:0] addr);

import "DPI-C" function int  tohost(input bit [63:0] data);

module mem_channel #(
    parameter SIZE = 16,
    parameter DELAY = 20,
    parameter ADDR_WIDTH = 49,
    parameter DATA_WIDTH = 512,
    parameter TAG_WIDTH = 8
)(
    input logic clk_i,
    input logic rstn_i,

    output logic                        req_ready_o,
    input logic                         req_valid_i,
    input logic [ADDR_WIDTH-1:0]        req_addr_i,
    input logic [2:0]                   req_size_i,
    input logic [TAG_WIDTH-1:0]         req_id_i,
    input logic [DATA_WIDTH-1:0]        req_data_i,
    input logic [(DATA_WIDTH/8)-1:0]    req_be_i,
    input logic [1:0]                   req_command_i,
    input logic [3:0]                   req_atomic_i,

    output logic                        rsp_valid_o,
    output logic [TAG_WIDTH-1:0]        rsp_id_o,
    output logic [DATA_WIDTH-1:0]       rsp_data_o,
    output logic                        rsp_is_atomic_o,
    input logic                         rsp_ready_i
);
    // *** Time reference ***

    logic [63:0] cycles;

    always_ff @(posedge clk_i) begin
        if(~rstn_i) begin
            cycles <= 0;
        end else begin
            cycles <= cycles + 1;
        end
    end

    // *** FIFO structure ***

    typedef struct packed {
        logic [ADDR_WIDTH-1:0]      addr;
        logic [TAG_WIDTH-1:0]       tag;
        logic [2:0]                 size;
        logic [DATA_WIDTH-1:0]      data;
        logic [(DATA_WIDTH/8)-1:0]  be;
        logic [1:0]                 cmd;
        logic [3:0]                 atomic_op;
        logic [63:0]                timestamp;
    } mem_op_t;

    mem_op_t memory [0:SIZE-1];
    logic [$clog2(SIZE)-1:0] write_ptr, read_ptr;
    logic [$clog2(SIZE):0] count;

    logic empty, full;

    assign empty = count == 0;
    assign full  = count == SIZE;

    mem_op_t head, new_data;
    assign head = memory[read_ptr];

    always_comb begin
        new_data.addr       = req_addr_i;
        new_data.tag        = req_id_i;
        new_data.size       = req_size_i;
        new_data.data       = req_data_i;
        new_data.be         = req_be_i;
        new_data.cmd        = req_command_i;
        new_data.atomic_op  = req_atomic_i;
        new_data.timestamp  = cycles;
    end

    logic fifo_write, fifo_read; // FIFO Controls

    assign fifo_write = req_valid_i & ~full;

    always_ff @(posedge clk_i) begin
        if (fifo_write) memory[write_ptr] <= new_data;
    end

    always_ff @(posedge clk_i) begin
        if(~rstn_i) begin
            write_ptr <= 0;
            read_ptr <= 0;
            count <= 0;
        end else begin
            if (fifo_write) write_ptr <= write_ptr + 1'b1;
            if (fifo_read && ~empty) read_ptr <= read_ptr + 1'b1;
            case({fifo_write,fifo_read})
                2'b00, 2'b11: count <= count;
                2'b01: count <= count - 1'b1;
                2'b10: count <= count + 1'b1;
            endcase
        end
    end

    // *** Control Logic ***

    typedef enum logic [1:0] {
        S_WAIT_DELAY, S_MEM_INTERFACE, S_WAIT_READY
    } state_t;

    state_t state;

    // Next-state logic
    always_ff @(posedge clk_i) begin
        if(~rstn_i) begin
            state <= S_WAIT_DELAY;
        end else begin
            case(state)
                S_WAIT_DELAY: // Waiting for the next memory op. to be "ready"
                    if (!empty && (cycles >= (head.timestamp + DELAY))) state <= S_MEM_INTERFACE;
                    else state <= S_WAIT_DELAY;
                S_MEM_INTERFACE:  // Interface with memory DPI
                    state <= S_WAIT_READY;
                S_WAIT_READY: // Wait for requester to accept the response
                    if (rsp_ready_i) state <= S_WAIT_DELAY;
                    else state <= S_WAIT_READY;
            endcase
        end
    end

    // Interface with memory DPI
    logic [TAG_WIDTH-1:0]  next_tag;
    logic [DATA_WIDTH-1:0] next_data;
    logic next_atomic;
    always_ff @(posedge clk_i) begin
        logic [`DPI_DATA_SIZE-1:0] readed_data; // From DPI
        if(~rstn_i) begin
            next_tag <= 0;
            next_data <= 0;
            next_atomic <= 1'b0;
        end else begin
            if (state == S_MEM_INTERFACE) begin
                next_tag <= head.tag;
                case (head.cmd)
                    2'b00: begin // Read
                        memory_read(head.addr, readed_data);
                        next_atomic <= 1'b0;
                        next_data <= readed_data[head.addr[5:0]*8 +: DATA_WIDTH];
                    end
                    2'b01: begin // Write
                        memory_write(head.addr, head.be, head.data);
                        next_data <= 0;
                        next_atomic <= 1'b0;
                    end
                    2'b10: begin // Atomic
                        memory_amo(head.addr, head.size, head.atomic_op, head.data, readed_data);
                        next_atomic <= 1'b1;
                        next_data <= readed_data;
                    end
                    2'b11: begin // Used for tohost, put dummy data
                        next_data <= 0;
                        next_atomic <= 1'b0;
                    end
                endcase
            end
        end
    end

    // Pop from queue after interfacing with memory
    assign fifo_read = state == S_MEM_INTERFACE; 

    // *** Channel Outputs ***

    assign req_ready_o = !full;
    assign rsp_valid_o = state == S_WAIT_READY;
    assign rsp_id_o = next_tag;
    assign rsp_data_o = next_data;
    assign rsp_is_atomic_o = next_atomic;

    // Only supported configuration is when cacheline width == DPI width
    initial assert (DATA_WIDTH == `DPI_DATA_SIZE);

endmodule

module l2_behav #(
    parameter DATA_CACHE_LINE_SIZE = 512,
    parameter INST_CACHE_LINE_SIZE = DATA_CACHE_LINE_SIZE,
    parameter ADDR_SIZE = 32,
    parameter INST_DELAY = 20,
    parameter DATA_DELAY = 20,
    parameter SIZE_WIDTH = 4,
    parameter ID_WIDTH = 8,

    localparam type addr_t = logic [ADDR_SIZE-1:0],
    localparam type data_t = logic [DATA_CACHE_LINE_SIZE-1:0],
    localparam type be_t   = logic [(DATA_CACHE_LINE_SIZE/8)-1:0],
    localparam type size_t = logic [SIZE_WIDTH-1:0],
    localparam type id_t   = logic [ID_WIDTH-1:0]

) (
    input logic                     clk_i,
    input logic                     rstn_i,

    // *** iCache Interface ***

    input logic [ADDR_SIZE-1:0]     ic_addr_i,
    input logic                     ic_valid_i,
    output logic [INST_CACHE_LINE_SIZE-1:0]    ic_line_o,
    output logic                    ic_ready_o,
    output logic                    ic_valid_o,
    output logic [1:0]              ic_seq_num_o,

    // *** dCache Interface ***

    // Read

    output logic  dc_read_req_ready_o,
    input logic   dc_read_req_valid_i,
    input addr_t  dc_read_req_addr_i,
    input id_t    dc_read_req_tag_i,
    input size_t  dc_read_req_word_size_i,
    input hpdcache_pkg::hpdcache_mem_command_e dc_read_req_cmd_i,  
    input hpdcache_pkg::hpdcache_mem_atomic_e dc_read_req_atomic_i,  

    input logic   dc_read_resp_ready_i,
    output logic  dc_read_resp_valid_o,
    output data_t dc_read_resp_data_o,
    output id_t   dc_read_resp_tag_o,
    output logic  dc_read_resp_last_o,

    // Write
    output logic  dc_write_req_ready_o,
    input logic   dc_write_req_valid_i,
    input addr_t  dc_write_req_addr_i,
    input size_t  dc_write_req_size_i,
    input id_t    dc_write_req_id_i,
    input hpdcache_pkg::hpdcache_mem_command_e dc_write_req_cmd_i,
    input hpdcache_pkg::hpdcache_mem_atomic_e dc_write_req_atomic_i,

    output logic dc_write_req_data_ready_o,
    input logic  dc_write_req_data_valid_i,
    input data_t dc_write_req_data_i,
    input be_t   dc_write_req_be_i,
    input logic  dc_write_req_last_i,

    input logic  dc_write_resp_ready_i,
    output logic dc_write_resp_valid_o,
    output hpdcache_pkg::hpdcache_mem_error_e  dc_write_resp_error_o,
    output id_t  dc_write_resp_id_o,
    output logic dc_write_resp_is_atomic_o
);

    logic [63:0] tohost_addr;

    // Memory DPI
    initial begin
        string path;
        if ($value$plusargs("load=%s", path)) begin
            memory_init(path);
            memory_symbol_addr("tohost", tohost_addr);
        end else begin
            $fatal(1, "No path provided for ELF to be loaded into the simulator's memory. Please provide one using +load=<path>");
        end
    end

    // *** iCache memory channel logic ***

    logic [$clog2(INST_DELAY)+1:0] ic_counter;
    logic [$clog2(INST_DELAY)+1:0] ic_next_counter;

    logic  [ADDR_SIZE-1:0] ic_addr_int;
    logic request_q;

    // ic_counter stuff
    assign ic_next_counter = (ic_counter > 0) ? ic_counter-1 : 0;
    assign ic_seq_num_o = 2'b11 - ic_counter[1:0];

    // Register holding the full bits from the DPI
    logic [`DPI_DATA_SIZE-1:0] ic_line;

    initial assert (INST_CACHE_LINE_SIZE == `DPI_DATA_SIZE);

    // ic_counter procedure
    always_ff @(posedge clk_i, negedge rstn_i) begin : proc_ic_counter
        if(~rstn_i) begin
            ic_counter <= 'h0;
            request_q <= 1'b0;
	        ic_valid_o <= 1'b0;
        end else if (ic_valid_i && !request_q) begin
            ic_counter <= INST_DELAY + 1;
	        ic_valid_o  <= 1'b0;
	        request_q <= 1'b1;
   	        ic_addr_int <= ic_addr_i;
        end else if (request_q && ic_counter > 0) begin
            ic_counter <= ic_next_counter;
	        ic_addr_int <= ic_addr_i;
   	        request_q <= 1'b1;
	        if (~|ic_next_counter && ~ic_valid_i) begin
                memory_read(ic_addr_int, ic_line);
	            ic_valid_o <= 1'b1;
	        end else begin
	            ic_valid_o <= 1'b0;
	        end
        end else begin
        	ic_valid_o  <= 1'b0;
	        request_q <= 1'b0;
        end
    end 

    always_comb begin
        if (ic_valid_o) ic_line_o = ic_line[ic_addr_int[5:0]*8 +: INST_CACHE_LINE_SIZE];
        else            ic_line_o = 0      ;
    end

    // *** dCache read channel ***

    logic  read_channel_rsp_valid;
    logic  read_channel_rsp_ready;
    data_t read_channel_rsp_data;
    id_t   read_channel_rsp_id;

    mem_channel #(
        .DATA_WIDTH(DATA_CACHE_LINE_SIZE),
        .ADDR_WIDTH(ADDR_SIZE)
    ) read_channel (
        .clk_i,
        .rstn_i,

        .req_ready_o(dc_read_req_ready_o),
        .req_valid_i(dc_read_req_valid_i),
        .req_addr_i(dc_read_req_addr_i),
        .req_size_i(dc_read_req_word_size_i),
        .req_id_i(dc_read_req_tag_i),
        .req_data_i(0), // Read-only channel
        .req_be_i(0),   // Read-only channel
        .req_command_i(dc_read_req_cmd_i),
        .req_atomic_i(dc_read_req_atomic_i),

        .rsp_valid_o(read_channel_rsp_valid),
        .rsp_id_o(read_channel_rsp_id),
        .rsp_data_o(read_channel_rsp_data),
        .rsp_is_atomic_o(), // Read channel doesn't have atomic responses
        .rsp_ready_i(read_channel_rsp_ready)
    );

    assign dc_read_resp_last_o = dc_read_resp_valid_o;

    // *** dCache writeback channel ***

    logic  write_channel_rsp_valid;
    logic  write_channel_rsp_ready;
    logic  write_channel_req_ready;
    data_t write_channel_rsp_data; // Only used in responses to atomic requests
    id_t   write_channel_rsp_id;

    mem_channel #(
        .DATA_WIDTH(DATA_CACHE_LINE_SIZE),
        .ADDR_WIDTH(ADDR_SIZE)
    ) write_channel (
        .clk_i,
        .rstn_i,

        .req_ready_o(write_channel_req_ready),
        .req_valid_i(dc_write_req_valid_i & dc_write_req_data_valid_i),
        .req_addr_i(dc_write_req_addr_i),
        .req_size_i(dc_write_req_size_i),
        .req_id_i(dc_write_req_id_i),
        .req_data_i(dc_write_req_data_i),
        .req_be_i(dc_write_req_be_i),
        .req_command_i(dc_write_req_cmd_i),
        .req_atomic_i(dc_write_req_atomic_i),

        .rsp_valid_o(write_channel_rsp_valid),
        .rsp_id_o(write_channel_rsp_id),
        .rsp_data_o(write_channel_rsp_data),
        .rsp_is_atomic_o(dc_write_resp_is_atomic_o),
        .rsp_ready_i(write_channel_rsp_ready)
    );

    // Wait for the write req & data to be available before signaling as ready
    assign dc_write_req_ready_o = write_channel_req_ready & dc_write_req_valid_i & dc_write_req_data_valid_i;
    assign dc_write_req_data_ready_o = dc_write_req_ready_o;

    assign dc_write_resp_error_o = hpdcache_pkg::HPDCACHE_MEM_RESP_OK;
    assign dc_write_resp_id_o = write_channel_rsp_id;
    assign dc_write_resp_valid_o = write_channel_rsp_valid;
    assign write_channel_rsp_ready = dc_write_resp_ready_i;

    // MUX for read channel and atomic responses

    always_comb begin: mux_read_atomic
        if (write_channel_rsp_valid & dc_write_resp_is_atomic_o) begin
            dc_read_resp_valid_o   = write_channel_rsp_valid;
            dc_read_resp_data_o    = write_channel_rsp_data;
            dc_read_resp_tag_o     = write_channel_rsp_id;
            read_channel_rsp_ready = 1'b0;
        end else begin
            dc_read_resp_valid_o   = read_channel_rsp_valid;
            dc_read_resp_data_o    = read_channel_rsp_data;
            dc_read_resp_tag_o     = read_channel_rsp_id;
            read_channel_rsp_ready = dc_read_resp_ready_i;
        end
    end

    // When responding an atomic request, both channels must be ready.
    atomic_resp_assert: assert property (@(posedge clk_i) disable iff (!rstn_i)
        (~(write_channel_rsp_valid & dc_write_resp_is_atomic_o) | (dc_write_resp_ready_i & dc_read_resp_ready_i))) else
        $error("Responding atomic request but the read or write interfaces aren't ready at the same time");

    // tohost logic for simulations

    assign is_tohost = dc_write_req_valid_i & dc_write_req_data_valid_i && dc_write_req_addr_i == tohost_addr;

    always_ff @(posedge clk_i, negedge rstn_i) begin
        logic [14:0] exit_code;
        if(~rstn_i) begin
        end else if (is_tohost) begin
            if (tohost(dc_write_req_data_i[63:0])) begin
                exit_code = dc_write_req_data_i[15:1];

                if (exit_code == 0) begin
                    $write("%c[1;32m", 27);
                    $write("Run finished correctly");
                    $write("%c[0m\n", 27);
                    $finish;
                end else begin
                    $write("%c[1;31m", 27);
                    $write("Simulation ended with error code %d", exit_code);
                    $write("%c[0m\n", 27);
                    $error;
                end
            end
        end
    end

endmodule
