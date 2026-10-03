PROJECT_DIR = $(abspath .)

FILELIST = ${PROJECT_DIR}/filelist.f

export HPDCACHE_DIR = $(PROJECT_DIR)/rtl/dcache

# *** Simulators ***
include simulator/simulator.mk

sim: $(SIMULATOR)

# *** ISA Tests ***
include tb/tb_isa_tests/isa-tests.mk

# *** Benchmarks ***
include benchmarks.mk