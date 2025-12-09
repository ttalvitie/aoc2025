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
    %local max_area1_low:dword
    %local max_area1_high:dword
    %local max_area2_low:dword
    %local max_area2_high:dword
    %local idx1:dword
    %local idx2:dword
    %local x1:dword
    %local x2:dword
    %local y1:dword
    %local y2:dword
    %local area_low:dword
    %local area_high:dword
    %local is_interior:dword
    %local poly1:dword
    %local poly2:dword

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
    mov dword [max_area1_low], 0
    mov dword [max_area1_high], 0
    mov dword [max_area2_low], 0
    mov dword [max_area2_high], 0
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

    ; Generate the ordered corner points for rectangle [x1, x2] x [y1, y2]
    mov esi, [idx1]
    mov eax, [points+8*esi]
    mov esi, [idx2]
    mov edx, [points+8*esi]
    cmp eax, edx
    jbe .x_order_done
    xchg eax, edx
.x_order_done:
    mov [x1], eax
    mov [x2], edx
    mov esi, [idx1]
    mov eax, [points+8*esi+4]
    mov esi, [idx2]
    mov edx, [points+8*esi+4]
    cmp eax, edx
    jbe .y_order_done
    xchg eax, edx
.y_order_done:
    mov [y1], eax
    mov [y2], edx

    ; Compute the area
    mov eax, [x2]
    sub eax, [x1]
    inc eax
    mov edx, [y2]
    sub edx, [y1]
    inc edx
    mul edx
    mov [area_low], eax
    mov [area_high], edx

    ; If the area is larger than the current max area for first star, update it
    mov eax, [area_low]
    mov edx, [area_high]
    cmp edx, [max_area1_high]
    jb .max_area1_update_done
    ja .do_max_area1_update
    cmp eax, [max_area1_low]
    jbe .max_area1_update_done
.do_max_area1_update:
    mov [max_area1_low], eax
    mov [max_area1_high], edx
.max_area1_update_done:

    ; Start checking whether the rectangle is also suitable for the second star.
    ; This is the case if both of the following hold:
    ;   - ([x1] + 0.5, [y1] + 0.5) is inside the polygon based on the even-odd fill rule
    ;   - None of the edges of the polygon cross the interior of the rectangle ]x1, x2[ x ]y1, y2[
    ; We check both of these using a single loop around the polygon
    mov dword [is_interior], 0
    mov eax, [points_count]
    dec eax
    mov [poly1], eax
    mov dword [poly2], 0
.poly_loop:
    mov eax, [points_count]
    cmp [poly2], eax
    ja .failure
    je .poly_loop_done

    ; Process horizontal and vertical edges separately
    mov eax, [poly1]
    mov eax, [points+8*eax]
    mov edx, [poly2]
    mov edx, [points+8*edx]
    cmp eax, edx
    je .vertical_edge

    ; Horizontal edge
    jbe .horizontal_edge_ordered
    xchg eax, edx
.horizontal_edge_ordered:
    mov esi, [poly1]
    mov esi, [points+8*esi+4]
    mov edi, [poly2]
    mov edi, [points+8*edi+4]
    cmp esi, edi
    jne .failure

    ; Edge is [eax, edx] x {esi}
    ; Check that the edge does not cross the interior of the rectangle
    cmp esi, [y1]
    jbe .horizontal_cross_check_done
    cmp esi, [y2]
    jae .horizontal_cross_check_done
    cmp eax, [x2]
    jae .horizontal_cross_check_done
    cmp edx, [x1]
    jbe .horizontal_cross_check_done
    jmp .max_area2_update_done
.horizontal_cross_check_done:

    jmp .edge_processing_done
.vertical_edge:
    ; Vertical edge
    mov esi, eax
    mov eax, [poly1]
    mov eax, [points+8*eax+4]
    mov edx, [poly2]
    mov edx, [points+8*edx+4]
    cmp eax, edx
    je .failure
    jbe .vertical_edge_ordered
    xchg eax, edx
.vertical_edge_ordered:

    ; Edge is {esi} x [eax, edx]
    ; Check that the edge does not cross the interior of the rectangle
    cmp esi, [x1]
    jbe .vertical_cross_check_done
    cmp esi, [x2]
    jae .vertical_cross_check_done
    cmp eax, [y2]
    jae .vertical_cross_check_done
    cmp edx, [y1]
    jbe .vertical_cross_check_done
    jmp .max_area2_update_done
.vertical_cross_check_done:

    ; Update the interiority using the even-odd fill rule (only vertical edges need to be considered)
    cmp esi, [x1]
    ja .edge_processing_done
    cmp eax, [y1]
    ja .edge_processing_done
    cmp edx, [y1]
    jbe .edge_processing_done
    xor dword [is_interior], 1

.edge_processing_done:

    ; Continue the loop around the polygon
    mov eax, [poly2]
    mov [poly1], eax
    inc dword [poly2]
    jmp .poly_loop
.poly_loop_done:
    cmp dword [is_interior], 1
    jne .max_area2_update_done

    ; Checks passed, update maximum area for second star
    mov eax, [area_low]
    mov edx, [area_high]
    cmp edx, [max_area2_high]
    jb .max_area2_update_done
    ja .do_max_area2_update
    cmp eax, [max_area2_low]
    jbe .max_area2_update_done
.do_max_area2_update:
    mov [max_area2_low], eax
    mov [max_area2_high], edx
.max_area2_update_done:

    ; Continue looping through pairs of points
    jmp .second_point_loop
.second_point_loop_done:
    inc dword [idx1]
    jmp .first_point_loop
.first_point_loop_done:

    ; Print results
    push dword [max_area1_high]
    push dword [max_area1_low]
    call write_ulong_line_to_stdout
    push dword [max_area2_high]
    push dword [max_area2_low]
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
