#include "dpi_konata.h"
#include <iostream>
#include <fstream>
#include <iomanip>
#include <string>
#include <riscv/disasm.h>

#define HEX_PC( x ) "0x" << std::setw(16) << std::setfill('0') << std::hex << (long)( x )
#define HEX_INST( x ) "0x" << std::setw(8) << std::setfill('0') << std::hex << (long)( x )
#define HEX_DATA( x ) "0x" << std::setw(16) << std::setfill('0') << std::hex << (long)( x )
#define DEC_DST( x ) "x" << std::setw(2) << std::setfill(' ') << std::dec << (long)( x )
#define DEC_PRIV( x ) std::setw(1) << std::dec << (long)( x )

// Global objects
konataSignature *konata_signature;
disassembler_t *disassembler;
isa_parser_t *isa;

// Global Variables
uint64_t last_pc=0, cycles=1, last_if1_id=1, last_if2_id=1;

// System Verilog DPI
void konata_dump (unsigned long long if1_valid,
                            unsigned long long if2_valid,
                            unsigned long long id_valid,
                            unsigned long long ir_valid,
                            unsigned long long rr_valid,
                            unsigned long long exe_valid,
                            unsigned long long wb1_valid,
                            unsigned long long wb2_valid,
                            unsigned long long wb3_valid,
                            unsigned long long wb4_valid,
                            unsigned long long wb1_fp_valid,
                            unsigned long long wb2_fp_valid,
                            unsigned long long wb1_simd_valid,
                            unsigned long long wb2_simd_valid,
                            unsigned long long wb_store_valid,
                            unsigned long long if1_stall,
                            unsigned long long if2_stall,
                            unsigned long long id_stall,
                            unsigned long long ir_stall,
                            unsigned long long rr_stall,
                            unsigned long long exe_stall,
                            unsigned long long if1_flush,
                            unsigned long long if2_flush,
                            unsigned long long id_flush,
                            unsigned long long ir_flush,
                            unsigned long long rr_flush,
                            unsigned long long exe_flush, 
                            unsigned long long id_pc,
                            unsigned long long id_inst,
                            unsigned long long if1_id,
                            unsigned long long if2_id,
                            unsigned long long id_id,
                            unsigned long long ir_id,
                            unsigned long long rr_id,
                            unsigned long long exe_id, 
                            unsigned long long exe_unit,
                            unsigned long long wb1_id,
                            unsigned long long wb2_id,
                            unsigned long long wb3_id,
                            unsigned long long wb4_id,
                            unsigned long long wb1_fp_id,
                            unsigned long long wb2_fp_id,
                            unsigned long long wb1_simd_id,
                            unsigned long long wb2_simd_id,
                            unsigned long long wb_store_id){

    konata_signature->dump_file(if1_valid, if2_valid, id_valid, rr_valid, ir_valid, exe_valid, 
                                wb1_valid, wb2_valid, wb3_valid, wb4_valid, wb1_fp_valid, wb2_fp_valid, wb1_simd_valid, wb2_simd_valid, wb_store_valid, if1_stall, if2_stall, id_stall, ir_stall,
                                rr_stall, exe_stall, if1_flush, if2_flush, id_flush, ir_flush, rr_flush, exe_flush, id_pc,
                                id_inst, if1_id, if2_id, id_id, ir_id, rr_id, exe_id, exe_unit, wb1_id, wb2_id, wb3_id, wb4_id, wb1_fp_id, wb2_fp_id, wb1_simd_id, wb2_simd_id, wb_store_id);
}

void konata_signature_init(const char *dumpfile){
    konata_signature = new konataSignature(dumpfile);
    isa = new isa_parser_t("rv64imaf", "msu");
    disassembler = new disassembler_t(isa);
}

// End of SystemVerilog DPI

konataSignature::konataSignature(const char *dumpfile) {
	signature = (uint64_t*) calloc(32,sizeof(uint64_t));
    signatureFileName = dumpfile;
    signatureFile.open(signatureFileName, std::ios::out);
    signatureFile << "Kanata\t0004\n";
}

void konataSignature::dump_file(unsigned long long if1_valid,
                            unsigned long long if2_valid,
                            unsigned long long id_valid,
                            unsigned long long ir_valid,
                            unsigned long long rr_valid,
                            unsigned long long exe_valid,
                            unsigned long long wb1_valid,
                            unsigned long long wb2_valid,
                            unsigned long long wb3_valid,
                            unsigned long long wb4_valid,
                            unsigned long long wb1_fp_valid,
                            unsigned long long wb2_fp_valid,
                            unsigned long long wb1_simd_valid,
                            unsigned long long wb2_simd_valid,
                            unsigned long long wb_store_valid,
                            unsigned long long if1_stall,
                            unsigned long long if2_stall,
                            unsigned long long id_stall,
                            unsigned long long ir_stall,
                            unsigned long long rr_stall,
                            unsigned long long exe_stall,
                            unsigned long long if1_flush,
                            unsigned long long if2_flush,
                            unsigned long long id_flush,
                            unsigned long long ir_flush,
                            unsigned long long rr_flush,
                            unsigned long long exe_flush, 
                            unsigned long long id_pc,
                            unsigned long long id_inst,
                            unsigned long long if1_id,
                            unsigned long long if2_id,
                            unsigned long long id_id,
                            unsigned long long ir_id,
                            unsigned long long rr_id,
                            unsigned long long exe_id, 
                            unsigned long long exe_unit,
                            unsigned long long wb1_id,
                            unsigned long long wb2_id,
                            unsigned long long wb3_id,
                            unsigned long long wb4_id,
                            unsigned long long wb1_fp_id,
                            unsigned long long wb2_fp_id,
                            unsigned long long wb1_simd_id,
                            unsigned long long wb2_simd_id,
                            unsigned long long wb_store_id){

    //We need to extend the PC sign
    signed long long signedPC = id_pc;
    signedPC = signedPC << 24;
    signedPC = signedPC >> 24;

    if(!((if1_valid && !if1_stall) || (if2_valid && !if2_stall) || (id_valid && !id_stall) ||
         (exe_valid && !exe_stall) || (ir_valid  && !ir_stall) || (rr_valid  && !rr_stall) || wb1_valid || wb2_valid || wb3_valid || wb4_valid || wb1_fp_valid || wb2_fp_valid || wb1_simd_valid || wb2_simd_valid ||
         if1_flush || if2_flush || id_flush || 
         ir_flush || rr_flush || exe_flush)){
        cycles++;
    }else{
        signatureFile << "C\t" << std::dec << cycles << "\n";
        if (if1_valid && !if1_stall && !if1_flush){
            if (last_if1_id != if1_id) {
                signatureFile << "I\t" << std::dec << if1_id << "\t" << std::dec << if1_id << "\t" << 0 << "\n";
                signatureFile << "S\t" << std::dec << if1_id << "\t" << std::dec << 0 << "\tF1" << "\n";
            }
        }
        if(if2_flush){
            signatureFile << "R\t" << std::dec << if2_id << "\t" << std::dec << if2_id << "\t" << 1 << "\n";
        }else if(if2_valid && !if2_stall){
            if (last_if2_id != if2_id) {
                signatureFile << "E\t" << std::dec << if2_id << "\t" << std::dec << 0 << "\tF1" << "\n";
                signatureFile << "S\t" << std::dec << if2_id << "\t" << std::dec << 0 << "\tF2" << "\n";
            }
        }
        if(id_flush){
            signatureFile << "R\t" << std::dec << id_id << "\t" << std::dec << id_id << "\t" << 1 << "\n";
        }else if(id_valid && !id_stall){
            signatureFile << "L\t" << std::dec << id_id << "\t" << std::dec << 0 << "\t" << HEX_PC( signedPC ) << ": " << disassembler->disassemble(insn_t(id_inst)) << "\n";
            signatureFile << "E\t" << std::dec << id_id << "\t" << std::dec << 0 << "\tF2" << "\n";
            signatureFile << "S\t" << std::dec << id_id << "\t" << std::dec << 0 << "\tD" << "\n";
        }
        if(ir_flush){
            signatureFile << "R\t" << std::dec << ir_id << "\t" << std::dec << ir_id << "\t" << 1 << "\n";
        }else if(ir_valid && !ir_stall){
            signatureFile << "E\t" << std::dec << ir_id << "\t" << std::dec << 0 << "\tD" << "\n";
            signatureFile << "S\t" << std::dec << ir_id << "\t" << std::dec << 0 << "\tI" << "\n";
        }
        if(rr_flush){
            signatureFile << "R\t" << std::dec << rr_id << "\t" << std::dec << rr_id << "\t" << 1 << "\n";
        }else if(rr_valid && !rr_stall){
            signatureFile << "E\t" << std::dec << rr_id << "\t" << std::dec << 0 << "\tI" << "\n";
            signatureFile << "S\t" << std::dec << rr_id << "\t" << std::dec << 0 << "\tR" << "\n";
        }
        if(exe_flush){
            signatureFile << "R\t" << std::dec << exe_id << "\t" << std::dec << exe_id << "\t" << 1 << "\n";
        }else if(exe_valid && !exe_stall){
            signatureFile << "E\t" << std::dec << exe_id << "\t" << std::dec << 0 << "\tR" << "\n";
            switch (exe_unit) {
                case 0: //ALU
                    signatureFile << "S\t" << std::dec << exe_id << "\t" << std::dec << 0 << "\tA" << "\n";
                    break;
                case 1: //DIV
                    signatureFile << "S\t" << std::dec << exe_id << "\t" << std::dec << 0 << "\tDIV" << "\n";
                    break;
                case 2: //MUL
                    signatureFile << "S\t" << std::dec << exe_id << "\t" << std::dec << 0 << "\tMUL" << "\n";
                    break;
                case 3: //BRANCH
                    signatureFile << "S\t" << std::dec << exe_id << "\t" << std::dec << 0 << "\tB" << "\n";
                    break;
                case 4: //MEM
                    signatureFile << "S\t" << std::dec << exe_id << "\t" << std::dec << 0 << "\tM" << "\n";
                    break;
                case 5: //SIMD
                    signatureFile << "S\t" << std::dec << exe_id << "\t" << std::dec << 0 << "\tV" << "\n";
                    break;
                case 6: //FPU
                    signatureFile << "S\t" << std::dec << exe_id << "\t" << std::dec << 0 << "\tFP" << "\n";
                    break;
                default: //CONTROL or SYSTEM
                    signatureFile << "S\t" << std::dec << exe_id << "\t" << std::dec << 0 << "\tE" << "\n";
                    break;
            }
        }
        if(wb1_valid){
            signatureFile << "R\t" << std::dec << wb1_id << "\t" << std::dec << wb1_id << "\t" << 0 << "\n";
        }
        if(wb2_valid){
            signatureFile << "R\t" << std::dec << wb2_id << "\t" << std::dec << wb2_id << "\t" << 0 << "\n";
        }
        if(wb3_valid){
            signatureFile << "R\t" << std::dec << wb3_id << "\t" << std::dec << wb3_id << "\t" << 0 << "\n";
        }
        if(wb4_valid){
            signatureFile << "R\t" << std::dec << wb4_id << "\t" << std::dec << wb4_id << "\t" << 0 << "\n";
        }
        if(wb1_fp_valid){
            signatureFile << "R\t" << std::dec << wb1_fp_id << "\t" << std::dec << wb1_fp_id << "\t" << 0 << "\n";
        }
        if(wb2_fp_valid){
            signatureFile << "R\t" << std::dec << wb2_fp_id << "\t" << std::dec << wb2_fp_id << "\t" << 0 << "\n";
        }
        if(wb1_simd_valid){
            signatureFile << "R\t" << std::dec << wb1_simd_id << "\t" << std::dec << wb1_simd_id << "\t" << 0 << "\n";
        }
        if(wb2_simd_valid){
            signatureFile << "R\t" << std::dec << wb2_simd_id << "\t" << std::dec << wb2_simd_id << "\t" << 0 << "\n";
        }
        if(wb_store_valid){
            signatureFile << "R\t" << std::dec << wb_store_id << "\t" << std::dec << wb_store_id << "\t" << 0 << "\n";
        }
        cycles = 1;
        signatureFile.flush();
    }
    last_if1_id = if1_id;
    if (if2_valid) last_if2_id = if2_id;
}
