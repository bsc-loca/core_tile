set -e

BASE_DIR="."
CCFLAGS="-I${BASE_DIR}/simulator/reference/riscv-isa-sim/"
LDFLAGS="-L${BASE_DIR}/simulator/reference/build/ -ldisasm -Wl,-rpath=${BASE_DIR}/simulator/reference/build/"
VLOG_FLAGS="-svinputport=compat +acc=rn"
CYCLES=-all

export HPDCACHE_DIR=${BASE_DIR}/rtl/dcache

rm -rf lib_module

vlib lib_module
vmap work $PWD/lib_module

vlog $VLOG_FLAGS \
     -ccflags "$CCFLAGS" \
     -F ${BASE_DIR}/simulator/simulator.f

vsim work.sim_top -ldflags "$LDFLAGS" $@ -do "run $CYCLES"