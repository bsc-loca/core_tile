VERILATOR = verilator
VERISIM_DIR = $(SIM_DIR)/verilator

TOP_MODULE = sim_top

SIMULATOR = $(PROJECT_DIR)/sim

FLAGS ?= 

VERI_FLAGS = \
	$(foreach flag, $(FLAGS), -D$(flag)) \
	-DVERILATOR_GCC \
	-F $(SIM_DIR)/simulator.f \
	--top-module $(TOP_MODULE) \
	--unroll-count 256 \
	-Wno-lint -Wno-style -Wno-STMTDLY -Wno-fatal \
	-CFLAGS "-std=c++14 -I$(SPIKE_DIR)/riscv-isa-sim/ -fcoroutines" \
	-LDFLAGS "-pthread -L$(SPIKE_DIR)/build/ -Wl,-rpath=$(SPIKE_DIR)/build/ -ldisasm -ldl" \
	--exe --main --timing \
	--trace-fst \
	--trace-max-array 512 \
	--trace-max-width 256 \
	--trace-structs \
	--trace-params \
	--trace-underscore \
	--assert \
	--unroll-stmts 100000 \
	--Mdir $(VERISIM_DIR)/build

VERI_OPTI_FLAGS = -O2 -CFLAGS "-O2"

SIM_CPP_SRCS = $(wildcard $(SIM_DIR)/models/cxx/*.cpp)
SIM_VERILOG_SRCS = $(shell cat $(FILELIST)) $(wildcard $(SIM_DIR)/models/hdl/*.sv)
 
$(SIMULATOR): $(SIM_CPP_SRCS) bootrom.hex libdisasm $(SIM_DIR)/sim_top.sv
		$(VERILATOR) --cc $(VERI_FLAGS) $(VERI_OPTI_FLAGS) -o $(SIMULATOR)
		$(MAKE) -C $(VERISIM_DIR)/build -f V$(TOP_MODULE).mk $(SIMULATOR)

clean-simulator:
		rm -rf $(VERISIM_DIR)/build $(SIMULATOR)

clean:: clean-simulator