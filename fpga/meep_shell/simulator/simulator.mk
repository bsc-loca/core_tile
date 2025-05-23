VERILATOR = verilator
MEEP_SIM_DIR = $(PROJECT_DIR)/fpga/meep_shell/simulator

MEEP_SIMULATOR = $(PROJECT_DIR)/sim-meep

FLAGS ?=

MEEP_VERI_FLAGS = \
	$(foreach flag, $(FLAGS), -D$(flag)) \
	-DVERILATOR_GCC \
	+define+SIM_COMMIT_LOG \
	+define+SIM_COMMIT_LOG_DPI \
	+define+SIM_KONATA_DUMP \
	-F $(MEEP_SIM_DIR)/filelist.f \
	--top-module sim_meep_top \
	--unroll-count 256 \
	-Wno-lint -Wno-style -Wno-STMTDLY -Wno-fatal \
	-CFLAGS "-std=c++14 -I$(SPIKE_DIR)/riscv-isa-sim/" \
	-LDFLAGS "-pthread -L$(SPIKE_DIR)/build/ -Wl,-rpath=$(SPIKE_DIR)/build/ -ldisasm -ldl" \
	--exe \
	--timing \
	--main \
	--trace-fst \
	--trace-max-array 512 \
	--trace-max-width 256 \
	--trace-structs \
	--trace-params \
	--trace-underscore \
	--assert \
	--Mdir $(MEEP_SIM_DIR)/build

MEEP_VERI_OPTI_FLAGS = -O2 -CFLAGS "-O2"

MEEP_SIM_CPP_SRCS = $(SIM_CPP_SRCS) $(wildcard $(MEEP_SIM_DIR)/models/cxx/*.cpp)
MEEP_SIM_VERILOG_SRCS = $(SIM_VERILOG_SRCS) $(shell cat $(PROJECT_DIR)/fpga/common/filelist.f) $(wildcard $(PROJECT_DIR)/fpga/meep_shell/src/*) $(wildcard $(MEEP_SIM_DIR)/models/hdl/*.sv)

.patched:
		echo "Applying patches to axi and common_cells submodules"
		cd $(MEEP_SIM_DIR)/../../common/rtl/axi && git apply $(MEEP_SIM_DIR)/../../common/patches/axi.patch && cd -
		cd $(MEEP_SIM_DIR)/../../../rtl/common_cells && git apply $(MEEP_SIM_DIR)/../../common/patches/common_cells.patch && cd -
		touch .patched

$(MEEP_SIMULATOR): $(MEEP_SIM_CPP_SRCS) bootrom.hex libdisasm $(MEEP_SIM_DIR)/sim_meep_top.sv .patched
		HPDCACHE_DIR=$(PROJECT_DIR)/rtl/dcache $(VERILATOR) --cc $(MEEP_VERI_FLAGS) $(VERI_OPTI_FLAGS) $(MEEP_SIM_DIR)/sim_meep_top.sv -o $(MEEP_SIMULATOR)
		$(MAKE) -C $(MEEP_SIM_DIR)/build -f Vsim_meep_top.mk $(MEEP_SIMULATOR)

clean-meep-simulator:
		rm -rf $(MEEP_SIM_DIR)/build $(MEEP_SIMULATOR)

clean:: clean-meep-simulator