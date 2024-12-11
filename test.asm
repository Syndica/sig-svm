entrypoint:
    mov32 r0, 0
    mov r1, -2
    jsge r1, 0, +1
    mov32 r0, 1
    exit