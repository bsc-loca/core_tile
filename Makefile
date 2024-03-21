PROJECT_DIR = $(abspath .)

FILELIST = ${PROJECT_DIR}/filelist.f

DV_DIR = $(PROJECT_DIR)/verif
CORE_UVM_DIR = $(DV_DIR)/core_uvm
CORE_UVM_REPO = git@gitlab-internal.bsc.es:hwdesign/verification/core-uvm.git
CORE_UVM_BRANCH ?= sargantana_mode_changes

DC_REPO = git@gitlab-internal.bsc.es:hwdesign/spd/dc-scripts.git
DC_BRANCH = sargantana_lint
DC_DIR =$(PROJECT_DIR)/dc-scripts


RISCV_DV_DIR = $(CORE_UVM_DIR)/riscv-dv
RISCV_DV_REPO = git@gitlab-internal.bsc.es:hwdesign/verification/riscv-dv.git
RISCV_DV_BRANCH ?= master
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
	git clone ${SHALLOW_CLONE} ${CORE_UVM_REPO} ${CORE_UVM_DIR} -b ${CORE_UVM_BRANCH}

$(DC_DIR):
	git clone ${DC_REPO} -b ${DC_BRANCH} $@

dc_elab: $(DC_DIR)
	make -C $(DC_DIR) elab BASE_DIR=$(PROJECT_DIR) RTL_BASE_PATH=$(PROJECT_DIR) FLIST_PATH=$(PROJECT_DIR)/dc_filelist.f TOP_MODULE=top_tile CLOCK_PORT=clk_i

clone_riscv_dv:
	mkdir -p ${DV_DIR}
	mkdir -p ${RISCV_DV_DIR}
	git clone ${SHALLOW_CLONE} ${RISCV_DV_REPO} ${RISCV_DV_DIR} -b ${RISCV_DV_BRANCH}
