// See LICENSE for license details.

#ifndef DPI_PERFECT_MEMORY_H
#define DPI_PERFECT_MEMORY_H

#define BUS_WIDTH 512   // Bus size
#define BUS_ADDR_BITS 6 // Bits needed to address a byte within the bus
#define BUS_ADDR_MASK (~((1 << BUS_ADDR_BITS) - 1)) // Mask to align addresses to the bus width

#include <svdpi.h>
#include <string>
#include <map>

#ifdef __cplusplus
extern "C" {
#endif

extern void memory_init(const char *path);

extern void memory_read(const svBitVecVal *addr, svBitVecVal *data);

extern void memory_write(const svBitVecVal *addr, const svBitVecVal *byte_enable, const svBitVecVal *data);

extern void memory_amo(const svBitVecVal *addr, const svBitVecVal *size, const svBitVecVal *amo_op, const svBitVecVal *data, svBitVecVal *result);

extern void memory_symbol_addr(const char *symbol, svBitVecVal *addr);

#ifdef __cplusplus
}
#endif

class Memory32 {                    // data width = 32-bit
    public:
        std::map<uint32_t, uint32_t> mem; // memory storage
        uint32_t addr_max;          // the maximal address, 0 means all 32-bit

        Memory32(uint32_t addr_max);

        Memory32();

        // initialize a memory location with a value
        void init(const uint32_t addr, const uint32_t &data);

        // write a value
        bool write(const uint32_t addr, const uint32_t &data, const uint32_t &mask);
            // burst write
        void write_block(uint32_t addr, uint32_t size, const uint8_t* buf);
        // read a value
        bool read(const uint32_t addr, uint32_t &data);

        uint32_t max_addr() const;
};

extern Memory32 memoryContents;
extern std::map<std::string, uint64_t> symbols;
extern std::map<uint64_t, std::string> reverseSymbols;

void memory_enable_read_debug();

std::string memory_symbol_from_addr(uint64_t addr);

uint32_t memory_dpi_read_contents(uint64_t addr);
void memory_dpi_write_contents(uint64_t addr, uint32_t data);
uint64_t memory_dpi_get_symbol_addr(const char *symbol);

#endif //DPI_PERFECT_MEMORY_H