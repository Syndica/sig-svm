entrypoint:
    mov r1, r2
    and r1, 4095
    mov r3, r10
    sub r3, r1
    add r3, -1
    ldxb r4, [r3]
    add r2, 1
    jlt r2, 0x10000, -8
    exit