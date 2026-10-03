/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : top_icache.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Neiel I. Leyva Santes. 
 * Email(s)       : neiel.leyva@bsc.es
 * References     : 
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Commit | Description
 *  ******     | Neiel L.  |        | 
 * -----------------------------------------------
 */



module sargantana_top_icache 
#(
    parameter logic         KILL_RESP           = 1'b1,
    parameter logic         LINES_256           = 1'b0,

    parameter int unsigned  ICACHE_MEM_BLOCK    = 64,
    parameter int unsigned  PADDR_SIZE          = 40,   //! Physical address size.

    parameter int unsigned  ADDR_SIZE           = 40,   //! Maximum between physical address size and virtual address size.
    parameter int unsigned  IDX_BITS_SIZE       = 12,   //! Bits used for idx
    parameter int unsigned  VPN_BITS_SIZE       = ADDR_SIZE - IDX_BITS_SIZE,    //! Bits used for vpn

    parameter int unsigned  FETCH_WIDHT         = 128,

    parameter int unsigned  ITLB_CYCLE          = 0,    //! Pick cycle to do asynch ITLB transaction {0, 1}

    localparam int unsigned ICACHE_SIZE         = 16,   // Total size in KB 
    localparam int unsigned ASSOCIATIVE         = 4,    // Associativity

    //localparam int unsigned WORD_SIZE           = 64,                                                       //- Word size in a set.
    localparam int unsigned SET_WIDHT           = ICACHE_MEM_BLOCK*8,                                       //- Cache line
    localparam int unsigned ICACHE_DEPTH        = (((ICACHE_SIZE*1024)/ASSOCIATIVE)/ICACHE_MEM_BLOCK),

    localparam int unsigned ICACHE_N_WAY        = ASSOCIATIVE,                                              //- Number of ways.
    //localparam int unsigned ICACHE_N_WAY_CLOG2  = $clog2( ICACHE_N_WAY ),
    localparam int unsigned TAG_DEPTH           = ICACHE_DEPTH,                                             //- .
    localparam int unsigned ADDR_WIDHT          = $clog2( ICACHE_DEPTH ),                                   //- icache Addr vector
    localparam int unsigned TAG_ADDR_WIDHT      = $clog2( TAG_DEPTH ),                                      //- 
    localparam int unsigned WAY_WIDHT           = SET_WIDHT,                                                //- 

    localparam int unsigned ICACHE_OFFSET_WIDTH = $clog2(SET_WIDHT/8),                                      // align to 64bytes
    localparam int unsigned ICACHE_INDEX_WIDTH  = $clog2(ICACHE_DEPTH) + ICACHE_OFFSET_WIDTH,

    //localparam int unsigned BLOCK_ADDR_SIZE     = ADDR_SIZE - ICACHE_OFFSET_WIDTH,
    localparam int unsigned PPN_BIT_SIZE        = ADDR_SIZE - ICACHE_INDEX_WIDTH,
    localparam int unsigned TAG_WIDHT           = ADDR_SIZE - ICACHE_INDEX_WIDTH,                           //- Tag size.

    localparam int unsigned ICACHE_TAG_WIDTH    = TAG_WIDHT,
    localparam int unsigned ICACHE_IDX_WIDTH    = ADDR_WIDHT

)
(
    `ifdef INTEL_PHYSICAL_MEM_CTRL
    input  wire [27:0]                      hduspsr_mem_ctrl            ,
    `endif
    input  logic                            clk_i                       ,
    input  logic                            rstn_i                      ,
    input  logic                            flush_i                     , 

    // Core interface                           
    // From Core
    input  logic                            lagarto_ireq_valid_i        ,   // we request a new word
    input  logic                            lagarto_ireq_kill_i         ,   // kill the current request
    input  logic [IDX_BITS_SIZE-1:0]        lagarto_ireq_idx_i          ,
    input  logic [VPN_BITS_SIZE-1:0]        lagarto_ireq_vpn_i          ,  

    // To Core
    output logic                            icache_resp_ready_o         ,  // icache is ready
    output logic                            icache_resp_valid_o         ,  // signals a valid read
    output logic [FETCH_WIDHT-1 :0]         icache_resp_data_o          ,  // 2+ cycle out: tag
    output logic [ADDR_SIZE-1:0]            icache_resp_vaddr_o         ,  // virtual address out
    output logic                            icache_resp_xcpt_o          ,  // we've encountered an exception

    // MMU interface                         
    //- From MMU.
    input  logic                            mmu_tresp_miss_i            ,
    input  logic                            mmu_tresp_ptw_v_i           ,  // ptw response valid
    input  logic [PPN_BIT_SIZE-1:0]         mmu_tresp_ppn_i             ,  // physical address in
    input  logic                            mmu_tresp_xcpt_i            ,  // exception occurred during fetch

    //- To MMU
    output logic                            icache_treq_valid_o         ,       // address translation request
    output logic [VPN_BITS_SIZE-1:0]        icache_treq_vpn_o           ,  
    
    // iFill interface
    input  logic                            ifill_resp_valid_i          , // Valid response
    input  logic                            ifill_resp_ack_i            , // IFILL request was received
    input  logic [SET_WIDHT-1:0]            ifill_resp_data_i           , // Full cache line
    input  logic                            ifill_resp_inv_valid_i      , //- valid invalidation and
    input  logic [ICACHE_INDEX_WIDTH-1:0]   ifill_resp_inv_paddr_i      , //- index to invalidate

    output logic                            icache_ifill_req_valid_o    ,  // valid request
    //output logic [$clog2(ICACHE_N_WAY)-1:0] icache_ifill_req_way_o      ,  // way to replace
    output logic [PADDR_SIZE-1:0]           icache_ifill_req_paddr_o    ,  // physical address

    // PMU
    output logic                            imiss_time_pmu_o            , 
    output logic                            imiss_kill_pmu_o           
);

logic     [ICACHE_TAG_WIDTH-1:0] cline_tag_d      ; //- Cache-line tag
logic     [ICACHE_TAG_WIDTH-1:0] cline_tag_q      ; //- Cache-line tag
logic     [ICACHE_IDX_WIDTH-1:0] vaddr_index      ;
logic [$clog2(ICACHE_N_WAY)-1:0] way_to_replace_q ;
logic [$clog2(ICACHE_N_WAY)-1:0] way_to_replace_d ;

logic     [ICACHE_N_WAY-1:0] tag_req_valid   ;      
logic     [ICACHE_N_WAY-1:0] data_req_valid  ;      
logic     [ICACHE_N_WAY-1:0] way_valid_bits  ;      
logic [ICACHE_IDX_WIDTH-1:0] addr_valid      ;
logic     [ICACHE_N_WAY-1:0] cline_hit       ;

logic [ICACHE_N_WAY-1:0][TAG_WIDHT-1:0] way_tags     ;
logic [ICACHE_N_WAY-1:0][WAY_WIDHT-1:0] cline_data_rd;

logic [IDX_BITS_SIZE-1:0]   idx_d ;
logic [IDX_BITS_SIZE-1:0]   idx_q ;
logic [VPN_BITS_SIZE-1:0]   vpn_d ;
logic [VPN_BITS_SIZE-1:0]   vpn_q ;

logic ifill_req_valid   ;
logic replay_valid      ;
logic valid_ireq_d      ;
logic valid_ireq_q      ;
logic ireq_kill_d       ;
logic ireq_kill_q       ;
logic flush_enable      ;
logic cache_rd_ena      ;
logic cache_rd_valid    ;
logic cache_wr_ena      ;
logic tag_we_valid      ;
logic cmp_enable        ;
logic cmp_enable_q      ;
logic treq_valid        ;
logic treq_valid_q      ;
logic valid_bit         ;
logic valid_ifill_resp  ;
logic is_flush_d        ;
logic is_flush_q        ;

logic ifill_req_was_sent_d ;
logic ifill_req_was_sent_q ;

logic ifill_process_started_d   ;
logic ifill_process_started_q   ;
logic tag_we                    ;
//logic block_invalidate          ;
logic valid_inv                 ;
logic ctrl_ready                ;

logic                    mmu_tresp_miss_d;
logic                    mmu_tresp_ptw_v_d;
logic [PPN_BIT_SIZE-1:0] mmu_tresp_ppn_d;
logic                    mmu_tresp_xcpt_d;
    
logic                    mmu_tresp_miss_q;
logic                    mmu_tresp_ptw_v_q;
logic [PPN_BIT_SIZE-1:0] mmu_tresp_ppn_q;
logic                    mmu_tresp_xcpt_q;

logic                    mmu_tresp_miss;
logic                    mmu_tresp_ptw_v;
logic [PPN_BIT_SIZE-1:0] mmu_tresp_ppn;
logic                    mmu_tresp_xcpt;


// a valid invalidation from L2
assign valid_inv = ifill_resp_valid_i & ifill_resp_inv_valid_i ;

//- It can only accept a request from the core if the cache is free.
assign valid_ireq_d = lagarto_ireq_valid_i || replay_valid ;

assign is_flush_d = flush_i;

assign ireq_kill_d = lagarto_ireq_kill_i ; 

//vaddr keeps available during all processes.
assign vpn_d = ( lagarto_ireq_valid_i ) ? {lagarto_ireq_vpn_i} : vpn_q;
assign idx_d = ( lagarto_ireq_valid_i ) ? {lagarto_ireq_idx_i} : idx_q;
//assign vaddr_in = {vpn_d,idx_d};
                                                      
always_ff @(posedge clk_i or negedge rstn_i) begin 
    if(!rstn_i) begin
        treq_valid_q <= '0;
    end
    else begin
        treq_valid_q <= treq_valid;
    end
end

// Make mmu transaction in cycle 0 or cycle 1
generate
    if (ITLB_CYCLE == 0) begin
        // mmu request
        assign icache_treq_vpn_o = vpn_d;
        assign icache_treq_valid_o = treq_valid || valid_ireq_d ;

        // mmu response into register
        assign mmu_tresp_miss_d     = mmu_tresp_miss_i;
        assign mmu_tresp_ptw_v_d    = mmu_tresp_ptw_v_i;
        assign mmu_tresp_ppn_d      = mmu_tresp_ppn_i;
        assign mmu_tresp_xcpt_d     = mmu_tresp_xcpt_i;


        // mmu response w/ reg into i$ ctrl
        assign mmu_tresp_miss     = mmu_tresp_miss_q;
        assign mmu_tresp_ptw_v    = mmu_tresp_ptw_v_q;
        assign mmu_tresp_ppn      = mmu_tresp_ppn_q;
        assign mmu_tresp_xcpt     = mmu_tresp_xcpt_q;
    end
    else begin
        // mmu request
        assign icache_treq_vpn_o = vpn_q;
        assign icache_treq_valid_o = treq_valid_q || valid_ireq_q ;

        // mmu into register not used
        assign mmu_tresp_miss_d     = 1'b0;
        assign mmu_tresp_ptw_v_d    = 1'b0;
        assign mmu_tresp_ppn_d      = PPN_BIT_SIZE'(0);
        assign mmu_tresp_xcpt_d     = 1'b0;

        // mmu reponse w/ out reg into i$ ctrl
        assign mmu_tresp_miss     = mmu_tresp_miss_i;
        assign mmu_tresp_ptw_v    = mmu_tresp_ptw_v_i;
        assign mmu_tresp_ppn      = mmu_tresp_ppn_i;
        assign mmu_tresp_xcpt     = mmu_tresp_xcpt_i;
    end
endgenerate

//- Split virtual address into index and offset to address cache arrays.
assign vaddr_index = valid_inv ? ifill_resp_inv_paddr_i[ICACHE_IDX_WIDTH:1] : 
                                 idx_d[ICACHE_INDEX_WIDTH-1:ICACHE_OFFSET_WIDTH];
                                 //vaddr_in[ICACHE_INDEX_WIDTH-1:ICACHE_OFFSET_WIDTH];
                     
assign cline_tag_d  = mmu_tresp_ppn ;
                                                                
// vaddr in fly 
assign icache_resp_vaddr_o = {vpn_q,idx_q};

// pass exception through
logic icache_resp_valid ; 
assign icache_resp_xcpt_o = mmu_tresp_xcpt && icache_resp_valid;

if (KILL_RESP) begin
    assign icache_resp_valid_o = icache_resp_valid && !ireq_kill_d;
end
else begin
    assign icache_resp_valid_o = icache_resp_valid;
end
//---------------------------------------------------------------------
//------------------------------------------------------ IFILL request.

assign icache_ifill_req_paddr_o = {cline_tag_d,idx_q[11:ICACHE_OFFSET_WIDTH],{{ICACHE_OFFSET_WIDTH}{1'b0}}};

assign icache_ifill_req_valid_o = ifill_req_valid  && !ireq_kill_d ;

//-----------------------------------------------------------------------
assign valid_ifill_resp = ifill_resp_valid_i & ~ifill_resp_inv_valid_i;

assign ifill_req_was_sent_d = icache_ifill_req_valid_o | 
                              (ifill_req_was_sent_q & ~valid_ifill_resp);

assign ifill_process_started_d = ifill_resp_valid_i ;
//assign ifill_process_started_d = ((ifill_resp_beat_i == 2'b00) && ifill_resp_valid_i) ? 1'b1 :
//                                  (valid_ifill_resp) ? 1'b0 : ifill_process_started_q;

//assign block_invalidate = ifill_process_started_q && ireq_kill_d ; 

assign valid_bit = valid_inv ? 1'b0 : tag_we_valid & ~ireq_kill_d & ~ireq_kill_q ;
                                         
assign tag_we = tag_we_valid ;

sargantana_icache_ctrl #(
    .ICACHE_N_WAY       ( ICACHE_N_WAY              )
)  icache_ctrl (
    .clk_i              ( clk_i                     ),
    .rstn_i             ( rstn_i                    ),
    .cache_enable_i     ( 1'b1                      ),
    .flush_i            ( is_flush_q                ),
    .flush_done_i       ( 1'b0                      ),
    .cmp_enable_o       (  cmp_enable               ),
    .invalidation       ( valid_inv                 ),
    .cache_rd_ena_o     ( cache_rd_ena              ),
    .cache_wr_ena_o     ( cache_wr_ena              ),
    .ireq_valid_i       ( valid_ireq_q              ),
    .ireq_kill_i        ( ireq_kill_q               ),
    .ireq_kill_d        ( ireq_kill_d               ),
    .iresp_ready_o      ( ctrl_ready                ),
    .iresp_valid_o      ( icache_resp_valid         ),
    .mmu_miss_i         ( mmu_tresp_miss            ),
    .mmu_ptw_valid_i    ( mmu_tresp_ptw_v           ),
    .mmu_ex_valid_i     ( mmu_tresp_xcpt            ),
    .treq_valid_o       ( treq_valid                ),
    .valid_ifill_resp_i ( valid_ifill_resp          ),
    .ifill_resp_valid_i ( valid_ifill_resp          ),
    .ifill_sent_ack_i   ( ifill_req_was_sent_d      ),
    .ifill_req_valid_o  ( ifill_req_valid           ),
    .cline_hit_i        ( cline_hit                 ),   
    .miss_o             ( imiss_time_pmu_o          ),                       
    .miss_kill_o        ( imiss_kill_pmu_o          ),                       
    .replay_valid_o     ( replay_valid              ),                       
    .flush_en_o         (flush_enable               )        
);                                          

assign icache_resp_ready_o = ctrl_ready &~ valid_inv ;

sargantana_top_memory #(
    .ICACHE_N_WAY   ( ICACHE_N_WAY   ),
    .TAG_DEPTH      ( TAG_DEPTH      ),
    .TAG_ADDR_WIDHT ( TAG_ADDR_WIDHT ),
    .SET_WIDHT      ( SET_WIDHT      ),
    .WAY_WIDHT      ( WAY_WIDHT      ),
    .TAG_WIDHT      ( TAG_WIDHT      ),
    .ADDR_WIDHT     ( ADDR_WIDHT     )
) icache_memory(
    `ifdef INTEL_PHYSICAL_MEM_CTRL
    .hduspsr_mem_ctrl ( hduspsr_mem_ctrl ),
    `endif
    .clk_i          ( clk_i  ),
    .rstn_i         ( rstn_i ),
    .tag_req_i      ( tag_req_valid  ),
    .data_req_i     ( data_req_valid ),
    .tag_we_i       ( tag_we  ),
    .data_we_i      ( cache_wr_ena ),
    .flush_en_i     ( is_flush_d ),
    .valid_bit_i    ( valid_bit),
    .cline_i        ( ifill_resp_data_i ),
    .tag_i          ( cline_tag_q ),
    .addr_i         ( addr_valid ),
    .tag_way_o      ( way_tags  ), 
    .cline_way_o    ( cline_data_rd ), 
    .valid_bit_o    ( way_valid_bits )  
);

assign cache_rd_valid = valid_ireq_d | cache_rd_ena ;

sargantana_icache_replace_unit #(
    .ICACHE_N_WAY       ( ICACHE_N_WAY ),
    .ICACHE_IDX_WIDTH   ( ICACHE_IDX_WIDTH )
) replace_unit(
    .clk_i          ( clk_i            ),
    .rstn_i         ( rstn_i           ),
    .inval_i        ( valid_inv        ),
    .cline_index_i  ( vaddr_index      ),
    .cache_rd_ena_i ( cache_rd_valid ),
    .cache_wr_ena_i ( cache_wr_ena     ),
    .flush_ena_i    ( flush_enable     ),
    .way_valid_bits_i ( way_valid_bits      ),
    .we_valid_o     ( tag_we_valid     ),
    .addr_valid_o   ( addr_valid       ),
    .cmp_en_q       ( cmp_enable_q       ),
    .way_to_replace_q ( way_to_replace_q      ),
    .way_to_replace_d ( way_to_replace_d      ),
    //.way_to_replace_o ( icache_ifill_req_way_o ),
    .data_req_valid_o  ( data_req_valid        ),
    .tag_req_valid_o  ( tag_req_valid        )
);


sargantana_icache_checker #(
    .LINES_256          ( LINES_256),

    .ICACHE_N_WAY       ( ICACHE_N_WAY        ),
    .TAG_WIDHT          ( TAG_WIDHT           ),
    .WAY_WIDHT          ( WAY_WIDHT           ),
    .FETCH_WIDHT        ( FETCH_WIDHT         )
) ichecker(
    .read_tags_i        ( way_tags            ),
    .cline_tag_d        ( cline_tag_d         ),
    .fetch_idx_i        ( idx_q[5:4]          ),
    .way_valid_bits_i   ( way_valid_bits      ),
    .data_rd_i          ( cline_data_rd       ),
    .cline_hit_o        ( cline_hit           ),
    .data_o             ( icache_resp_data_o  )
);


sargantana_icache_ff #(
    .ICACHE_N_WAY       ( ICACHE_N_WAY      ),
    .PPN_BIT_SIZE       ( PPN_BIT_SIZE      ),
    .ICACHE_TAG_WIDTH   ( ICACHE_TAG_WIDTH  ),
    .IDX_BITS_SIZE      ( IDX_BITS_SIZE     ),
    .VPN_BITS_SIZE      ( VPN_BITS_SIZE     )
) icache_ff(
    .clk_i              ( clk_i             ),
    .rstn_i             ( rstn_i            ),
    //.vaddr_d            ( vaddr_d           ),
    //.vaddr_q            ( vaddr_q           ),
    .vpn_d              ( vpn_d             ),
    .vpn_q              ( vpn_q             ),
    .idx_d              ( idx_d             ),
    .idx_q              ( idx_q             ),
    .flush_d            ( is_flush_d        ),
    .flush_q            ( is_flush_q        ),
    .cline_tag_d        ( cline_tag_d       ),
    .cline_tag_q        ( cline_tag_q       ),
    .cmp_enable_d       ( cmp_enable        ),
    .cmp_enable_q       ( cmp_enable_q      ),
    .way_to_replace_q   ( way_to_replace_q  ),
    .way_to_replace_d   ( way_to_replace_d  ),
    .valid_ireq_d       (valid_ireq_d),
    .valid_ireq_q       (valid_ireq_q),
    .ireq_kill_d        (ireq_kill_d ),
    .ireq_kill_q        (ireq_kill_q ),
    .ifill_process_started_d (ifill_process_started_d),
    .ifill_process_started_q (ifill_process_started_q ),
    .mmu_tresp_miss_d   ( mmu_tresp_miss_d  ),
    .mmu_tresp_ptw_v_d  ( mmu_tresp_ptw_v_d ),
    .mmu_tresp_ppn_d    ( mmu_tresp_ppn_d   ),
    .mmu_tresp_xcpt_d   ( mmu_tresp_xcpt_d  ),
    .mmu_tresp_miss_q   ( mmu_tresp_miss_q  ),
    .mmu_tresp_ptw_v_q  ( mmu_tresp_ptw_v_q ),
    .mmu_tresp_ppn_q    ( mmu_tresp_ppn_q   ),
    .mmu_tresp_xcpt_q   ( mmu_tresp_xcpt_q  ),
    .cache_enable_d     ( ifill_req_was_sent_d ),
    .cache_enable_q     ( ifill_req_was_sent_q )
);



endmodule
