RISCV_TESTS_DIR = $(PROJECT_DIR)/riscv-tests

BENCHMARK_GCC_OPTS = -march=rv64g -DPREALLOCATE=1 -mcmodel=medany -static -std=gnu99 -O2 -ffast-math -fno-common -fno-builtin-printf -fno-tree-loop-distribute-patterns -Wno-implicit-int -Wno-implicit-function-declaration -Wno-incompatible-pointer-types

ifdef BENCHMARKS_CI
	BENCHMARK_GCC_OPTS += -DSMALL_TESTS
endif

ifdef SARGANTANA_TEST_FPGA
BENCHMARK_GCC_OPTS += -DFPGA
endif

# *** riscv-tests benchmark compilation ***

$(PROJECT_DIR)/benchmarks/Makefile: 
		mkdir -p $(PROJECT_DIR)/benchmarks/
		cd $(PROJECT_DIR)/benchmarks/ && $(RISCV_TESTS_DIR)/configure

.PHONY: build-benchmarks
build-benchmarks: $(PROJECT_DIR)/benchmarks/Makefile
		$(MAKE) -C $(PROJECT_DIR)/benchmarks RISCV_GCC_OPTS="$(BENCHMARK_GCC_OPTS)" benchmarks

# *** riscv-tests benchmark simulation ***

run-benchmarks: build-benchmarks $(SIMULATOR)
		$(PROJECT_DIR)/run-benchmarks.sh
		
# *** Cleaning ***

clean-benchmarks:
		rm -rf $(PROJECT_DIR)/benchmarks

clean:: clean-benchmarks