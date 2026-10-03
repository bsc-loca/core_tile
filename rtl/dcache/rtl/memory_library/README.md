![image](images/memory_lib.png)

### Features
Defining `PRINT_MEMORY_LIST`will print out in the simulation the memory list. Checked with Questasim.

### sp_ram and dp_ram instantiation parameters
##### ADDR_WIDTH 
Address width of the instantiated memory. If not defined during instantiation, then its value will be one.

##### DATA_WIDTH
Address width of the instantiated memory. If not defined during instantiation, then its value will be one.

##### INSTANTIATE_ASIC_MEMORY
If not defined during instantiation, then its value will be one, which means ASIC physical memories will be instantiated otherwise zero means simulation/FPGA model will be instantiated. For ASIC, depends on the size selected (address and data widths), it will instantiate multiple physical memories.

##### INIT_MEMORY_ON_RESET
If not defined during instantiation, then its value will be zero which means memory will not be initialized. If its value is set to 1, then it means the instantiated memory will be initialized with reset. The reset memory is initialized to zero by writing in each clock cycle to one address. It starts the proccess when the reset is deasserted and the procedure will last a number of clk cycles that is determined by memory's depth: 2^ADDR_WIDTH. During mentioned time, the memory won't accept any transaction.

##### SRAM_CHUNK_ID 
JTAG parameter specific to OpenPiton package to select the access to memory in L2 or L15. This parameter is required if multiple-memories are instantiated within L2 or/and L15. See [JTAG debugging feature section](###JTAG-debugging-feature).

### JTAG debugging feature
JTAG debugging feature allows to debug memories i.e, to perform read and write on the memory. It can perform read and write on every address of every CHUNK of SRAM. It has three signals mentioned below:
* srams_rtap_data (output of memory)
* rtap_srams_bist_command (input of memory)
* rtap_srams_bist_data (input of memory)

If someone do not want to use this feature, then all inputs should be tied to zero while output can be left floating. More information is given in this [document](https://docs.google.com/document/d/1Wi6KAI7N3HcUqIAwOswY91akce7Dcl7LyN65eAGiSYY/edit?tab=t.0) (access required).


