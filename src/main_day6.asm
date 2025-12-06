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
    %local grand_total_low:dword
    %local grand_total_high:dword
    %local last_row_pos:dword
    %local column_width:dword
    %local is_last_column:dword
    %local value_low:dword
    %local value_high:dword
    %local tmp1_low:dword
    %local tmp1_high:dword
    %local tmp2_low:dword
    %local tmp2_high:dword

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

    ; Perform the computations for each column
    mov dword [grand_total_low], 0
    mov dword [grand_total_high], 0
    mov [last_row_pos], esi
    mov eax, [width]
    sub [last_row_pos], eax
    dec dword [last_row_pos]
.column_loop:
    ; Check operation and initialize value to neutral element
    mov dword [value_low], 0
    mov dword [value_high], 0
    mov esi, [last_row_pos]
    cmp byte [esi], '+'
    je .operation_check_ok
    cmp byte [esi], '*'
    jne .parse_error
    inc dword [value_low]
.operation_check_ok:

    ; Find the width of the column
    xor eax, eax
.column_scan_loop:
    inc eax
    cmp byte [esi+eax], ' '
    je .column_scan_loop
    mov dword [is_last_column], 0
    cmp byte [esi+eax], `\n`
    jne .last_column_check_done
    inc dword [is_last_column]
    inc eax
.last_column_check_done:
    dec eax
    mov [column_width], eax

    ; Iterate the column and perform the computation; esi = column start, edi = elements left
    mov esi, [last_row_pos]
    mov edi, [height]
.elem_loop:
    sub esi, [width]
    dec esi
    dec edi
    cmp edi, 0
    jl .failure
    je .elem_loop_done

    ; Check that the field ends in space or newline
    mov eax, [column_width]
    mov al, [esi+eax]
    cmp al, ' '
    je .field_end_check_done
    cmp al, `\n`
    jne .parse_error
.field_end_check_done:

    ; Skip spaces in the end of the column
    xor ecx, ecx
.skip_leading_space_loop:
    cmp ecx, [column_width]
    jae .parse_error
    cmp byte [esi+ecx], ' '
    jne .skip_leading_space_loop_done
    inc ecx
    jmp .skip_leading_space_loop
.skip_leading_space_loop_done:

    ; Parse the element to edx:eax
    push esi
    add dword [esp], ecx
    call parse_ulong
    sub ecx, esi

    ; Perform the computation
    mov ebx, [last_row_pos]
    cmp byte [ebx], '+'
    jne .not_plus
    add [value_low], eax
    adc [value_high], edx
    jmp .computation_done
.not_plus:
    cmp byte [ebx], '*'
    jne .parse_error
    mov [tmp1_low], eax
    mov [tmp1_high], edx
    mov eax, [value_low]
    mov [tmp2_low], eax
    mov edx, [value_high]
    mov [tmp2_high], edx
    mov eax, [tmp1_low]
    mov edx, [tmp2_low]
    mul edx
    mov [value_low], eax
    mov [value_high], edx
    mov eax, [tmp1_low]
    mov edx, [tmp2_high]
    mul edx
    add [value_high], eax
    mov eax, [tmp1_high]
    mov edx, [tmp1_low]
    mul edx
    add [value_high], eax
.computation_done:

    ; Check that after the number, there are only spaces
.check_trailing_space_loop:
    cmp ecx, [column_width]
    ja .failure
    je .check_trailing_space_loop_done
    cmp byte [esi+ecx], ' '
    jne .parse_error
    inc ecx
.check_trailing_space_loop_done:

    jmp .elem_loop
.elem_loop_done:

    ; Accumulate the computation result to the grand total
    mov eax, [value_low]
    mov edx, [value_high]
    add [grand_total_low], eax
    adc [grand_total_high], edx

    ; If this is the last column, break the loop
    cmp dword [is_last_column], 0
    jne .column_loop_done

    ; Proceed to the next column
    mov eax, [column_width]
    inc eax
    add [last_row_pos], eax
    jmp .column_loop
.column_loop_done:

    ; Write output to stdout
    push dword [grand_total_high]
    push dword [grand_total_low]
    call write_ulong_line_to_stdout

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
