PROJECT_DIR = $(abspath .)

FILELIST = $(PROJECT_DIR)/filelist.f

# *** Simulators ***
include simulator/simulator.mk

sim: $(SIMULATOR)

# *** ISA Tests ***
include tb/tb_isa_tests/isa-tests.mk

# *** Benchmarks ***
include benchmarks.mk

# *** Torture Tests ***
include tb/tb_torture/torture.mk

# *** MEEP FPGA simulator ***
include fpga/meep_shell/simulator/simulator.mk

sim-meep: $(MEEP_SIMULATOR)

# *** CI rules ***
lint-verilator:
		verilator --lint-only -Wwarn-lint -f filelist.f --error-limit 10000

lint-spyglass:
		./scripts/lint_spyglass.sh