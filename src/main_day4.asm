extern main

%include "exit.inc"
%include "math.inc"
%include "number_str.inc"
%include "raw_io.inc"


section .bss


input: resb 100000
input_capacity: equ $ - input

output: resb 100
output_capacity: equ $ - output


section .text


main:
    %push
    %stacksize flat

    %assign %$localsize 0
    %local width:dword
    %local height:dword
    %local stride:dword
    %local accessible_count:dword
    %local x:dword
    %local y:dword
    %local neighbor_count:dword

    push ebp
    mov ebp, esp
    sub esp, %$localsize

    push esi
    push edi

    ; Read input
    push input_capacity - 1
    push input
    call read_all_stdin

    ; Add 0-byte to end of input
    mov byte [input+eax], 0

    ; Iterate through the input, inferring the width, height and stride; esi = read position
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
    cmp byte [esi+eax], '.'
    je .elem_ok
    cmp byte [esi+eax], '@'
    jne .parse_error
.elem_ok:
    inc eax
    jmp .input_elem_loop
.input_elem_loop_done:
    cmp dword [width], -1
    jne .skip_width_set
    mov dword [width], eax
    mov dword [stride], eax
    inc dword [stride]
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

    ; Initialize result variable
    mov dword [accessible_count], 0

    ; Iterate through all cells
    mov dword [y], 0
    mov esi, input
.row_loop:
    mov eax, [height]
    cmp [y], eax
    je .row_loop_done
    mov dword [x], 0
.elem_loop:
    mov eax, [width]
    cmp [x], eax
    je .elem_loop_done

    ; Only consider cells with paper roll inside them
    cmp byte [esi], '.'
    je .elem_loop_continue

    ; Count the neighbors (calling routine .consider_neighbor for each ecx = stride * dy, edx = dx)
    mov dword [neighbor_count], 0
    jmp .consider_neighbor_end
.consider_neighbor:
    cmp dword [x], 0
    jne .left_ok
    cmp edx, 0
    jl .consider_neighbor_break
.left_ok:
    cmp dword [y], 0
    jne .up_ok
    cmp ecx, 0
    jl .consider_neighbor_break
.up_ok:
    mov eax, [width]
    dec eax
    cmp dword [x], eax
    jne .right_ok
    cmp edx, 0
    jg .consider_neighbor_break
.right_ok:
    mov eax, [height]
    dec eax
    cmp dword [y], eax
    jne .down_ok
    cmp ecx, 0
    jg .consider_neighbor_break
.down_ok:
    lea edi, [esi+ecx]
    cmp byte [edi+edx], '.'
    je .consider_neighbor_break
    inc dword [neighbor_count]
.consider_neighbor_break:
    ret
.consider_neighbor_end:

    mov ecx, [stride]
    mov edx, -1
    call .consider_neighbor
    inc edx
    call .consider_neighbor
    inc edx
    call .consider_neighbor
    neg ecx
    call .consider_neighbor
    dec edx
    call .consider_neighbor
    dec edx
    call .consider_neighbor
    xor ecx, ecx
    call .consider_neighbor
    neg edx
    call .consider_neighbor

    ; If there are fewer than four neighbors, this roll is accessible
    cmp dword [neighbor_count], 4
    jge .elem_loop_continue
    inc dword [accessible_count]

.elem_loop_continue:
    inc esi
    inc dword [x]
    jmp .elem_loop
.elem_loop_done:
    inc esi
    inc dword [y]
    jmp .row_loop
.row_loop_done:

    ; Sanity check state
    cmp byte [esi], 0
    jne .failure

    ; Generate output string
    mov edi, output
    push output_capacity - 1
    push edi
    push dword [accessible_count]
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
