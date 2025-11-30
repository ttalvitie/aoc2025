global main

%include "raw_io.inc"


section .data


text_prefix: db `Hello, `
text_prefix_len: equ $ - text_prefix

text_suffix: db `!\n`
text_suffix_len: equ $ - text_suffix


section .bss


input: resb 1024
input_capacity: equ $ - input


section .text


main:
    %push
    %stacksize flat

    %assign %$localsize 0
    %local input_len:dword

    push ebp
    mov ebp, esp
    sub esp, %$localsize

    push input_capacity
    push input
    call read_all_stdin

.loop:
    cmp eax, 0
    je .done
    cmp byte [input+eax-1], `\n`
    jne .done
    dec eax
    jmp .loop

.done:
    mov [input_len], eax

    push text_prefix_len
    push text_prefix
    call write_all_stdout

    push dword [input_len]
    push input
    call write_all_stdout

    push text_suffix_len
    push text_suffix
    call write_all_stdout

    mov eax, 0

    add esp, %$localsize
    pop ebp
    ret

    %pop
