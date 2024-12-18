#!/bin/bash

CC="${HOME}/local/llvm18-sbpf/bin/clang --target=sbf-solana-solana -fno-builtin -std=c17 -O2 -Werror"
LD="${HOME}/local/llvm18-sbpf/bin/ld.lld -z notext -shared --Bdynamic --script tests/elfs/elf.ld -e entrypoint"

$CC tests/standalone/sanity.c -c -o tests/standalone/sanity.o
$LD tests/standalone/sanity.o     -o tests/standalone/sanity.so

rm tests/standalone/*.o