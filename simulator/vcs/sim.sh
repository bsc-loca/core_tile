set -e

BASE_DIR=$(pwd)
CCFLAGS="-I${BASE_DIR}/simulator/reference/riscv-isa-sim/ "
CCFLAGS+="-I${BASE_DIR}/simulator/models/cxx "
LDFLAGS="-L${BASE_DIR}/simulator/reference/build/ -Wl,-rpath=${BASE_DIR}/simulator/reference/build/"

rm -rf build_vcs
mkdir build_vcs
cd build_vcs

PARSED_FLIST=${BASE_DIR}/simulator/vcs/out.f FLIST_PATH=${BASE_DIR}/simulator/simulator.f ${BASE_DIR}/simulator/vcs/gen_full_filelist.sh 

vcs -CFLAGS "$CCFLAGS" -f ${BASE_DIR}/simulator/vcs/out.f -Xstrict=1 -notice +nospecify -timescale=1ps/1ps \
     -sverilog +systemverilogext+.sv -debug_access+r -kdb -top sim_top +lint=all,noVCDE,noVNGS,noPCTIO-L,noPCTIO \
     +warn=all -l compile.log  -LDFLAGS "$LDFLAGS" -ldisasm

if [ -z "${CI_VCS}" ]; then cp ../bootrom.hex .; fi