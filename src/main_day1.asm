global main

%include "exit.inc"
%include "number.inc"
%include "raw_io.inc"


section .bss


input: resb 1000000
input_capacity: equ $ - input

output: resb 100
output_capacity: equ $ - input


section .text


main:
    %push
    %stacksize flat

    %assign %$localsize 0
    %local dial_pos:dword
    %local zero_count:dword

    push ebp
    mov ebp, esp
    sub esp, %$localsize

    push ebx
    push esi

    ; Read input
    push input_capacity - 1
    push input
    call read_all_stdin

    ; Add 0-byte to end of input
    mov byte [input+eax], 0

    ; Read input (read pos ebx), tracking dial position.
    mov ebx, input
    mov dword [dial_pos], 50
    mov dword [zero_count], 0
.loop:
    ; Break loop when 0-byte is reached
    cmp byte [ebx], 0
    je .done

    ; Read direction L/R -> -1/1 to esi
    cmp byte [ebx], 'L'
    jne .not_l
    mov esi, -1
    jmp .dir_done
.not_l:
    cmp byte [ebx], 'R'
    jne .not_lr
    mov esi, 1
    jmp .dir_done
.not_lr:
    push 1
    call exit
.dir_done:
    inc ebx

    ; Read amount to eax (new position returned to edx)
    push ebx
    call parse_uint

    cmp edx, ebx
    jne .amount_read_ok
    push 2
    call exit
.amount_read_ok:
    mov ebx, edx

    ; Update dial position
    mul esi
    add [dial_pos], eax

    ; Compute dial_pos % 100 to edx
    mov eax, [dial_pos]
    cdq
    mov ecx, 100
    idiv ecx

    ; If the remainder is 0, increase counter
    cmp edx, 0
    jne .remainder_nonzero
    inc dword [zero_count]
.remainder_nonzero:

    ; Consume newline
    cmp byte [ebx], `\n`
    je .newline_ok
    push 3
    call exit
.newline_ok:
    inc ebx

    jmp .loop

.done:
    ; Generate output string
    push output_capacity - 1
    push output
    push dword [zero_count]
    call uint_to_str
    mov byte [output+eax], `\n`
    inc eax

    ; Write output to stdout
    push eax
    push output
    call write_all_stdout

    ; Exit status
    mov eax, 0

    pop esi
    pop ebx

    add esp, %$localsize
    pop ebp
    ret

    %pop
