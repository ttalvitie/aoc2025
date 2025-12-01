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
    %local stop_at_zero_count:dword
    %local pass_zero_count:dword
    %local prev_dial_round:dword
    %local prev_dial_remainder:dword

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
    mov dword [stop_at_zero_count], 0
    mov dword [pass_zero_count], 0
    mov dword [prev_dial_round], 0
    mov dword [prev_dial_remainder], 50
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

    ; Compute dial_pos / 100 to eax and dial_pos % 100 to edx
    mov eax, [dial_pos]
    cdq
    mov ecx, 100
    idiv ecx

    ; Fix eax to floor(dial_pos / 100) instead of towards-zero rounding
    cmp dword [dial_pos], 0
    jge .no_fix_needed
    cmp edx, 0
    je .no_fix_needed
    dec eax
.no_fix_needed:

    ; Increase the counter for zero passes by the change in floor(dial_pos / 100)
    push eax
    sub eax, [prev_dial_round]
    cmp eax, 0
    jge .rounds_not_negative
    neg eax
.rounds_not_negative:
    add [pass_zero_count], eax
    pop eax

    ; If the remainder is 0, increase counter for stop at zero
    cmp edx, 0
    jne .remainder_check_done
    inc dword [stop_at_zero_count]

    ; For right rotations, we also need to reduce the zero pass count to avoid double-counting the
    ; last movement
    cmp esi, 0
    jle .remainder_check_done
    dec dword [pass_zero_count]
.remainder_check_done:

    ; If we did a left-rotation from remainder-zero position, we also need to reduce the zero pass
    ; count, to avoid double-counting the last movement
    cmp dword [prev_dial_remainder], 0
    jne .left_from_zero_check_done
    cmp esi, 0
    jge .left_from_zero_check_done
    dec dword [pass_zero_count]
.left_from_zero_check_done:


    ; Save floor(dial_pos / 100) and the remainder for next round
    mov [prev_dial_round], eax
    mov [prev_dial_remainder], edx

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
    mov edi, output
    push output_capacity / 2 - 1
    push edi
    push dword [stop_at_zero_count]
    call uint_to_str
    add edi, eax
    mov byte [edi], `\n`
    inc edi
    push output_capacity / 2 - 1
    push edi
    mov eax, [pass_zero_count]
    add eax, [stop_at_zero_count]
    push eax
    call uint_to_str
    add edi, eax
    mov byte [edi], `\n`
    inc edi
    sub edi, output

    ; Write output to stdout
    push edi
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
