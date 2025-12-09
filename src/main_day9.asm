extern main

%include "exit.inc"
%include "io.inc"
%include "math.inc"
%include "number_str.inc"
%include "raw_io.inc"


section .bss


input: resb 10000
input_capacity: equ $ - input

points_capacity: equ 1000
points: resq points_capacity
points_count: resd 1


section .text


main:
    %push
    %stacksize flat

    %assign %$localsize 0
    %local max_area_low:dword
    %local max_area_high:dword
    %local idx1:dword
    %local idx2:dword

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

    ; Read the points from the input; esi = read position, edi = points write position
    mov dword [points_count], 0
    mov esi, input
    mov edi, points
.input_row_loop:
    cmp byte [esi], 0
    je .input_row_loop_done
    cmp dword [points_count], points_capacity
    jae .failure
    inc dword [points_count]
    push esi
    call parse_uint
    mov dword [edi], eax
    mov esi, edx
    cmp byte [esi], ','
    jne .parse_error
    inc esi
    push esi
    call parse_uint
    mov dword [edi+4], eax
    mov esi, edx
    cmp byte [esi], `\n`
    jne .parse_error
    inc esi
    add edi, 8
    jmp .input_row_loop
.input_row_loop_done:

    ; Check that there are at least 2 points
    cmp dword [points_count], 2
    jl .failure

    ; Loop through pairs of points to find the largest area
    mov dword [max_area_low], 0
    mov dword [max_area_high], 0
    mov dword [idx1], 0
.first_point_loop:
    mov eax, [points_count]
    cmp [idx1], eax
    ja .failure
    je .first_point_loop_done
    mov eax, [idx1]
    mov dword [idx2], eax
.second_point_loop:
    inc dword [idx2]
    mov eax, [points_count]
    cmp [idx2], eax
    jae .second_point_loop_done

    ; Compute the area edx:eax between points of indices [idx1] and [idx2]
    mov esi, [idx1]
    mov eax, [points+8*esi]
    mov edx, [points+8*esi+4]
    mov esi, [idx2]
    sub eax, [points+8*esi]
    sub edx, [points+8*esi+4]
    cmp eax, 0
    jge .x_abs_done
    neg eax
.x_abs_done:
    cmp edx, 0
    jge .y_abs_done
    neg edx
.y_abs_done:
    inc eax
    inc edx
    mul edx

    ; If the area edx:eax is larger than the current max area, update it
    cmp edx, [max_area_high]
    jb .max_area_update_done
    ja .do_max_area_update
    cmp eax, [max_area_low]
    jbe .max_area_update_done
.do_max_area_update:
    mov [max_area_low], eax
    mov [max_area_high], edx
.max_area_update_done:

    ; Continue looping through pairs of points
    jmp .second_point_loop
.second_point_loop_done:
    inc dword [idx1]
    jmp .first_point_loop
.first_point_loop_done:

    ; Print resulting largest area
    push dword [max_area_high]
    push dword [max_area_low]
    call write_ulong_line_to_stdout

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
