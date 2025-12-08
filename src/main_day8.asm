extern main

%include "exit.inc"
%include "io.inc"
%include "math.inc"
%include "number_str.inc"
%include "raw_io.inc"


struc PointPair
    .dist_sq_low resd 1
    .dist_sq_high resd 1
    .idx1 resd 1
    .idx2 resd 1
endstruc


section .bss


input: resb 100000
input_capacity: equ $ - input

points_capacity: equ 2000
points: resd 3 * points_capacity
points_count: resd 1

point_pairs_capacity: equ points_capacity * (points_capacity) / 2
point_pairs: resb PointPair_size * point_pairs_capacity
point_pair_count: resd 1

parent: resd points_capacity
component_size: resd points_capacity


section .text


sort_point_pairs:
    %push
    %stacksize flat

    %arg first:dword
    %arg last:dword

    push ebp
    mov ebp, esp

    push esi
    push edi

    ; Nothing to do unless [first] < [last]
    mov esi, [first]
    mov edi, [last]
    cmp esi, edi
    jae .done

    ; Use the first element as pivot edx:eax
    mov eax, [esi+PointPair.dist_sq_low]
    mov edx, [esi+PointPair.dist_sq_high]

    ; Partition the range using the pivot
    sub esi, PointPair_size
    add edi, PointPair_size
.partition_loop:
.left_move_loop:
    add esi, PointPair_size
    cmp esi, [last]
    ja .right_move_loop
    cmp [esi+PointPair.dist_sq_high], edx
    ja .right_move_loop
    jb .left_move_loop
    cmp [esi+PointPair.dist_sq_low], eax
    jae .right_move_loop
    jmp .left_move_loop
.right_move_loop:
    sub edi, PointPair_size
    cmp edi, [first]
    jb .move_loops_done
    cmp [edi+PointPair.dist_sq_high], edx
    jb .move_loops_done
    ja .right_move_loop
    cmp [edi+PointPair.dist_sq_low], eax
    jbe .move_loops_done
    jmp .right_move_loop
.move_loops_done:
    cmp esi, edi
    jae .partition_loop_done
    ; Perform the swap
    %if PointPair_size != 16
    %error Unexpected PointPair size
    %endif
    push eax
    push edx
    mov eax, [esi+PointPair.dist_sq_low]
    mov edx, [edi+PointPair.dist_sq_low]
    mov [esi+PointPair.dist_sq_low], edx
    mov [edi+PointPair.dist_sq_low], eax
    mov eax, [esi+PointPair.dist_sq_high]
    mov edx, [edi+PointPair.dist_sq_high]
    mov [esi+PointPair.dist_sq_high], edx
    mov [edi+PointPair.dist_sq_high], eax
    mov eax, [esi+PointPair.idx1]
    mov edx, [edi+PointPair.idx1]
    mov [esi+PointPair.idx1], edx
    mov [edi+PointPair.idx1], eax
    mov eax, [esi+PointPair.idx2]
    mov edx, [edi+PointPair.idx2]
    mov [esi+PointPair.idx2], edx
    mov [edi+PointPair.idx2], eax
    pop edx
    pop eax
    jmp .partition_loop
.partition_loop_done:

    ; Recursively sort partitions
    push edi
    push dword [first]
    call sort_point_pairs
    push dword [last]
    push edi
    add dword [esp], PointPair_size
    call sort_point_pairs

.done:
    pop edi
    pop esi

    pop ebp
    ret 8

    %pop


find:
    %push
    %stacksize flat

    %arg idx:dword

    push ebp
    mov ebp, esp

    ; Read the parent of eax = [idx] to edx
    mov eax, [idx]
    mov edx, [parent+4*eax]

    ; If the element is its own parent, return itself (already in eax); otherwise, recursively call
    ; find to find the parent of eax and make it the new parent to compactify the path
    cmp eax, edx
    je .done
    push edx
    call find
    mov edx, [idx]
    mov [parent+4*edx], eax
.done:

    pop ebp
    ret 4

    %pop


main:
    %push
    %stacksize flat

    %assign %$localsize 0
    %local points_end:dword
    %local point_pairs_end:dword
    %local idx1:dword
    %local idx2:dword
    %local compsize1:dword
    %local compsize2:dword
    %local compsize3:dword
    %local kruskal_round_count:dword

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
    cmp byte [esi], ','
    jne .parse_error
    inc esi
    push esi
    call parse_uint
    mov dword [edi+8], eax
    mov esi, edx
    cmp byte [esi], `\n`
    jne .parse_error
    inc esi
    add edi, 12
    jmp .input_row_loop
.input_row_loop_done:
    mov eax, [points_count]
    lea edx, [points+8*eax]
    lea edx, [edx+4*eax]
    mov [points_end], edx

    ; Generate point_pairs; esi = first point position, ebx = second point position, edi = point pair position
    mov esi, points
    mov dword [idx1], 0
    mov edi, point_pairs
.first_point_loop:
    cmp esi, [points_end]
    ja .failure
    je .first_point_loop_done
    mov ebx, esi
    mov eax, [idx1]
    mov [idx2], eax
.second_point_loop:
    add ebx, 12
    inc dword [idx2]
    cmp ebx, [points_end]
    ja .failure
    je .second_point_loop_done

    ; Generate point pair; ecx = coordinate
    mov dword [edi+PointPair.dist_sq_low], 0
    mov dword [edi+PointPair.dist_sq_high], 0
    mov eax, [idx1]
    mov [edi+PointPair.idx1], eax
    mov eax, [idx2]
    mov [edi+PointPair.idx2], eax
    xor ecx, ecx
.coord_loop:
    mov eax, [esi+4*ecx]
    sub eax, [ebx+4*ecx]
    imul eax
    add [edi+PointPair.dist_sq_low], eax
    adc [edi+PointPair.dist_sq_high], edx
    inc ecx
    cmp ecx, 3
    jl .coord_loop

    ; Continue point pair loops
    add edi, PointPair_size
    jmp .second_point_loop
.second_point_loop_done:
    add esi, 12
    inc dword [idx1]
    jmp .first_point_loop
.first_point_loop_done:

    ; Sanity check state and save end of point pairs array
    mov eax, [points_count]
    dec eax
    mul dword [points_count]
    shr eax, 1
    mov edx, PointPair_size
    mul edx
    add eax, point_pairs
    cmp eax, edi
    jne .failure
    mov [point_pairs_end], edi

    ; Sort the point pairs by distance squared
    push dword [point_pairs_end]
    sub dword [esp], PointPair_size
    push point_pairs
    call sort_point_pairs

    ; Just in case, check that the sort was successful
    mov esi, [point_pairs_end]
    sub esi, 2 * PointPair_size
.sort_check_loop:
    cmp esi, point_pairs
    jb .sort_check_loop_done
    mov eax, [esi+PointPair.dist_sq_high]
    cmp eax, [esi+PointPair_size+PointPair.dist_sq_high]
    ja .failure
    jb .sort_check_ok
    mov eax, [esi+PointPair.dist_sq_low]
    cmp eax, [esi+PointPair_size+PointPair.dist_sq_low]
    ja .failure
.sort_check_ok:
    sub esi, PointPair_size
    jmp .sort_check_loop
.sort_check_loop_done:

    ; Initialize Union-Find structure by setting each point to be its own parent
    xor esi, esi
.uf_init_loop:
    cmp esi, [points_count]
    ja .failure
    je .uf_init_loop_done
    mov dword [parent+4*esi], esi
    mov dword [component_size+4*esi], 1
    inc esi
    jmp .uf_init_loop
.uf_init_loop_done:

    ; Determine the number of rounds based on whether this is the example input or not
    mov dword [kruskal_round_count], 10
    cmp dword [points_count], 20
    je .set_kruskal_round_count_done
    mov dword [kruskal_round_count], 1000
.set_kruskal_round_count_done

    ; Run the beginning of the Kruskal algorithm, iterating point pairs ordered by distance
    ; squared and linking them whenever they are in different components;
    ; esi = point pairs position, edi = point pairs index
    mov esi, point_pairs
    xor edi, edi
.kruskal_loop:
    cmp esi, [point_pairs_end]
    ja .failure
    je .kruskal_loop_done
    cmp edi, [kruskal_round_count]
    ja .failure
    je .kruskal_loop_done
    push dword [esi+PointPair.idx1]
    call find
    mov ebx, eax
    push dword [esi+PointPair.idx2]
    call find
    cmp eax, ebx
    je .kruskal_loop_continue

    ; Merge the components
    mov [parent+4*eax], ebx
    mov ecx, [component_size+4*eax]
    mov dword [component_size+4*eax], 0
    add [component_size+4*ebx], ecx

.kruskal_loop_continue:
    add esi, PointPair_size
    inc edi
    jmp .kruskal_loop
.kruskal_loop_done:

    ; Find the three largest components; esi = root point index
    mov dword [compsize1], 0
    mov dword [compsize2], 0
    mov dword [compsize3], 0
    xor esi, esi
.component_loop:
    cmp esi, [points_count]
    ja .failure
    je .component_loop_done
    mov eax, [component_size+4*esi]
    cmp eax, [compsize3]
    jb .component_loop_continue
    mov [compsize3], eax
    cmp eax, [compsize2]
    jb .component_loop_continue
    mov edx, [compsize2]
    mov [compsize2], eax
    mov [compsize3], edx
    cmp eax, [compsize1]
    jb .component_loop_continue
    mov edx, [compsize1]
    mov [compsize1], eax
    mov [compsize2], edx
.component_loop_continue:
    inc esi
    jmp .component_loop
.component_loop_done:

    ; Compute product of top three component sizes and write it to stdout
    mov eax, [compsize1]
    mul dword [compsize2]
    mul dword [compsize3]
    push eax
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
