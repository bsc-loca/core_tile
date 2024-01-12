# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased - Current version

### Added

### Changed

### Fixed

## 2.0.0 - Add OpenPiton Support

### Added

- [Tile] OpenPiton support
- [Tile] Parametric memory map
- [Tile] Parametric physical address size

### Changed

- [CSR & Sargantana] Change hartid to a 64 bit register, allowing for a 18446744073709551615-core SoC.

### Fixed

- [MISC] Linting issues with various tools in various places

## 1.1.0 - Add MEEP Shell FPGA infrastructure & misc. fixes

### Added

- [Tile] MEEP-Shell FPGA emulation of Core Tile with Sargantana
- [Tile] Simulation of MEEP-Shell FPGA infrastructure

### Fixed

- [MMU] Fix dirty bit behavior when mstatus.sum = 1
- [MMU] Fix access bit behavior when mstatus.mxr = 1
- [MMU] Fix non-zero 63:54 bits in PTE do not cause a page fault
- [Sargantana] Fix wrong finish bit value in PMRQ new entries
- [CSR & Sargantana] Fix CSRs PC size to 64 (previously was the physical size, contrary to RISC-V's specs)
- [PMU & Sargantana] Fix unconnected PMU signals
- [PMU & Sargantana] Fix flipped load/store counters
- [Tile] Fix duplicated requests from Tile to HPDC due to delayed responses.

## 1.0.0 - 2023-11-08

### Added

- Initial Release