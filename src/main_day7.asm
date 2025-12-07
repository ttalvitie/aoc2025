extern main

%include "exit.inc"
%include "io.inc"
%include "math.inc"
%include "number_str.inc"
%include "raw_io.inc"


section .bss


input: resb 100000
input_capacity: equ $ - input


section .text


main:
    %push
    %stacksize flat

    %assign %$localsize 0
    %local width:dword
    %local height:dword
    %local split_count:dword

    push ebp
    mov ebp, esp
    sub esp, %$localsize

    push esi
    push edi
    push ebx

    ; Read input
    push input_capacity - 1
    push input
    call read_all_stdin

    ; Add 0-byte to end of input
    mov byte [input+eax], 0

    ; Iterate through the input, inferring the width and height; esi = read position
    mov dword [width], -1
    mov dword [height], 0
    mov esi, input
.input_row_loop:
    cmp byte [esi], 0
    je .input_row_loop_done
    inc dword [height]
    xor eax, eax
.input_elem_loop:
    cmp byte [esi+eax], `\n`
    je .input_elem_loop_done
    inc eax
    jmp .input_elem_loop
.input_elem_loop_done:
    cmp dword [width], -1
    jne .skip_width_set
    mov dword [width], eax
.skip_width_set:
    cmp [width], eax
    jne .parse_error
    add esi, eax
    inc esi
    jmp .input_row_loop
.input_row_loop_done:
    cmp dword [width], 0
    jle .parse_error
    cmp dword [height], 0
    jle .parse_error

    ; Initialize output variable
    mov dword [split_count], 0

    ; Start looping through the input, propagating beams using '|' signs; esi = position
    mov esi, input

    ; First, process the first row, replacing 'S' by '|'; ebx = x
    xor ebx, ebx
.first_row_loop:
    cmp ebx, [width]
    ja .failure
    je .first_row_loop_done
    cmp byte [esi], 'S'
    jne .not_s
    mov byte [esi], '|'
    jmp .first_row_loop_continue
.not_s:
    cmp byte [esi], '.'
    jne .parse_error
.first_row_loop_continue:
    inc ebx
    inc esi
    jmp .first_row_loop
.first_row_loop_done:
    cmp byte [esi], `\n`
    jne .failure
    inc esi

    ; Then process the other row, performing splits, propagating beams using '|' sign; edi = y
    mov edi, 1
.rows_loop:
    cmp edi, [height]
    ja .failure
    je .rows_loop_done
    xor ebx, ebx
.elem_loop:
    cmp ebx, [width]
    ja .failure
    je .elem_loop_done
    cmp byte [esi], '.'
    jne .not_dot
    mov eax, [width]
    neg eax
    cmp byte [esi+eax-1], '|'
    jne .elem_loop_continue
    mov byte [esi], '|'
    jmp .elem_loop_continue
.not_dot:
    cmp byte [esi], '^'
    jne .not_dot_or_caret
    mov eax, [width]
    neg eax
    cmp byte [esi+eax-1], '|'
    jne .elem_loop_continue
    inc dword [split_count]
    cmp ebx, 0
    je .failure
    mov eax, [width]
    dec eax
    cmp ebx, eax
    je .failure
    mov byte [esi-1], '|'
    mov byte [esi+1], '|'
    jmp .elem_loop_continue
.not_dot_or_caret:
    cmp byte [esi], '|'
    jne .failure
.elem_loop_continue:
    inc ebx
    inc esi
    jmp .elem_loop
.elem_loop_done:
    cmp byte [esi], `\n`
    jne .failure
    inc esi
    inc edi
    jmp .rows_loop
.rows_loop_done:

    ; Sanity check state
    cmp byte [esi], 0
    jne .failure

    ; Write output to stdout
    push dword [split_count]
    call write_uint_line_to_stdout

    ; Exit status
    mov eax, 0

    pop ebx
    pop edi
    pop esi

    add esp, %$localsize
    pop ebp
    ret

.parse_error:
    push 1
    call exit

.failure:
    push 2
    call exit

    %pop
