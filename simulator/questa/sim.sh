set -e

BASE_DIR="."
CCFLAGS="-I${BASE_DIR}/simulator/reference/riscv-isa-sim/"
LDFLAGS="-L${BASE_DIR}/simulator/reference/build/ -ldisasm -Wl,-rpath=${BASE_DIR}/simulator/reference/build/"
DEFINES="+define+SIMULATION +define+SIM_COMMIT_LOG +define+SIM_COMMIT_LOG_DPI +define+SIM_KONATA_DUMP"
VLOG_FLAGS="-svinputport=compat +acc=rn"
CYCLES=-all

export HPDCACHE_DIR=${BASE_DIR}/rtl/dcache

rm -rf lib_module

vlib lib_module
vmap work $PWD/lib_module

vlog $VLOG_FLAGS \
     $DEFINES \
     -ccflags "$CCFLAGS" \
     -F $BASE_DIR/filelist.f \
     -F ${BASE_DIR}/simulator/models/filelist.f \
     ${BASE_DIR}/simulator/questa/questa_top.sv

vsim work.questa_top -ldflags "$LDFLAGS" $@ -do "run $CYCLES"