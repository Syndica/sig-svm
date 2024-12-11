entrypoint:
    add r11, -0x7FFFFFFF
    add r11, -0x7FFFFFFF
    add r11, -0x7FFFFFFF
    add r11, -0x7FFFFFFF
    add r11, -0x40005
    call function_foo
    exit
function_foo:
    stb [r10], 0
    exit