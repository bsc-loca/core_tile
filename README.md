# Sargantana Tile

This module includes the [Sargantana](https://gitlab.bsc.es/hwdesign/rtl/cores/sargantana) core, as well as the iCache, dCache (HPDCache from OpenHardware), and MMU to make it all work.

## Table of Contents

- [Sargantana Tile](#sargantana-tile)
  - [Table of Contents](#table-of-contents)
  - [1. Installing the dependencies](#1-installing-the-dependencies)
  - [2. Building the simulator](#2-building-the-simulator)
    - [2.1 Verilator](#21-verilator)
    - [2.2 Questasim](#22-questasim)
  - [3. Building tests and benchmarks](#3-building-tests-and-benchmarks)
  - [4. Running simulations](#4-running-simulations)
    - [4.1 Optional parameters](#41-optional-parameters)
    - [4.2 Running the ISA tests or benchmarks](#42-running-the-isa-tests-or-benchmarks)

## 1. Installing the dependencies

The following software is required to build the basic simulator internals, bootrom, and the RISC-V tests and benchmarks:

- `gcc >= 10.5`
- `riscv64-unknown-elf-gcc >= 12.0`
- `device-tree-compiler` (any recent version should work)
- `libboost-regex-dev >= 1.53`

The following table provides the simulators supported and the minimum versions:

| Simulator | Minimum Version |
|-----------|-----------------|
| Verilator | 5.004           |
| Questasim | 2021.3          |

Optionally, to visualize waveforms the following software can be used:

- `gtkwave` (any recent version should work)

Optionally, to visualize pipeline diagrams, the following software can be used:

- `konata >= v0.34`

## 2. Building the simulator

### 2.1 Verilator

To build the simulator run `make -j$(nproc) sim` from the root folder of the project. That should build the bootrom and the simulator itself (as well as some needed libraries from `riscv-isa-sim`).

### 2.2 Questasim

To use questasim, first compile the bootrom and helper libraries using `make -j$(nproc) bootrom.hex libdisasm`. Everything else will be compiled by Questasim at runtime.

> [!NOTE]  
> This only needs to be done once. If the RTL changes, Questasim will re-compile those files each time it is run.

## 3. Building tests and benchmarks

Before being able to do any simulations, we need to build the binaries to simulate.
If you already have those, you can skip to section [4. Running simulations](#4-running-simulations).

The ISA tests are a basic set of tests checking most ISA instructions and the general working of the core.
To build the ISA tests run the following command:

`make -j$(nproc) build-isa-tests`

The benchmarks available are from the `riscv-tests` repository, plus some custom ones which check basic performance characteristics of the core.
To build the benchmarks run the following command:

`make -j$(nproc) build-benchmarks`

## 4. Running simulations

To run a simulation using **Verilator**, use the following command:

`./sim +load=<path/to/binary>`

To run a simulation using **Questasim**, use the following command:

`./simulator/questa/sim.sh +load=<path/to/binary>`

> [!TIP]
> If you want to run Questasim without the GUI, add `-c` to the command line above.

> [!CAUTION]  
> Depending on the Questasim installation, it could use an incompatible GCC to compile the simulator's internals. If that's the case, you will see an error message mentioning the version of GCC (which, if it's older than `10.5`, won't work). To fix this, you can modify the `./simulator/questa/sim.sh` script to add the following parameter in the `vlog` and `vsim` commands: `-cpppath <path/to/good/gcc>`.

### 4.1 Optional parameters

- `+vcd[=path/to/waveform.vcd]` Generates a waveform of the simulation. By default, it will save it as `dump.vcd`.
- `+commit_log[=path/to/log.txt]` Generates a log of the commited instructions. By default, it will save it as `signature.txt`.
- `+konata_dump[=path/to/konata.txt]` Generates a dump of the pipeline to later be visualized as a pipeline diagram using konata. By default, it will save it as `konata.txt`.
- `+checkpoint_Mcycles=N` Generates a snapshot of the design model every N million cycles. It saves the last 2 checkpoints (suffixed with _1 and _2) and overwrites the oldest one when creating a third one. Only enabled when using **Verilator**.
- `+checkpoint_name=path/to/checkpoint` Change the file name and path of the verilator checkpoint to save. By default, it is `verilator_model`. You should not include a file extension as the simulation suffixes the name with `_1.bin` and `_2.bin`. Only enabled when using **Verilator**.
- `+checkpoint_restore_ON` Resumes simulation from the model checkpoint file. By default, it is `verilator_model_1.bin`. Does not work if the verilator binary is not same as when it was created. Only enabled when using **Verilator**. 
- `+checkpoint_restore_name=path/to/checkpoint.bin` Change the file name and path of the verilator checkpoint to resume from. Only enabled when using **Verilator**.

The output of all the optional parameters can be overriden by appending `=` and the path of the desired output.

### 4.2 Running the ISA tests or benchmarks

You can run all test or benchmarks using `make run-isa-tests` or `make run-benchmarks` respectively.

The individual programs can be run individually using:
- `<simulator> +load=<tb/tb_isa_tests/build/isa/<binary>` or
- `<simulator> +load=<benchmarks/benchmarks/<binary>`
