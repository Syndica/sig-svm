~/local/llvm18-sbpf/bin/llvm-mc -triple=sbf-solana-solana test.asm -filetype=obj -o temp/hello.o
~/local/llvm18-sbpf/bin/ld.lld -z notext -shared --Bdynamic --script tests/elfs/elf.ld -e 0x120 -o temp/hello.so temp/hello.o