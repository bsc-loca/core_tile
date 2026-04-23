#!/bin/bash

SIMULATOR=$1
ISA_DIR=$2
TEST_TIMEOUT=100000

TESTS_TO_SKIP=(
    # Core doesn't support misaligned load/stores
    rv64ui-p-ma_data
    rv64ui-v-ma_data
)

print_padded() {
    pad=$(printf '%0.1s' "."{1..60})
    padlength=30
    printf '%s' "$1"
    printf '%*.*s' 0 $((padlength - ${#1} )) "$pad"
}

failed_tests=()
passed_tests=0

export HPDCACHE_DIR=./rtl/dcache

rm -rf lib_module

vlib lib_module
vmap work $PWD/lib_module

vlog -svinputport=compat \
     -ccflags "-I./simulator/reference/riscv-isa-sim/" \
     -F ./simulator/simulator.f +define+QUESTASIM

for test in $ISA_DIR/{rv64u{i,m,f,d,a,zba,zbb,zbs}-{p,v}-*,rv64mi-p-*}; do
    test_name=$(basename $test)

    if [[ "$test_name" != *dump ]]; then
        print_padded "Testing $test_name" 

        if [[ ! ${TESTS_TO_SKIP[*]} =~ "$test_name" ]]; then
            rm -f lib_module/failed_test.tmp
            vsim work.sim_top -ldflags "-L./simulator/reference/build/ -ldisasm -Wl,-rpath=./simulator/reference/build/" -batch &> /dev/null +max-cycles=$TEST_TIMEOUT +load=$test -do "run -all"
            if ! [[ -e lib_module/failed_test.tmp ]]; then
                printf "\e[32mOK\e[0m\n"
                ((passed_tests++))
            else
                printf "\e[31mFAILED\e[0m (Test case %d)\n"
                failed_tests[${#failed_tests[@]}]=$test_name
            fi
        else
            printf "\e[33mSKIP\e[0m\n"
        fi
    fi
done

echo ""
echo "*** SUMMARY ***"

echo "Tests passed:  $passed_tests"
echo "Tests skipped: ${#TESTS_TO_SKIP[@]}"
echo "Tests failed:  ${#failed_tests[@]}"

if [[ "${#failed_tests[@]}" -gt 0 ]]; then
    echo ""
    echo "*** LIST OF FAILED TESTS ***"

    for test in "${failed_tests[@]}"; do
        printf "%s, " $test
    done

    printf "\n"
fi

exit ${#failed_tests[@]}