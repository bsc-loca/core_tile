/*
 *  Authors       : Arnau Bigas
 *  Creation Date : January, 2025
 *  Description   : Sargantana macros for defining HPDcache types
 *  History       :
 */
`ifndef __SARGANTANA_TYPEDEF_SVH__
`define __SARGANTANA_TYPEDEF_SVH__

`include "hpdcache_typedef.svh"

// Builds an HPDC Configuration based on a Drac Cfg core configuration
function automatic hpdcache_pkg::hpdcache_cfg_t sargBuildHPDCCfg(input drac_pkg::drac_cfg_t DracCfg);
    hpdcache_pkg::hpdcache_user_cfg_t HPDcacheUserCfg = '{
        // 2 requesters: Core and MMU
        nRequesters: 2,
        // Address and word size as configured in drac_pkg
        paWidth: drac_pkg::PHY_ADDR_SIZE,
        wordWidth: riscv_pkg::XLEN,
        // Configure size, associativity and cacheline size via config parameter
        sets: DracCfg.DCacheNumSets,
        ways: DracCfg.DCacheNumWays,
        clWords: DracCfg.DCacheLineWidth / riscv_pkg::XLEN,
        // Configure the request to access the whole cacheline
        reqWords: DracCfg.DCacheLineWidth / riscv_pkg::XLEN,
        // Core is configured to support 7 bit IDs, currently hardcoded!
        reqTransIdWidth: 7,
        // Up to 8 requesters
        reqSrcIdWidth: 3,
        // Use Pseudo-LRU
        victimSel: hpdcache_pkg::HPDCACHE_VICTIM_PLRU,
        // Put two ways side-by-side on an SRAM line
        dataWaysPerRamWord: 2,
        // Put all the sets in the same SRAM (TODO: Confirm with Cesar)
        dataSetsPerRam: DracCfg.DCacheNumSets,
        // Use byte-enable SRAMs
        dataRamByteEnable: 1'b1,
        // Access the whole cacheline in a single cycle, for request & refills
        accessWords: DracCfg.DCacheLineWidth / riscv_pkg::XLEN,
        // Configure the MSHRs via the config parameter
        mshrSets: DracCfg.DCacheMSHRSets,
        mshrWays: DracCfg.DCacheMSHRWays,
        // Store 2 ways per SRAM line
        mshrWaysPerRamWord: 2,
        mshrSetsPerRam: DracCfg.DCacheMSHRSets,
        mshrRamByteEnable: 1'b0,
        // Use SRAMs for the MSHRs
        mshrUseRegbank: 0,
        // Bypass data to the core when refilling
        refillCoreRspFeedthrough: 1'b1,
        refillFifoDepth: DracCfg.DCacheRefillFIFODepth,
        // Configure the write buffer entries via the config parameter
        wbufDirEntries: DracCfg.DCacheWBUFSize,
        wbufDataEntries: DracCfg.DCacheWBUFSize,
        // Have a whole cacheline in each write buffer entry.
        // Caution! It says words, but really it's the width of the core request!
        wbufWords: 1,
        wbufTimecntWidth: 3,
        // Number of replay table entries
        rtabEntries: 8,
        // Number of invalidation entries
        flushEntries: 4,
        flushFifoDepth: 2,
        // Memory interface parameters, configured via the config parameter
        memAddrWidth: DracCfg.MemAddrWidth,
        memIdWidth: DracCfg.MemIDWidth,
        memDataWidth: DracCfg.MemDataWidth,
        // Write-through or Write-back configuration, depending on config parameter
        // Only allows one or the other
        wtEn: DracCfg.DCacheWTNotWB ? 1'b1 : 1'b0,
        wbEn: DracCfg.DCacheWTNotWB ? 1'b0 : 1'b1,
        lowLatency: 1'b1
    };

    return hpdcache_pkg::hpdcacheBuildConfig(HPDcacheUserCfg);
endfunction

// Builds the HPDC core request and response types based on the HPDC configuration
// See `sargBuildHPDCCfg` on how to build the HPDC config from the Core config
`define SARGANTANA_TYPEDEF_HPDC_REQ_RSP(__hpdc_cfg) \
    `HPDCACHE_TYPEDEF_REQ_ATTR_T(hpdcache_req_offset_t, hpdcache_data_word_t, hpdcache_data_be_t, \
                                hpdcache_req_data_t, hpdcache_req_be_t, hpdcache_req_sid_t, \
                                hpdcache_req_tid_t, hpdcache_tag_t, __hpdc_cfg); \
    `HPDCACHE_TYPEDEF_REQ_T(hpdcache_req_t, hpdcache_req_offset_t, hpdcache_req_data_t, \
                            hpdcache_req_be_t, hpdcache_req_sid_t, hpdcache_req_tid_t, \
                            hpdcache_tag_t); \
    `HPDCACHE_TYPEDEF_RSP_T(hpdcache_rsp_t, hpdcache_req_data_t, hpdcache_req_sid_t, \
                            hpdcache_req_tid_t);

`endif //  __SARGANTANA_TYPEDEF_SVH__
