TB_ISA_TEST_DIR = $(PROJECT_DIR)/tb/tb_isa_tests

RISCV_TESTS_DIR = $(PROJECT_DIR)/riscv-tests

ISA_TESTS_GCC_OPTS = -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles

ifdef SARGANTANA_TEST_FPGA
ISA_TESTS_GCC_OPTS += -DFPGA
endif

# *** ISA Test Compilation ***

$(TB_ISA_TEST_DIR)/build/Makefile: 
		mkdir -p $(TB_ISA_TEST_DIR)/build/
		cd $(TB_ISA_TEST_DIR)/build/ && $(RISCV_TESTS_DIR)/configure

.PHONY: build-isa-tests
build-isa-tests: $(TB_ISA_TEST_DIR)/build/Makefile
		$(MAKE) -C $(TB_ISA_TEST_DIR)/build RISCV_GCC_OPTS="$(ISA_TESTS_GCC_OPTS)" isa

# *** ISA Test Simulation ***

run-isa-tests: build-isa-tests $(SIMULATOR)
		$(TB_ISA_TEST_DIR)/run-tests.py $(SIMULATOR) $(TB_ISA_TEST_DIR)/build/isa

# *** Cleaning ***

clean-isa-tests:
		rm -rf $(TB_ISA_TEST_DIR)/build

clean:: clean-isa-tests
