#include "dpi_checkpoint.h"

#include "verilated.h"
#include "Vsim_top.h"
#include <cassert>
#include <stack>
#include <iostream>
#include <fstream>
#include <iomanip>
#include <string>

using std::string;
using std::vector;

// Construct the Verilated model, from Vtop.h generated from Verilating
Vsim_top *topp;
uint64_t main_time;
VerilatedContext *contextp;

void save_model(const char* filename) {
    VerilatedSave os;
    os.open(filename);
    main_time = contextp->time();
    os << main_time;  // user code must save the timestamp
    os << *topp;
    os << memoryContents; // should this be a pointer?
}

void restore_model(const char* filename) {
    VerilatedRestore os;
    os.open(filename);
    os >> main_time;
    os >> *topp;
    os >> memoryContents;
    contextp->time(main_time);
}

int main(int argc, char** argv) {
    // Setup context, defaults, and parse command line
    Verilated::debug(0);
    contextp = new VerilatedContext;
    contextp->traceEverOn(true);
    contextp->commandArgs(argc, argv);

    // Construct the Verilated model, from Vtop.h generated from Verilating
    topp = new Vsim_top{contextp};

    bool checkpoint_restore = false;
    string checkpointRestoreFileName = "verilator_model_1.bin";

    vector<string> args(argv + 1, argv + argc);
    vector<string>::iterator tail_args = args.end();

    for(vector<string>::iterator it = args.begin(); it != args.end(); ++it) {
        if (it->find("+checkpoint_restore_ON") == 0) {
            checkpoint_restore = true;
        }
        else if (it->find("+checkpoint_restore_name=") == 0) {
            checkpointRestoreFileName = it->substr(strlen("+checkpoint_restore_name="));
        }
    }

    topp->tb_clk = 0;
    topp->tb_rstn = 0;
    topp->eval();

    if (checkpoint_restore) {
        restore_model(checkpointRestoreFileName.c_str());
        fprintf(stderr, "Checkpoint restored\n");
    }

    // Simulate until $finish
    while (!contextp->gotFinish()) {
        contextp->timeInc(1);
        topp->tb_clk = !topp->tb_clk;
        if (contextp->time() > 0 && contextp->time() < 5) {
            topp->tb_rstn = 0;  // Assert reset
        } else {
            topp->tb_rstn = 1;  // Deassert reset
        }
        // Evaluate model
        topp->eval();
        // Advance time
        //if (!topp->eventsPending()) break;
        //contextp->time(topp->nextTimeSlot());
    }

    if (!contextp->gotFinish()) {
        VL_DEBUG_IF(VL_PRINTF("+ Exiting without $finish; no events left\n"););
    }

    // Final model cleanup
    topp->final();
    delete topp;
    delete contextp;
    return 0;
}



