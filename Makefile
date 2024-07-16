PROJECT_DIR = $(abspath .)

FILELIST = ${PROJECT_DIR}/filelist.f

DV_DIR = $(PROJECT_DIR)/verif
CORE_UVM_DIR = $(DV_DIR)/core_uvm
CORE_UVM_REPO = git@gitlab-internal.bsc.es:hwdesign/verification/core-uvm.git
CORE_UVM_BRANCH ?= sargantana_mode_changes

DC_REPO = git@gitlab-internal.bsc.es:hwdesign/spd/dc-scripts.git
DC_BRANCH = sargantana_syn
DC_DIR =$(PROJECT_DIR)/dc-scripts

SRAM_WRAPPER_REPO = git@gitlab-internal.bsc.es:hwdesign/chips/cincoranch.git
SRAM_WRAPPER_BRANCH = main
SRAM_WRAPPER_DIR =$(PROJECT_DIR)/cincoranch
SRAM_WRAPPER =$(SRAM_WRAPPER_DIR)/piton/design/common/rtl/asic_sram_1p.v

RISCV_DV_DIR = $(CORE_UVM_DIR)/riscv-dv
RISCV_DV_REPO = git@gitlab-internal.bsc.es:hwdesign/verification/riscv-dv.git
RISCV_DV_BRANCH ?= master

CI_SCRIPTS_REPO = git@gitlab-internal.bsc.es:hwdesign/ci/ci_scripts.git
CI_SCRIPTS_DIR = $(CORE_UVM_DIR)/ci_scripts
CI_SCRIPTS_BRANCH ?= main

export HPDCACHE_DIR = $(PROJECT_DIR)/rtl/dcache

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

lint-vc:
		vc_static_shell -lic_wait 30 -f scripts/lint_intel_grade.tcl

clone_dv: clone_uvm clone_riscv_dv

clone_uvm:
	mkdir -p ${DV_DIR}
	mkdir -p ${CORE_UVM_DIR}
	git clone ${SHALLOW_CLONE} ${CORE_UVM_REPO} ${CORE_UVM_DIR} -b ${CORE_UVM_BRANCH}
	make -C ${CORE_UVM_DIR} clone_spike 
	make -C ${CORE_UVM_DIR} clone_tests

$(DC_DIR):
	git clone ${DC_REPO} -b ${DC_BRANCH} $@

$(SRAM_WRAPPER_DIR):
	git clone ${SRAM_WRAPPER_REPO} -b ${SRAM_WRAPPER_BRANCH} $@

$(SRAM_WRAPPER): $(SRAM_WRAPPER_DIR)
	printf "\n$(@)\n" >> $(PROJECT_DIR)/dc_filelist.f

DC_VARS = \
	BASE_DIR=$(PROJECT_DIR) \
	RTL_BASE_PATH=$(PROJECT_DIR) \
	FLIST_PATH=$(PROJECT_DIR)/dc_filelist.f \
	TOP_MODULE=top_tile \
	CLOCK_PORT=clk_i \
	ASYNC_RESET_PORT=rstn_i \
	CONSTANT_IN_CONSTRAINTS=true \
	CONSTANT_IN_LIST="reset_addr_i core_id_i" \
	SYNTH_DEFINES+=SRAM_IP \
	SYNTH_DEFINES+=CONF_HPDCACHE_MSHR_SETS=32 \

dc_elab: $(DC_DIR) $(SRAM_WRAPPER)
	make -C $< elab $(DC_VARS)

dc_syn: $(DC_DIR) $(SRAM_WRAPPER)
	make -C $< syn $(DC_VARS)

dc_clean: $(DC_DIR)
	make -C $< clean-dc $(DC_VARS)
	rm -rf $<

sram_wrapper_clean: $(SRAM_WRAPPER_DIR)
	rm -rf $<
	git checkout $(PROJECT_DIR)/dc_filelist.f

clone_riscv_dv:
	mkdir -p ${DV_DIR}
	mkdir -p ${RISCV_DV_DIR}
	git clone ${SHALLOW_CLONE} ${RISCV_DV_REPO} ${RISCV_DV_DIR} -b ${RISCV_DV_BRANCH}
	${RISCV_DV_DIR}/clone_targets.sh ${RISCV_DV_DIR}

clone_ci_scripts:
	mkdir -p ${DV_DIR}
	mkdir -p ${CI_SCRIPTS_DIR}
	git clone ${SHALLOW_CLONE} ${CI_SCRIPTS_REPO} ${CI_SCRIPTS_DIR} -b ${CI_SCRIPTS_BRANCH}
