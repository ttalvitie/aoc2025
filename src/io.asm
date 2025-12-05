%include "io.inc"

%include "number_str.inc"
%include "raw_io.inc"

section .bss


tmp: resb 32
tmp_capacity: equ $ - tmp


section .text


write_uint_line_to_stdout:
    %push
    %stacksize flat

    %arg value:dword

    push ebp
    mov ebp, esp

    ; Generate number string from the value
    push tmp_capacity - 1
    push tmp
    push dword [value]
    call uint_to_str

    ; Add newline
    mov byte [tmp+eax], `\n`
    inc eax

    ; Write generated string to stdout
    push eax
    push tmp
    call write_all_stdout

    pop ebp
    ret 4

    %pop


write_ulong_line_to_stdout:
    %push
    %stacksize flat

    %arg low:dword
    %arg high:dword

    push ebp
    mov ebp, esp

    ; Generate number string from the value
    push tmp_capacity - 1
    push tmp
    push dword [high]
    push dword [low]
    call ulong_to_str

    ; Add newline
    mov byte [tmp+eax], `\n`
    inc eax

    ; Write generated string to stdout
    push eax
    push tmp
    call write_all_stdout

    pop ebp
    ret 8

    %pop
