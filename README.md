# Core Tile

This module includes the [Sargantana](https://github.com/bsc-loca/sargantana) core, as well as the iCache, dCache (HPDCache from OpenHardware), and MMU to make it all work.

## Table of Contents

- [Core Tile](#core-tile)
  - [Table of Contents](#table-of-contents)
  - [1. Installing the dependencies](#1-installing-the-dependencies)
  - [2. Building the simulator](#2-building-the-simulator)
    - [2.1 Verilator](#21-verilator)
    - [2.2 Questasim](#22-questasim)
  - [3. Running simulations](#3-running-simulations)
    - [3.1 Optional parameters](#31-optional-parameters)
    - [3.2 Running the ISA tests or benchmarks](#32-running-the-isa-tests-or-benchmarks)
  - [4. Emulating on an FPGA](#4-emulating-on-an-fpga)
  - [5. Design](#5-design)
  - [6. License](#6-license)
  - [7. Authors](#7-authors)
  - [8. Citation](#8-citation)

## 1. Installing the dependencies

The following software is required to build the simulator, bootrom, and the RISC-V tests and benchmarks:

- `gcc >= 10.5`
- `verilator >= 5.004`
- `riscv64-unknown-elf-gcc >= 12.0`
- `device-tree-compiler` (any recent version should work)

Optionally, to visualize waveforms the following software can be used:

- `gtkwave`

Optionally, to visualize pipeline diagrams, the following software can be used:

- `konata`

## 2. Building the simulator

### 2.1 Verilator

To build the simulator run `make -j$(nproc) sim` from the root folder of the project. That should build the bootrom and the simulator itself (as well as some needed libraries from `riscv-isa-sim`).

### 2.2 Questasim

To use questasim, first compile the bootrom and helper libraries using `make -j$(nproc) bootrom.hex libdisasm`. Everything else will be compiled by Questasim at runtime.

## 3. Running simulations

To run a simulation using **Verilator**, use the following command:

`./sim +load=<path/to/binary>`

To run a simulation using **Questasim** (headless), use the following command:

`./simulator/questa/sim.sh -c -suppress 3999 +load=<path/to/binary>`

To run the simulations using Questasim's GUI, remove the `-c` argument of the previous command.

### 3.1 Optional parameters

- `+vcd[=path/to/waveform.vcd]` Generates a waveform of the simulation. By default, it will save it as `dump.vcd`.
- `+commit_log[=path/to/log.txt]` Generates a log of the commited instructions. By default, it will save it as `signature.txt`.
- `+konata_dump[=path/to/konata.txt]` Generates a dump of the pipeline to later be visualized as a pipeline diagram using konata. By default, it will save it as `konata.txt`.

The output of all the optional parameters can be overriden by appending `=` and the path of the desired output.

### 3.2 Running the ISA tests or benchmarks

1. Build the isa tests or benchmarks using `make -j$(nproc) build-isa-tests` or `make -j$(nproc) build-benchmarks` respectively.
2. Run all test or benchmarks using `make run-isa-tests` or `make run-benchmarks`.

The programs can be run individually using:
- `<simulator> +load=<tb/tb_isa_tests/build/isa/<binary>` or
- `<simulator> +load=<benchmarks/benchmarks/<binary>`

## 4. Emulating on an FPGA

Coming soon.

## 5. Design

Coming soon.

## 6. License

This work is licensed under the Solderpad Hardware License v2.1.

For more information, check the [LICENSE](LICENSE) file.

## 7. Authors

The list of authors can be found in the [CONTRIBUTORS.md](CONTRIBUTORS.md) file.


## 8. Citation

This work is derived and based upon Sargantana:
Víctor Soria-Pardos, Max Doblas, Guillem López-Paradís, Gerard Candón, Narcís Rodas, Xavier Carril, Pau Fontova-Musté, Neiel Leyva, Santiago Marco-Sola, and Miquel Moretó. ["Sargantana: A 1 GHz+ in-order RISC-V processor with SIMD vector extensions in 22nm FD-SOI"](https://upcommons.upc.edu/bitstream/handle/2117/384912/sargantana_preprint.pdf?sequence=1). 25th Euromicro, 2022.
