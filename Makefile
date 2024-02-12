PROJECT_DIR = $(abspath .)

FILELIST = $(PROJECT_DIR)/filelist.f

DV_DIR = $(PROJECT_DIR)/verif
CORE_UVM_DIR = $(DV_DIR)/core_uvm
CORE_UVM_REPO = git@gitlab-internal.bsc.es:hwdesign/verification/core-uvm.git
CORE_UVM_BRANCH = sargantana_mode_changes

RISCV_DV_DIR = $(CORE_UVM_DIR)/riscv-dv
RISCV_DV_REPO = git@gitlab-internal.bsc.es:hwdesign/verification/riscv-dv.git
RISCV_DV_BRANCH = master
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

clone_dv: clone_uvm clone_riscv_dv

clone_uvm:
	mkdir -p ${DV_DIR}
	mkdir -p ${CORE_UVM_DIR}
	git clone ${CORE_UVM_REPO} ${CORE_UVM_DIR} -b ${CORE_UVM_BRANCH}

clone_riscv_dv:
	mkdir -p ${DV_DIR}
	mkdir -p ${RISCV_DV_DIR}
	git clone ${RISCV_DV_REPO} ${RISCV_DV_DIR} -b ${RISCV_DV_BRANCH}
