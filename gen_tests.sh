#!/bin/bash

CC="${HOME}/local/llvm18-sbpf/bin/clang"
LD="${HOME}/local/llvm18-sbpf/bin/ld.lld"

C_FLAGS="
    -target sbf-solana-solana \
    -mcpu=v1 \
    -fno-builtin \
    -fPIC -fno-unwind-tables \
    -fomit-frame-pointer -fno-exceptions\
    -fno-asynchronous-unwind-tables \
    -std=c23 \
    -O2 \
    -Werror \
    -I ../agave/sdk/sbf/c/inc"

LD_FLAGS="-z notext -shared --Bdynamic --script tests/elfs/elf.ld -e entrypoint"

CC="${CC} ${C_FLAGS}"
LD="${LD} ${LD_FLAGS}"

$CC tests/standalone/sanity.c -c -o tests/standalone/sanity.o
$LD tests/standalone/sanity.o    -o tests/standalone/sanity.so

$CC bench/alu_bench.c -c -o bench/alu_bench.o
$LD bench/alu_bench.o    -o bench/alu_bench.so


rm tests/standalone/*.o
rm bench/*.o