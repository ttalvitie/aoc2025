extern main

%include "exit.inc"
%include "io.inc"
%include "math.inc"
%include "number_str.inc"
%include "raw_io.inc"


section .bss


input: resb 100000
input_capacity: equ $ - input

output: resb 100
output_capacity: equ $ - output

tmp: resb input_capacity


section .text


; Remove paper rolls, writing updated data to different buffer
; (source data pointer, destination data pointer, width, height) -> removed count
run_removal_round:
    %push
    %stacksize flat

    %arg src:dword
    %arg dest:dword
    %arg width:dword
    %arg height:dword

    %assign %$localsize 0
    %local x:dword
    %local y:dword
    %local neighbor_count:dword
    %local removed_count:dword

    push ebp
    mov ebp, esp
    sub esp, %$localsize

    push esi
    push edi
    push ebx

    ; Initialize the return value
    mov dword [removed_count], 0

    ; Iterate through all cells; esi = read position, edi = write position
    mov dword [y], 0
    mov esi, [src]
    mov edi, [dest]
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

    ; Count the neighbors (calling routine .consider_neighbor for each ecx = (width + 1) * dy, edx = dx)
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
    lea ebx, [esi+ecx]
    cmp byte [ebx+edx], '.'
    je .consider_neighbor_break
    inc dword [neighbor_count]
.consider_neighbor_break:
    ret
.consider_neighbor_end:

    mov ecx, [width]
    inc ecx
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
    inc dword [removed_count]
    mov byte [edi], '.'
    jmp .removed

.elem_loop_continue:
    ; Copy input byte to output
    mov al, [esi]
    mov [edi], al
.removed:
    inc esi
    inc edi
    inc dword [x]
    jmp .elem_loop
.elem_loop_done:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    inc dword [y]
    jmp .row_loop
.row_loop_done:

    ; Sanity check state
    cmp byte [esi], 0
    jne .failure
    
    ; Write terminating 0-byte to destination as well
    mov byte [edi], 0

    ; Set return value
    mov eax, [removed_count]

    pop ebx
    pop edi
    pop esi

    add esp, %$localsize
    pop ebp
    ret 16

.failure:
    push 2
    call exit

    %pop


main:
    %push
    %stacksize flat

    %assign %$localsize 0
    %local width:dword
    %local height:dword
    %local accessible_count:dword
    %local removable_count:dword

    push ebp
    mov ebp, esp
    sub esp, %$localsize

    push esi

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

    ; Run first removal round, obtaining the first output value as the number of removed rolls
    push dword [height]
    push dword [width]
    push tmp
    push input
    call run_removal_round
    mov [accessible_count], eax
    mov [removable_count], eax

    ; Run further removal rounds as long as rolls are removed
.removal_loop:
    push dword [height]
    push dword [width]
    push input
    push tmp
    call run_removal_round
    cmp eax, 0
    je .removal_loop_done
    add [removable_count], eax
    push dword [height]
    push dword [width]
    push tmp
    push input
    call run_removal_round
    cmp eax, 0
    je .removal_loop_done
    add [removable_count], eax
    jmp .removal_loop
.removal_loop_done:

    ; Write output to stdout
    push dword [accessible_count]
    call write_uint_line_to_stdout
    push dword [removable_count]
    call write_uint_line_to_stdout

    ; Exit status
    mov eax, 0

    pop esi

    add esp, %$localsize
    pop ebp
    ret

.parse_error:
    push 1
    call exit

    %pop
