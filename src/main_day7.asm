extern main

%include "exit.inc"
%include "io.inc"
%include "math.inc"
%include "number_str.inc"
%include "raw_io.inc"


section .bss


input: resb 100000
input_capacity: equ $ - input

counts_capacity: equ 200
counts1: resq counts_capacity
counts2: resq counts_capacity


section .text


main:
    %push
    %stacksize flat

    %assign %$localsize 0
    %local width:dword
    %local height:dword
    %local split_count:dword
    %local path_count_low:dword
    %local path_count_high:dword
    %local prev_counts:dword
    %local counts:dword

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

    ; Check that we have enough capacity for storing the path counts
    cmp dword [width], counts_capacity
    jg .failure

    ; Start looping through the input, keeping track of the numbers of paths for each x;
    ; esi = input read position
    mov esi, input

    ; First, process the first row, initializing the path count to 1 for each position with 'S'
    xor ebx, ebx
.first_row_loop:
    cmp ebx, [width]
    ja .failure
    je .first_row_loop_done
    cmp byte [esi], 'S'
    jne .not_s
    mov dword [counts1+8*ebx], 1
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

    ; We will keep swapping counts1 and counts2 as the backing storage for the path counts as we
    ; proceed
    mov dword [counts], counts1
    mov dword [prev_counts], counts2

    ; Then process the other rows, performing splits, updating counts; edi = y
    mov edi, 1
.rows_loop:
    cmp edi, [height]
    ja .failure
    je .rows_loop_done

    ; Swap the counts and clear the output counts
    mov eax, [counts]
    mov edx, [prev_counts]
    mov [prev_counts], eax
    mov [counts], edx
    xor eax, eax
    push edi
    mov edi, [counts]
    mov ecx, [width]
    add ecx, ecx
    rep stosd
    pop edi

    ; Loop through the elements; ebx = x
    xor ebx, ebx
.elem_loop:
    cmp ebx, [width]
    ja .failure
    je .elem_loop_done
    cmp byte [esi], '.'
    jne .not_dot
    mov ecx, [prev_counts]
    mov eax, [ecx+8*ebx]
    mov edx, [ecx+8*ebx+4]
    mov ecx, [counts]
    add [ecx+8*ebx], eax
    adc [ecx+8*ebx+4], edx
    jmp .elem_loop_continue
.not_dot:
    cmp byte [esi], '^'
    jne .not_dot_or_caret
    cmp ebx, 0
    je .failure
    mov eax, [width]
    dec eax
    cmp ebx, eax
    je .failure
    mov ecx, [prev_counts]
    mov eax, [ecx+8*ebx]
    mov edx, [ecx+8*ebx+4]
    mov ecx, [counts]
    add [ecx+8*ebx-8], eax
    adc [ecx+8*ebx-4], edx
    add [ecx+8*ebx+8], eax
    adc [ecx+8*ebx+12], edx
    cmp eax, 0
    jne .nonzero
    cmp edx, 0
    je .elem_loop_continue
.nonzero:
    inc dword [split_count]
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

    ; Compute the sum of the counts
    xor eax, eax
    xor edx, edx
    xor ebx, ebx
    mov ecx, [counts]
.sum_loop:
    cmp ebx, [width]
    ja .failure
    je .sum_loop_done
    add eax, [ecx+8*ebx]
    adc edx, [ecx+8*ebx+4]
    inc ebx
    jmp .sum_loop
.sum_loop_done:
    mov [path_count_low], eax
    mov [path_count_high], edx

    ; Write output to stdout
    push dword [split_count]
    call write_uint_line_to_stdout
    push dword [path_count_high]
    push dword [path_count_low]
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
