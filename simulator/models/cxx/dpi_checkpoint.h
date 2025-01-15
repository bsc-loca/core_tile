#ifndef DPI_CHECKPOINT_H
#define DPI_CHECKPOINT_H

#include "riscv/isa_parser.h"
#include <svdpi.h>
#include <iostream>
#include <fstream>
#include <stdlib.h>
#include <string>
#include <riscv/disasm.h>
#include <map>
#include "verilated_save.h"
#include "dpi_perfect_memory.h"

#ifdef __cplusplus
extern "C" {
#endif

extern void save_model(const char* filename);

void restore_model(const char* filename);

int main(int argc, char** argv);

#ifdef __cplusplus
}
#endif

template <class T_Key, class T_Value>
inline VerilatedSerialize& operator<<(VerilatedSerialize& os, std::map<T_Key, T_Value>& rhs) {
    vluint32_t len = rhs.size();
    os << len;
    for (const auto& i : rhs) {
        T_Key index = i.first;  // Copy to get around const_iterator
        T_Value value = i.second;
        os << index << value;
    }
    return os;
}
template <class T_Key, class T_Value>
inline VerilatedDeserialize& operator>>(VerilatedDeserialize& os, std::map<T_Key, T_Value>& rhs) {
    vluint32_t len = 0;
    os >> len;
    rhs.clear();
    for (vluint32_t i = 0; i < len; ++i) {
        T_Key index;
        T_Value value;
        os >> index;
        os >> value;
        rhs[index] = value;
    }
    return os;
}

inline VerilatedSerialize& operator<<(VerilatedSerialize& os, Memory32& rhs) {
    os << rhs.mem;
    os << rhs.addr_max;
    os << symbols;
    os << reverseSymbols;
    return os; 
}

inline VerilatedDeserialize& operator>>(VerilatedDeserialize& os, Memory32& rhs) {
    os >> rhs.mem;
    os >> rhs.addr_max;
    os >> symbols;
    os >> reverseSymbols;
    return os; 
}

#endif